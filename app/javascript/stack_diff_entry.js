import { FileDiff, processPatch, preloadHighlighter, getFiletypeFromFileName, DEFAULT_THEMES, wrapCoreCSS } from "@pierre/diffs";

function ensureCoreCSS(fileContainer) {
  const shadowRoot = fileContainer.shadowRoot;
  if (!shadowRoot || shadowRoot.querySelector("style[data-core-css]")) return;

  const coreStyle = document.createElement("style");
  coreStyle.setAttribute("data-core-css", "");
  coreStyle.textContent = wrapCoreCSS("");
  shadowRoot.prepend(coreStyle);
}

async function renderStack() {
  const container = document.getElementById("stack-diff-root");
  if (!container) return;

  const stackId = container.dataset.stackId;

  const response = await fetch(`/stacks/${stackId}.json`, {
    headers: { Accept: "application/json" }
  });
  const { pull_requests } = await response.json();

  const parsedByPr = pull_requests.map((pr) => ({ pr, parsed: processPatch(pr.diff) }));

  const langs = new Set();
  parsedByPr.forEach(({ parsed }) => {
    parsed.files.forEach((fileDiff) => langs.add(getFiletypeFromFileName(fileDiff.name)));
  });

  await preloadHighlighter({
    themes: [DEFAULT_THEMES.dark, DEFAULT_THEMES.light],
    langs: Array.from(langs)
  });

  parsedByPr.forEach(({ pr, parsed }) => {
    const prContainer = document.createElement("div");
    prContainer.className = "pr-diff";
    prContainer.innerHTML = `<h3>#${pr.number} ${pr.title} (${pr.author})</h3>`;
    container.appendChild(prContainer);

    parsed.files.forEach((fileDiff) => {
      const fileContainer = document.createElement("div");
      prContainer.appendChild(fileContainer);

      const diff = new FileDiff();
      diff.render({ fileDiff, fileContainer });
      ensureCoreCSS(fileContainer);
    });
  });
}

document.addEventListener("DOMContentLoaded", renderStack);
