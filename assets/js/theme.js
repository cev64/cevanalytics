// Manual light/dark override. The initial theme is set inline in <head>
// to avoid a flash; this file only wires up the toggle button.
(function () {
  var button = document.querySelector(".theme-toggle");
  if (!button) return;

  var root = document.documentElement;
  var systemDark = window.matchMedia("(prefers-color-scheme: dark)");

  function current() {
    return root.dataset.theme || (systemDark.matches ? "dark" : "light");
  }

  function sync() {
    button.setAttribute("aria-pressed", current() === "dark" ? "true" : "false");
  }

  button.addEventListener("click", function () {
    var next = current() === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    try {
      localStorage.setItem("cev-theme", next);
    } catch (e) {}
    sync();
  });

  if (systemDark.addEventListener) systemDark.addEventListener("change", sync);
  button.hidden = false;
  sync();
})();
