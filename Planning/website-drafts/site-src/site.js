// The review bar's two switches, kept across pages in this browser: coming soon or at launch, and the
// review notes on or off. Storage can be missing (a private window), so every read and write is guarded.
(function () {
  function get(k, d) { try { return localStorage.getItem(k) || d; } catch (e) { return d; } }
  function put(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  var q = new URLSearchParams(location.search);
  var state = q.get('state') || get('frus-walk-state', 'soon');
  var notes = (q.get('notes') || get('frus-walk-notes', 'on')) === 'on';
  function setState(s) {
    state = s; document.body.setAttribute('data-state', s); put('frus-walk-state', s);
    document.querySelectorAll('[data-state-btn]').forEach(function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-state-btn') === s ? 'true' : 'false');
    });
  }
  function setNotes(on) {
    notes = on; document.body.classList.toggle('hide-notes', !on); put('frus-walk-notes', on ? 'on' : 'off');
    var b = document.getElementById('notes-btn');
    if (b) { b.setAttribute('aria-pressed', on ? 'true' : 'false'); b.textContent = 'Review notes: ' + (on ? 'on' : 'off'); }
  }
  document.querySelectorAll('[data-state-btn]').forEach(function (b) {
    b.addEventListener('click', function () { setState(b.getAttribute('data-state-btn')); });
  });
  var nb = document.getElementById('notes-btn');
  if (nb) nb.addEventListener('click', function () { setNotes(!notes); });
  setState(state); setNotes(notes);
})();
