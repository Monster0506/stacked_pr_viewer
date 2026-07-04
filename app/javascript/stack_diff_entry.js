import { FileDiff, processPatch, preloadHighlighter, getFiletypeFromFileName, DEFAULT_THEMES, wrapCoreCSS } from "@pierre/diffs";

function ensureCoreCSS(fileContainer) {
  const shadowRoot = fileContainer.shadowRoot;
  if (!shadowRoot || shadowRoot.querySelector("style[data-core-css]")) return;

  const coreStyle = document.createElement("style");
  coreStyle.setAttribute("data-core-css", "");
  coreStyle.textContent = wrapCoreCSS("");
  shadowRoot.prepend(coreStyle);
}

// Builds the "..." button for a comment thread. It's inserted directly into
// @pierre/diffs' own blank gutter cell for that annotation row (a real
// `[data-gutter-buffer="annotation"]` element in the diff's shadow DOM -- see
// wireThreadActionButtons), so it lands in the actual gutter/number column
// rather than floating over the comment text or fighting shadow-DOM stacking.
function buildThreadActionsButton() {
  const button = document.createElement("button");
  button.type = "button";
  button.dataset.role = "thread-actions-button";
  button.textContent = "...";
  button.setAttribute("aria-label", "Comment actions");
  button.className = "block w-full text-center bg-neutral-900 border border-neutral-700 text-neutral-300 hover:text-neutral-100 hover:border-neutral-500 text-[10px] font-mono leading-none py-0.5 cursor-pointer";
  return button;
}

function closeThreadActionsPopup() {
  document.querySelectorAll("[data-role='thread-actions-popup']").forEach((el) => el.remove());
}

// Opens a small floating popup of action buttons anchored under `anchorEl`.
// Closes on an outside click or after any action is chosen.
function openThreadActionsPopup(anchorEl, items) {
  closeThreadActionsPopup();
  if (!anchorEl || items.length === 0) return;

  const popup = document.createElement("div");
  popup.dataset.role = "thread-actions-popup";
  popup.className = "fixed z-50 bg-neutral-950 border border-neutral-800 py-1 text-xs font-mono";
  popup.style.minWidth = "8rem";

  items.forEach(({ label, onClick }) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.className = "block w-full text-left px-3 py-1.5 text-neutral-300 hover:bg-neutral-900 hover:text-sky-400 bg-transparent border-0 cursor-pointer whitespace-nowrap";
    button.addEventListener("click", () => {
      closeThreadActionsPopup();
      onClick();
    });
    popup.appendChild(button);
  });

  document.body.appendChild(popup);
  const rect = anchorEl.getBoundingClientRect();
  popup.style.top = `${rect.bottom + 4}px`;
  popup.style.left = `${rect.left}px`;

  setTimeout(() => {
    document.addEventListener("click", function onOutsideClick(event) {
      if (popup.contains(event.target)) return;
      closeThreadActionsPopup();
      document.removeEventListener("click", onOutsideClick, true);
    }, true);
  }, 0);
}

// Swaps the comment body text for an inline input, PATCHing on save.
// `text` is the row's text container (author + body); `bodySpan` is the
// body-only child that gets replaced with the editor and restored after.
function startEditingComment(text, bodySpan, comment) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";

  const editor = document.createElement("span");
  editor.className = "inline-flex items-center gap-2";
  editor.innerHTML = `
    <input type="text" class="field-input mt-0" style="width: 20rem">
    <button type="button" data-role="save-edit" class="btn-ghost">Save</button>
    <button type="button" data-role="cancel-edit"
      class="text-xs font-mono text-neutral-500 hover:text-neutral-200 bg-transparent border-0 cursor-pointer">Cancel</button>
    <span data-role="edit-error" class="text-red-400"></span>
  `;

  const input = editor.querySelector("input");
  input.value = comment.body;
  const errorEl = editor.querySelector('[data-role="edit-error"]');

  editor.querySelector('[data-role="cancel-edit"]').addEventListener("click", () => editor.replaceWith(bodySpan));

  editor.querySelector('[data-role="save-edit"]').addEventListener("click", async () => {
    errorEl.textContent = "";

    const response = await fetch(`/comments/${comment.id}`, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ comment: { body: input.value } })
    });

    if (!response.ok) {
      const { errors } = await response.json().catch(() => ({ errors: [ "Couldn't save comment" ] }));
      errorEl.textContent = (errors || []).join(", ");
      return;
    }

    const updated = await response.json();
    comment.body = updated.body;
    bodySpan.textContent = updated.body;
    editor.replaceWith(bodySpan);
  });

  bodySpan.replaceWith(editor);
}

// Deletes a comment on the server after confirmation; resolves to whether
// it was actually deleted, so callers only update local state on success.
async function requestCommentDelete(comment) {
  if (!window.confirm("Delete this comment?")) return false;

  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";
  const response = await fetch(`/comments/${comment.id}`, {
    method: "DELETE",
    headers: { Accept: "application/json", "X-CSRF-Token": csrfToken }
  });

  if (!response.ok) {
    window.alert("Couldn't delete comment");
    return false;
  }

  return true;
}

// Renders one comment/reply line. Edit/Delete/Reply are no longer inline here --
// they're offered from the line's gutter "..." popup (see renderFileDiffs) -- but
// `text`/`bodySpan` are stashed on the row so that popup can still target this row.
function renderCommentRow(comment, { indent = false } = {}) {
  const row = document.createElement("div");
  row.dataset.commentId = comment.id;
  row.className = `px-4 py-2 text-xs font-mono text-neutral-300 ${indent ? "pl-10" : ""}`;

  const text = document.createElement("span");
  text.innerHTML = `<span class="muted">${comment.author}</span> `;
  const bodySpan = document.createElement("span");
  bodySpan.dataset.role = "comment-body";
  bodySpan.textContent = comment.body;
  text.appendChild(bodySpan);
  row.appendChild(text);

  row._text = text;
  row._bodySpan = bodySpan;
  return row;
}

// Sorted by line number: wireThreadActionButtons pairs these 1:1, in order,
// with the gutter's own annotation cells, which render top-to-bottom.
function buildThreadAnnotations(comments) {
  return comments
    .filter((comment) => !comment.parent_id)
    .sort((a, b) => a.line_number - b.line_number)
    .map((comment) => ({
      side: "additions",
      lineNumber: comment.line_number,
      metadata: { comment, replies: comments.filter((c) => c.parent_id === comment.id) }
    }));
}

// Renders a comment thread (top-level comment + replies) for one annotation.
// `addComment`/`removeComment` mutate the file's live comment list and
// trigger a fresh annotation render (see renderFileDiffs). `registerButtonSetup`
// queues the "..." button's own setup (built lazily, once the thread's real
// gutter cell is known) -- see wireThreadActionButtons.
function makeRenderCommentAnnotation(pr, filePath, addComment, removeComment, registerButtonSetup) {
  return (annotation) => {
    const { comment, replies } = annotation.metadata;
    const container = document.createElement("div");
    container.dataset.commentThread = comment.id;
    container.className = "border-t border-neutral-800";

    let replyComposer = null;
    const showReplyComposer = () => {
      if (replyComposer) return;
      replyComposer = buildCommentForm(pr, filePath, comment.line_number, comment.id, (reply) => {
        replyComposer.remove();
        replyComposer = null;
        addComment(reply);
      });
      container.appendChild(replyComposer);
    };

    const topRow = renderCommentRow(comment);
    container.appendChild(topRow);

    const replyRows = replies.map((reply) => {
      const row = renderCommentRow(reply, { indent: true });
      container.appendChild(row);
      return { comment: reply, row };
    });

    registerButtonSetup((gutterCell) => {
      const actionsButton = buildThreadActionsButton();
      actionsButton.dataset.commentThread = comment.id;
      gutterCell.appendChild(actionsButton);

      actionsButton.addEventListener("click", () => {
        const items = [ { label: "Reply", onClick: showReplyComposer } ];

        if (comment.editable) {
          items.push({ label: "Edit comment", onClick: () => startEditingComment(topRow._text, topRow._bodySpan, comment) });
          items.push({ label: "Delete comment", onClick: () => requestCommentDelete(comment).then((deleted) => deleted && removeComment(comment.id)) });
        }

        replyRows.forEach(({ comment: reply, row }, index) => {
          if (!reply.editable) return;
          const suffix = replyRows.length > 1 ? ` ${index + 1}` : "";
          items.push({ label: `Edit reply${suffix}`, onClick: () => startEditingComment(row._text, row._bodySpan, reply) });
          items.push({ label: `Delete reply${suffix}`, onClick: () => requestCommentDelete(reply).then((deleted) => deleted && removeComment(reply.id)) });
        });

        openThreadActionsPopup(actionsButton, items);
      });
    });

    return container;
  };
}

function buildMarkReviewedForm(pr) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";

  const form = document.createElement("form");
  form.method = "post";
  form.action = "/review_states";
  form.className = "inline";
  form.innerHTML = `
    <input type="hidden" name="authenticity_token" value="${csrfToken}">
    <input type="hidden" name="review_state[pull_request_id]" value="${pr.id}">
    <button type="submit" class="text-xs font-mono text-neutral-500 hover:text-neutral-200 bg-transparent border-0 cursor-pointer">Mark reviewed</button>
  `;
  return form;
}

// Submits via fetch instead of a native form post so adding a comment
// updates just this file's annotations, not a full Turbo page visit.
// The caller owns removing the form on success (a top-level comment composer
// and a reply composer track their own open-form state independently).
function buildCommentForm(pr, filePath, lineNumber, parentId, onCreated) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";
  const isReply = parentId != null;

  const form = document.createElement("form");
  form.dataset.role = "comment-form";
  form.className = "px-4 py-2 border-t border-neutral-800 flex items-center gap-2";
  form.innerHTML = `
    <span class="muted text-xs font-mono">${isReply ? "reply" : `line ${lineNumber}`}</span>
    <input type="text" name="body" placeholder="${isReply ? "Write a reply" : "Add a comment"}" required autofocus
      class="field-input flex-1 mt-0">
    <button type="submit" class="btn-ghost">${isReply ? "Reply" : "Comment"}</button>
    <button type="button" data-role="cancel-comment"
      class="text-xs font-mono text-neutral-500 hover:text-neutral-200 bg-transparent border-0 cursor-pointer">Cancel</button>
    <span data-role="comment-error" class="text-xs font-mono text-red-400"></span>
  `;

  const bodyInput = form.querySelector('input[name="body"]');
  const errorEl = form.querySelector('[data-role="comment-error"]');
  form.querySelector('[data-role="cancel-comment"]').addEventListener("click", () => form.remove());

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    errorEl.textContent = "";

    const response = await fetch("/comments", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({
        comment: { pull_request_id: pr.id, file_path: filePath, line_number: lineNumber, parent_id: parentId, body: bodyInput.value }
      })
    });

    if (!response.ok) {
      const { errors } = await response.json().catch(() => ({ errors: [ "Couldn't save comment" ] }));
      errorEl.textContent = (errors || []).join(", ");
      return;
    }

    onCreated(await response.json());
  });

  return form;
}

function commentsByFile(comments) {
  const byFile = new Map();
  comments.forEach((comment) => {
    const forFile = byFile.get(comment.file_path) || [];
    forFile.push(comment);
    byFile.set(comment.file_path, forFile);
  });
  return byFile;
}

// Renders each file's diff into filesWrapper with comment annotations and a
// click-to-comment composer. New comments are attributed to `commentOwnerPr`
// (the top PR for the cumulative view, since that's where its head lands).
function renderFileDiffs(filesWrapper, files, commentOwnerPr) {
  const commentsForFile = commentsByFile(commentOwnerPr.comments || []);

  files.forEach((fileDiff) => {
    const fileContainer = document.createElement("div");
    filesWrapper.appendChild(fileContainer);

    let comments = commentsForFile.get(fileDiff.name) || [];
    let openComposer = null;
    let diff;

    // Populated by makeRenderCommentAnnotation during render(), in the same
    // top-to-bottom order as the gutter's own annotation cells -- see
    // wireThreadActionButtons.
    let pendingButtonSetups = [];
    const registerButtonSetup = (setupFn) => pendingButtonSetups.push(setupFn);

    // Pairs each thread's queued button setup with @pierre/diffs' own blank
    // gutter cell for that row (a real `[data-gutter-buffer="annotation"]`
    // element), so the "..." button is inserted directly into the gutter
    // instead of floating over the comment text. Our comments are always
    // additions-side, but for changed (not purely added) lines the library
    // also inserts a matching blank annotation cell on the deletions side
    // (to keep both columns row-aligned) -- that side renders first in DOM
    // order, so the query must be scoped to the additions column specifically
    // or its placeholder cells would steal our buttons.
    const wireThreadActionButtons = () => {
      const additionsCode = fileContainer.shadowRoot?.querySelector("code[data-additions]");
      const scope = additionsCode || fileContainer.shadowRoot;
      const gutterCells = Array.from(scope?.querySelectorAll('[data-gutter-buffer="annotation"]') || []);
      pendingButtonSetups.forEach((setup, index) => {
        const gutterCell = gutterCells[index];
        if (gutterCell) setup(gutterCell);
      });
    };

    const rerenderDiff = () => {
      pendingButtonSetups = [];
      diff.render({ fileDiff, fileContainer, lineAnnotations: buildThreadAnnotations(comments) });
      wireThreadActionButtons();
    };

    const addComment = (comment) => {
      // FileDiff.render only detects annotation changes by array identity,
      // so a fresh array (not an in-place push) is required here.
      comments = [ ...comments, comment ];
      rerenderDiff();
    };

    const removeComment = (commentId) => {
      // Deleting a top-level comment cascades to its replies server-side,
      // so drop both here too.
      comments = comments.filter((c) => c.id !== commentId && c.parent_id !== commentId);
      rerenderDiff();
    };

    diff = new FileDiff({
      themeType: "dark",
      renderAnnotation: makeRenderCommentAnnotation(commentOwnerPr, fileDiff.name, addComment, removeComment, registerButtonSetup),
      lineHoverHighlight: "number",
      onLineNumberClick: ({ lineNumber }) => {
        if (openComposer) openComposer.remove();
        openComposer = buildCommentForm(commentOwnerPr, fileDiff.name, lineNumber, null, (comment) => {
          openComposer.remove();
          openComposer = null;
          addComment(comment);
        });
        fileContainer.after(openComposer);
      }
    });
    rerenderDiff();
    ensureCoreCSS(fileContainer);
  });
}

async function renderStack() {
  const container = document.getElementById("stack-diff-root");
  if (!container) return;

  // Guard against overlapping renders (e.g. a stray duplicate event firing
  // before a previous render's async work has finished).
  const renderToken = Symbol();
  container.dataset.renderToken = "";
  container._renderToken = renderToken;
  container.innerHTML = "";

  const stackId = container.dataset.stackId;

  const response = await fetch(`/stacks/${stackId}.json`, {
    headers: { Accept: "application/json" }
  });
  const { pull_requests, cumulative_diff } = await response.json();
  if (container._renderToken !== renderToken) return;

  const parsedByPr = pull_requests.map((pr) => ({ pr, parsed: processPatch(pr.diff) }));
  const parsedCumulative = cumulative_diff ? processPatch(cumulative_diff) : null;

  const langs = new Set();
  parsedByPr.forEach(({ parsed }) => {
    parsed.files.forEach((fileDiff) => langs.add(getFiletypeFromFileName(fileDiff.name)));
  });
  if (parsedCumulative) {
    parsedCumulative.files.forEach((fileDiff) => langs.add(getFiletypeFromFileName(fileDiff.name)));
  }

  await preloadHighlighter({
    themes: [DEFAULT_THEMES.dark, DEFAULT_THEMES.light],
    langs: Array.from(langs)
  });
  if (container._renderToken !== renderToken) return;

  if (parsedCumulative && pull_requests.length > 1) {
    const cumulativeSection = document.createElement("div");
    cumulativeSection.className = "border border-neutral-800 mb-6";

    const header = document.createElement("div");
    header.className = "px-4 py-3 border-b border-neutral-800 font-mono text-sm text-neutral-300";
    header.textContent = `Cumulative diff (${pull_requests.length} PRs)`;
    cumulativeSection.appendChild(header);

    const filesWrapper = document.createElement("div");
    filesWrapper.className = "divide-y divide-neutral-800";
    cumulativeSection.appendChild(filesWrapper);

    renderFileDiffs(filesWrapper, parsedCumulative.files, pull_requests[pull_requests.length - 1]);

    container.appendChild(cumulativeSection);
  }

  parsedByPr.forEach(({ pr, parsed }) => {
    const prContainer = document.createElement("div");
    prContainer.className = "border border-neutral-800";

    const staleBadge = pr.stale_for_current_user
      ? `<span class="text-xs font-mono text-amber-400 border border-amber-900 px-1.5 py-0.5">new changes</span>`
      : "";
    const conflictBadge = pr.conflicted
      ? `<span class="text-xs font-mono text-red-400 border border-red-900 px-1.5 py-0.5">conflicts with base</span>`
      : "";

    const header = document.createElement("div");
    header.className = "px-4 py-3 border-b border-neutral-800 font-mono text-sm text-neutral-300 flex items-center gap-2";
    header.innerHTML = `<span class="text-neutral-600">#${pr.number}</span> ${pr.title} <span class="text-neutral-600 text-xs">(${pr.author})</span> ${staleBadge} ${conflictBadge}`;
    if (pr.stale_for_current_user) header.appendChild(buildMarkReviewedForm(pr));
    prContainer.appendChild(header);

    container.appendChild(prContainer);

    const filesWrapper = document.createElement("div");
    filesWrapper.className = "divide-y divide-neutral-800";
    prContainer.appendChild(filesWrapper);

    renderFileDiffs(filesWrapper, parsed.files, pr);
  });
}

// Turbo re-inserts this script fresh on every visit; guard on `window` so the
// listener attaches once, and render immediately in case this navigation's turbo:load already fired before this large bundle finished loading.
if (!window.__stackDiffListenerAttached) {
  window.__stackDiffListenerAttached = true;
  document.addEventListener("turbo:load", renderStack);
  renderStack();
}
