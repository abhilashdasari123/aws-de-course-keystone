(function () {
  var stage = document.querySelector(".stage");
  var slides = Array.prototype.slice.call(document.querySelectorAll(".slide"));
  var deckTitle = document.body.getAttribute("data-deck") || document.title;
  var current = 0;

  var bar = document.createElement("div");
  bar.className = "progress";
  document.body.appendChild(bar);

  var help = document.createElement("div");
  help.className = "help";
  help.textContent = "Arrows / Space: navigate | F: fullscreen | N: trainer notes | Home / End";
  document.body.appendChild(help);

  slides.forEach(function (slide, n) {
    if (document.body.hasAttribute("data-no-footer")) return;
    var footer = document.createElement("div");
    footer.className = "footer";
    footer.innerHTML = "<span>" + deckTitle + "</span><span>" + (n + 1) + " / " + slides.length + "</span>";
    slide.appendChild(footer);
  });

  function fit() {
    var scale = Math.min(window.innerWidth / 1280, window.innerHeight / 720) * 0.98;
    stage.style.transform = "scale(" + scale + ")";
  }

  function show(n) {
    current = Math.max(0, Math.min(slides.length - 1, n));
    slides.forEach(function (slide, k) { slide.classList.toggle("active", k === current); });
    bar.style.width = ((current + 1) / slides.length) * 100 + "%";
    if (history.replaceState) history.replaceState(null, "", "#" + (current + 1));
  }

  function toggleFullscreen() {
    if (!document.fullscreenElement) document.documentElement.requestFullscreen();
    else document.exitFullscreen();
  }

  document.addEventListener("keydown", function (e) {
    var tag = e.target.tagName;
    if (tag === "SUMMARY" && (e.key === " " || e.key === "Enter")) return;
    switch (e.key) {
      case "ArrowRight": case "ArrowDown": case "PageDown": case " ":
        e.preventDefault(); show(current + 1); break;
      case "ArrowLeft": case "ArrowUp": case "PageUp":
        e.preventDefault(); show(current - 1); break;
      case "Home": show(0); break;
      case "End": show(slides.length - 1); break;
      case "f": case "F": toggleFullscreen(); break;
      case "n": case "N": document.body.classList.toggle("show-notes"); break;
    }
  });

  document.addEventListener("click", function (e) {
    if (e.target.closest("details, a, button, pre, code, table, .notes")) return;
    if (window.getSelection && String(window.getSelection())) return;
    if (e.clientX > window.innerWidth / 2) show(current + 1);
    else show(current - 1);
  });

  window.addEventListener("resize", fit);
  fit();
  show((parseInt(location.hash.slice(1), 10) || 1) - 1);
})();
