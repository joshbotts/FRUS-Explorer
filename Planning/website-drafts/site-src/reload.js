// Reloads the page when build_site.py --watch writes a new build. It reads site/build-stamp.txt
// once a second and reloads when the stamp changes. Opened as a file, or with no watch running,
// it does nothing that shows.
(function () {
  if (!/^https?:$/.test(location.protocol)) return;
  var url = new URL('build-stamp.txt', document.currentScript ? document.currentScript.src : location.href).href;
  var last = null;
  function check() {
    fetch(url, { cache: 'no-store' }).then(function (r) { return r.ok ? r.text() : null; }).then(function (s) {
      if (s === null) return;
      if (last !== null && s !== last) { location.reload(); return; }
      last = s;
    }).catch(function () {}).then(function () { setTimeout(check, 1000); });
  }
  check();
})();
