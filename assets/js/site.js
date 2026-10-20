// Site behaviour. Everything here is optional: the page reads fully
// without it. The initial theme is set inline in <head> to avoid a flash.
(function () {
  var root = document.documentElement;
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ---- Theme toggle -------------------------------------------------------
  var toggle = document.querySelector(".theme-toggle");
  if (toggle) {
    var systemDark = window.matchMedia("(prefers-color-scheme: dark)");
    var currentTheme = function () {
      return root.dataset.theme || (systemDark.matches ? "dark" : "light");
    };
    var syncToggle = function () {
      toggle.setAttribute("aria-pressed", currentTheme() === "dark" ? "true" : "false");
    };
    toggle.addEventListener("click", function () {
      var next = currentTheme() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      try {
        localStorage.setItem("cev-theme", next);
      } catch (e) {}
      syncToggle();
    });
    if (systemDark.addEventListener) systemDark.addEventListener("change", syncToggle);
    toggle.hidden = false;
    syncToggle();
  }

  // ---- Active section in the nav -------------------------------------------
  var navLinks = document.querySelectorAll('.site-nav a[href^="#"]');
  if (navLinks.length && "IntersectionObserver" in window) {
    var linkFor = {};
    navLinks.forEach(function (a) {
      linkFor[a.getAttribute("href").slice(1)] = a;
    });
    var spy = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          navLinks.forEach(function (a) {
            a.removeAttribute("aria-current");
          });
          var link = linkFor[entry.target.id];
          if (link) link.setAttribute("aria-current", "location");
        });
      },
      { rootMargin: "-45% 0px -50% 0px" }
    );
    document.querySelectorAll("main > section").forEach(function (section) {
      spy.observe(section);
    });
  }

  // ---- "How we work" timeline fills as you scroll --------------------------
  var steps = document.querySelector(".steps");
  if (steps && !reduceMotion) {
    var items = steps.querySelectorAll(".step");
    var pending = false;
    var update = function () {
      pending = false;
      var rect = steps.getBoundingClientRect();
      var vh = window.innerHeight;
      var horizontal = getComputedStyle(steps).display === "grid";
      var progress = horizontal
        ? (vh * 0.85 - rect.top) / (vh * 0.45)
        : (vh * 0.7 - rect.top) / rect.height;
      progress = Math.max(0, Math.min(1, progress));
      steps.style.setProperty("--progress", progress.toFixed(3));
      items.forEach(function (item) {
        var at = horizontal
          ? item.offsetLeft / steps.clientWidth
          : item.offsetTop / steps.clientHeight;
        item.classList.toggle("is-active", progress > 0 && progress >= at);
      });
    };
    var schedule = function () {
      if (!pending) {
        pending = true;
        window.requestAnimationFrame(update);
      }
    };
    steps.classList.add("steps--live");
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    update();
  }

  // ---- Illustrations animate once their card scrolls into view ------------
  var cards = document.querySelectorAll(".card");
  if (cards.length) {
    if ("IntersectionObserver" in window) {
      var reveal = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (!entry.isIntersecting) return;
            entry.target.classList.add("is-visible");
            reveal.unobserve(entry.target);
          });
        },
        { threshold: 0.35 }
      );
      cards.forEach(function (card) {
        reveal.observe(card);
      });
    } else {
      cards.forEach(function (card) {
        card.classList.add("is-visible");
      });
    }
  }

  // ---- Copy email ------------------------------------------------------------
  var copy = document.querySelector(".copy-email");
  var status = document.querySelector("[data-copy-status]");
  if (copy && navigator.clipboard && window.isSecureContext) {
    var label = copy.textContent;
    var timer;
    copy.hidden = false;
    copy.addEventListener("click", function () {
      navigator.clipboard.writeText(copy.dataset.copy).then(function () {
        copy.textContent = "Copied";
        if (status) status.textContent = "Email address copied";
        clearTimeout(timer);
        timer = setTimeout(function () {
          copy.textContent = label;
          if (status) status.textContent = "";
        }, 2000);
      });
    });
  }
})();
