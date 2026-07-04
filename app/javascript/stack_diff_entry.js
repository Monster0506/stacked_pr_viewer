import { FileDiff, processPatch, preloadHighlighter, getFiletypeFromFileName, DEFAULT_THEMES, wrapCoreCSS } from "@pierre/diffs";

function ensureCoreCSS(fileContainer) {
  const shadowRoot = fileContainer.shadowRoot;
  if (!shadowRoot || shadowRoot.querySelector("style[data-core-css]")) return;

  const coreStyle = document.createElement("style");
  coreStyle.setAttribute("data-core-css", "");
  coreStyle.textContent = wrapCoreCSS("");
  shadowRoot.prepend(coreStyle);
}

function renderCommentAnnotation(annotation) {
  const comment = annotation.metadata;
  const el = document.createElement("div");
  el.className = "px-4 py-2 text-xs font-mono border-t border-b border-neutral-800 bg-neutral-900 text-neutral-300";
  el.innerHTML = `<span class="text-sky-400">${comment.author}</span> ${comment.body}`;
  return el;
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
    <button type="submit" class="text-xs font-mono text-neutral-500 hover:text-neutral-200 border border-neutral-800 px-1.5 py-0.5">Mark reviewed</button>
  `;
  return form;
}

function buildCommentForm(pr, filePath) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";

  const form = document.createElement("form");
  form.method = "post";
  form.action = "/comments";
  form.className = "px-4 py-2 border-t border-neutral-800 flex items-center gap-2 text-xs font-mono";
  form.innerHTML = `
    <input type="hidden" name="authenticity_token" value="${csrfToken}">
    <input type="hidden" name="comment[pull_request_id]" value="${pr.id}">
    <input type="hidden" name="comment[file_path]" value="${filePath}">
    <input type="number" name="comment[line_number]" placeholder="line" required
      class="w-16 bg-neutral-900 border border-neutral-800 px-1 py-0.5 text-neutral-300">
    <input type="text" name="comment[body]" placeholder="Add a comment" required
      class="flex-1 bg-neutral-900 border border-neutral-800 px-1 py-0.5 text-neutral-300">
    <button type="submit" class="text-sky-400 hover:text-sky-300 border border-neutral-800 px-2 py-0.5">Comment</button>
  `;
  return form;
}

function commentsByFile(comments) {
  const byFile = new Map();
  comments.forEach((comment) => {
    const forFile = byFile.get(comment.file_path) || [];
    forFile.push({ side: "additions", lineNumber: comment.line_number, metadata: comment });
    byFile.set(comment.file_path, forFile);
  });
  return byFile;
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

    parsedCumulative.files.forEach((fileDiff) => {
      const fileContainer = document.createElement("div");
      filesWrapper.appendChild(fileContainer);

      const diff = new FileDiff({ themeType: "dark" });
      diff.render({ fileDiff, fileContainer });
      ensureCoreCSS(fileContainer);
    });

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

    const commentsForFile = commentsByFile(pr.comments || []);

    parsed.files.forEach((fileDiff) => {
      const fileContainer = document.createElement("div");
      filesWrapper.appendChild(fileContainer);

      const diff = new FileDiff({ themeType: "dark", renderAnnotation: renderCommentAnnotation });
      diff.render({ fileDiff, fileContainer, lineAnnotations: commentsForFile.get(fileDiff.name) || [] });
      ensureCoreCSS(fileContainer);

      filesWrapper.appendChild(buildCommentForm(pr, fileDiff.name));
    });
  });
}

// Turbo re-inserts this script fresh on every visit; guard on `window` so the
// listener attaches once, and render immediately in case this navigation's turbo:load already fired before this large bundle finished loading.
if (!window.__stackDiffListenerAttached) {
  window.__stackDiffListenerAttached = true;
  document.addEventListener("turbo:load", renderStack);
  renderStack();
}
