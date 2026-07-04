import { FileDiff, processPatch, preloadHighlighter, getFiletypeFromFileName, DEFAULT_THEMES, wrapCoreCSS } from "@pierre/diffs";

function ensureCoreCSS(fileContainer) {
  const shadowRoot = fileContainer.shadowRoot;
  if (!shadowRoot || shadowRoot.querySelector("style[data-core-css]")) return;

  const coreStyle = document.createElement("style");
  coreStyle.setAttribute("data-core-css", "");
  coreStyle.textContent = wrapCoreCSS("");
  shadowRoot.prepend(coreStyle);
}

function buildActionsMenu(actions) {
  const wrapper = document.createElement("span");
  wrapper.className = "shrink-0";

  const toggle = document.createElement("button");
  toggle.type = "button";
  toggle.textContent = "…";
  toggle.className = "text-neutral-500 hover:text-neutral-200 bg-transparent border-0 cursor-pointer px-1";

  const menu = document.createElement("span");
  menu.className = "hidden ml-1";
  actions.forEach(({ label, onClick }, index) => {
    if (index > 0) menu.appendChild(document.createTextNode(" · "));
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.className = "text-sky-400 hover:text-sky-300 bg-transparent border-0 cursor-pointer";
    button.addEventListener("click", () => {
      menu.classList.add("hidden");
      onClick();
    });
    menu.appendChild(button);
  });

  toggle.addEventListener("click", () => menu.classList.toggle("hidden"));

  wrapper.appendChild(toggle);
  wrapper.appendChild(menu);
  return wrapper;
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

function renderCommentRow(comment, { indent = false, actions = [] } = {}) {
  const row = document.createElement("div");
  row.dataset.commentId = comment.id;
  row.className = `flex items-start justify-between gap-2 px-4 py-2 text-xs font-mono text-neutral-300 ${indent ? "pl-10" : ""}`;

  const text = document.createElement("span");
  text.innerHTML = `<span class="muted">${comment.author}</span> `;
  const bodySpan = document.createElement("span");
  bodySpan.dataset.role = "comment-body";
  bodySpan.textContent = comment.body;
  text.appendChild(bodySpan);
  row.appendChild(text);

  const allActions = comment.editable
    ? [ ...actions, { label: "Edit", onClick: () => startEditingComment(text, bodySpan, comment) } ]
    : actions;

  if (allActions.length > 0) row.appendChild(buildActionsMenu(allActions));

  return row;
}

function buildThreadAnnotations(comments) {
  return comments
    .filter((comment) => !comment.parent_id)
    .map((comment) => ({
      side: "additions",
      lineNumber: comment.line_number,
      metadata: { comment, replies: comments.filter((c) => c.parent_id === comment.id) }
    }));
}

// Renders a comment thread (top-level comment + replies) for one annotation.
// `addComment` appends a new reply into the file's live comment list and
// triggers a fresh annotation render (see renderFileDiffs).
function makeRenderCommentAnnotation(pr, filePath, addComment) {
  return (annotation) => {
    const { comment, replies } = annotation.metadata;
    const container = document.createElement("div");
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

    container.appendChild(renderCommentRow(comment, { actions: [ { label: "Reply", onClick: showReplyComposer } ] }));
    replies.forEach((reply) => container.appendChild(renderCommentRow(reply, { indent: true })));

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

    const addComment = (comment) => {
      // FileDiff.render only detects annotation changes by array identity,
      // so a fresh array (not an in-place push) is required here.
      comments = [ ...comments, comment ];
      diff.render({ fileDiff, fileContainer, lineAnnotations: buildThreadAnnotations(comments) });
    };

    diff = new FileDiff({
      themeType: "dark",
      renderAnnotation: makeRenderCommentAnnotation(commentOwnerPr, fileDiff.name, addComment),
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
    diff.render({ fileDiff, fileContainer, lineAnnotations: buildThreadAnnotations(comments) });
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
