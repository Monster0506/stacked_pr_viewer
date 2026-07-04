import { FileDiff, processPatch } from "@pierre/diffs";

async function renderStack() {
  const container = document.getElementById("stack-diff-root");
  if (!container) return;

  const stackId = container.dataset.stackId;

  const response = await fetch(`/stacks/${stackId}.json`, {
    headers: { Accept: "application/json" }
  });
  const { pull_requests } = await response.json();

  pull_requests.forEach((pr) => {
    const prContainer = document.createElement("div");
    prContainer.className = "pr-diff";
    prContainer.innerHTML = `<h3>#${pr.number} ${pr.title} (${pr.author})</h3>`;
    container.appendChild(prContainer);

    const { files } = processPatch(pr.diff);

    files.forEach((fileDiff) => {
      const fileContainer = document.createElement("div");
      prContainer.appendChild(fileContainer);

      const diff = new FileDiff();
      diff.render({ fileDiff, fileContainer });
    });
  });
}

document.addEventListener("DOMContentLoaded", renderStack);
