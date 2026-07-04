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
    prContainer.className = "card overflow-hidden";

    const header = document.createElement("div");
    header.className = "px-4 py-3 border-b border-neutral-800 font-mono text-sm text-neutral-300";
    header.innerHTML = `<span class="text-neutral-600">#${pr.number}</span> ${pr.title} <span class="text-neutral-600 text-xs">(${pr.author})</span>`;
    prContainer.appendChild(header);

    container.appendChild(prContainer);

    const filesWrapper = document.createElement("div");
    filesWrapper.className = "divide-y divide-neutral-800";
    prContainer.appendChild(filesWrapper);

    parsed.files.forEach((fileDiff) => {
      const fileContainer = document.createElement("div");
      filesWrapper.appendChild(fileContainer);

      const diff = new FileDiff({ themeType: "dark" });
      diff.render({ fileDiff, fileContainer });
      ensureCoreCSS(fileContainer);
    });
  });
}

document.addEventListener("DOMContentLoaded", renderStack);
