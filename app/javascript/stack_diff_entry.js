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
  const { pull_requests } = await response.json();
  if (container._renderToken !== renderToken) return;

  const parsedByPr = pull_requests.map((pr) => ({ pr, parsed: processPatch(pr.diff) }));

  const langs = new Set();
  parsedByPr.forEach(({ parsed }) => {
    parsed.files.forEach((fileDiff) => langs.add(getFiletypeFromFileName(fileDiff.name)));
  });

  await preloadHighlighter({
    themes: [DEFAULT_THEMES.dark, DEFAULT_THEMES.light],
    langs: Array.from(langs)
  });
  if (container._renderToken !== renderToken) return;

  parsedByPr.forEach(({ pr, parsed }) => {
    const prContainer = document.createElement("div");
    prContainer.className = "border border-neutral-800";

    const staleBadge = pr.stale_for_current_user
      ? `<span class="text-xs font-mono text-amber-400 border border-amber-900 px-1.5 py-0.5">new changes</span>`
      : "";

    const header = document.createElement("div");
    header.className = "px-4 py-3 border-b border-neutral-800 font-mono text-sm text-neutral-300 flex items-center gap-2";
    header.innerHTML = `<span class="text-neutral-600">#${pr.number}</span> ${pr.title} <span class="text-neutral-600 text-xs">(${pr.author})</span> ${staleBadge}`;
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
