/*
 * v42: Digital voucher signatures (Sign Voucher page, the signature link page sign.php, the Signatures box).
 *
 *  - the signature pad: mouse, finger or stylus (pointer events), smooth ink, Undo, Clear, a larger pad on phones.
 *    The drawing is kept in pad units (600 x 200) whatever the size on screen, and sent as strokes:
 *    {"w":600,"h":200,"s":[[x,y,x,y,...],...]}; the server draws the same curves on the PDF.
 *  - Submit is enabled once there is a signature, a line is chosen and the review box is ticked; the confirmation
 *    dialog shows the signature before it is sent; the button shows it is working and cannot be pressed twice.
 *  - the voucher viewer: Page (fitted to the screen width) or PDF (loaded when first shown).
 *  - Copy link / Share for the signature links; the new link dialog opens by itself.
 */
(function () {
  'use strict';
  var W = 600, H = 200, MIN_STEP = 1.4;

  // ------------------------------------------------------------------ the pad
  function Pad(root) {
    this.root = root;
    this.area = root.querySelector('.sig-pad-area');
    this.canvas = root.querySelector('canvas');
    this.ctx = this.canvas.getContext('2d');
    this.data = root.querySelector('[data-sig-data]');
    this.strokes = [];
    this.cur = null;
    this.ratio = 1;
    var self = this;
    this.resize();
    window.addEventListener('resize', function () { self.resize(); });
    if (window.ResizeObserver) new ResizeObserver(function () { self.resize(); }).observe(this.area);
    var c = this.canvas;
    c.addEventListener('pointerdown', function (e) { self.down(e); });
    c.addEventListener('pointermove', function (e) { self.move(e); });
    ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(function (n) { c.addEventListener(n, function (e) { self.up(e); }); });
    c.addEventListener('touchmove', function (e) { e.preventDefault(); }, { passive: false });
    this.undone = [];
    root.querySelector('[data-sig-undo]').addEventListener('click', function () { if (self.strokes.length) self.undone.push(self.strokes.pop()); self.changed(); });
    root.querySelector('[data-sig-redo]').addEventListener('click', function () { if (self.undone.length) self.strokes.push(self.undone.pop()); self.changed(); });
    root.querySelector('[data-sig-clear]').addEventListener('click', function () { self.strokes = []; self.undone = []; self.changed(); });
    var ex = root.querySelector('[data-sig-expand]');
    if (ex) ex.addEventListener('click', function () { self.full(true); });
    var c2 = root.querySelector('[data-sig-clear2]');
    if (c2) c2.addEventListener('click', function () { self.strokes = []; self.undone = []; self.changed(); });
    var done = root.querySelector('[data-sig-collapse]');
    if (done) done.addEventListener('click', function () { self.full(false); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && root.classList.contains('is-full')) self.full(false); });
  }
  Pad.prototype.full = function (on) {
    this.root.classList.toggle('is-full', on);
    document.body.classList.toggle('sig-pad-open', on);
    this.resize();
  };
  Pad.prototype.resize = function () {
    var cs = getComputedStyle(this.area);
    var avail = this.area.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
    if (!avail) return;
    var full = this.root.classList.contains('is-full');
    if (avail === this.lastW && full === this.lastFull && window.innerHeight === this.lastH) return;
    this.lastW = avail; this.lastFull = full; this.lastH = window.innerHeight;
    // 3 : 1, the same shape as the pad units, so nothing is stretched
    var w = avail, h = w / 3;
    if (full) {
      var maxH = window.innerHeight - 120;
      if (h > maxH) { h = maxH; w = h * 3; }
    }
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    var dpr = window.devicePixelRatio || 1;
    this.canvas.width = Math.round(w * dpr);
    this.canvas.height = Math.round(h * dpr);
    this.ratio = w / W;
    this.ctx.setTransform(dpr * this.ratio, 0, 0, dpr * this.ratio, 0, 0);
    this.redraw();
  };
  Pad.prototype.point = function (e) {
    var r = this.canvas.getBoundingClientRect();
    var x = (e.clientX - r.left) / r.width * W, y = (e.clientY - r.top) / r.height * H;
    return [Math.max(0, Math.min(W, Math.round(x * 10) / 10)), Math.max(0, Math.min(H, Math.round(y * 10) / 10))];
  };
  Pad.prototype.down = function (e) {
    if (e.button !== undefined && e.button > 0) return;
    e.preventDefault();
    try { this.canvas.setPointerCapture(e.pointerId); } catch (err) { /* old browsers */ }
    var p = this.point(e);
    this.cur = [p[0], p[1]];
    this.strokes.push(this.cur);
    this.undone = [];
    this.root.classList.add('has-ink');
    this.redraw();
  };
  Pad.prototype.move = function (e) {
    if (!this.cur) return;
    e.preventDefault();
    var evs = e.getCoalescedEvents ? e.getCoalescedEvents() : [e];
    if (!evs.length) evs = [e];
    for (var i = 0; i < evs.length; i++) {
      var p = this.point(evs[i]), s = this.cur, n = s.length;
      if (Math.hypot(p[0] - s[n - 2], p[1] - s[n - 1]) < MIN_STEP) continue;
      s.push(p[0], p[1]);
    }
    this.redraw();
  };
  Pad.prototype.up = function () {
    if (!this.cur) return;
    this.cur = null;
    this.changed();
  };
  Pad.prototype.redraw = function () {
    var ctx = this.ctx;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.restore();
    ctx.strokeStyle = '#172a6b';
    ctx.fillStyle = '#172a6b';
    ctx.lineWidth = 2.6;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    this.strokes.forEach(function (s) { draw(ctx, s); });
  };
  Pad.prototype.changed = function () {
    this.redraw();
    var has = this.strokes.length > 0;
    this.root.classList.toggle('has-ink', has);
    this.data.value = has ? JSON.stringify({ w: W, h: H, s: this.strokes }) : '';
    this.root.querySelector('[data-sig-undo]').disabled = !has;
    this.root.querySelector('[data-sig-clear]').disabled = !has;
    this.root.querySelector('[data-sig-redo]').disabled = !this.undone.length;
    this.root.dispatchEvent(new CustomEvent('sig:change', { bubbles: true }));
  };
  Pad.prototype.svg = function () {
    // the same curves as the server draws
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity, d = '';
    this.strokes.forEach(function (s) {
      for (var i = 0; i < s.length; i += 2) { minX = Math.min(minX, s[i]); maxX = Math.max(maxX, s[i]); minY = Math.min(minY, s[i + 1]); maxY = Math.max(maxY, s[i + 1]); }
      d += path(s);
    });
    if (!d) return '';
    var p = 6;
    return '<svg viewBox="' + (minX - p) + ' ' + (minY - p) + ' ' + (maxX - minX + 2 * p) + ' ' + (maxY - minY + 2 * p) + '" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg">'
      + '<path d="' + d + '" fill="none" stroke="#172a6b" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/></svg>';
  };

  function draw(ctx, s) {
    var n = s.length / 2;
    ctx.beginPath();
    ctx.moveTo(s[0], s[1]);
    if (n === 1) {
      ctx.arc(s[0], s[1], 1.3, 0, Math.PI * 2);
      ctx.fill();
      return;
    }
    for (var i = 1; i < n - 1; i++) {
      var x = s[2 * i], y = s[2 * i + 1];
      ctx.quadraticCurveTo(x, y, (x + s[2 * i + 2]) / 2, (y + s[2 * i + 3]) / 2);
    }
    ctx.lineTo(s[2 * n - 2], s[2 * n - 1]);
    ctx.stroke();
  }
  function path(s) {
    var n = s.length / 2, d = 'M' + s[0] + ' ' + s[1];
    if (n === 1) return d + 'l0.1 0';
    for (var i = 1; i < n - 1; i++) {
      d += 'Q' + s[2 * i] + ' ' + s[2 * i + 1] + ' ' + ((s[2 * i] + s[2 * i + 2]) / 2) + ' ' + ((s[2 * i + 1] + s[2 * i + 3]) / 2);
    }
    return d + 'L' + s[2 * n - 2] + ' ' + s[2 * n - 1];
  }

  // ------------------------------------------------------------------ the signing form
  document.querySelectorAll('[data-sig-form]').forEach(function (form) {
    var padEl = form.querySelector('[data-sig-pad]');
    var pad = padEl ? new Pad(padEl) : null;
    var consent = form.querySelector('[data-sig-consent]');
    var submit = form.querySelector('[data-sig-submit]');
    var modalEl = form.dataset.sigConfirm ? document.querySelector(form.dataset.sigConfirm) : null;
    var sending = false;
    function ok() {
      var slot = form.querySelector('input[name="slot"]');
      var slotOk = !slot || !!form.querySelector('input[name="slot"]:checked');
      return pad && pad.strokes.length > 0 && (!consent || consent.checked) && slotOk;
    }
    function refresh() { if (submit && !sending) submit.disabled = !ok(); }
    form.addEventListener('sig:change', refresh);
    form.addEventListener('change', refresh);
    refresh();
    function send() {
      if (sending) return;
      sending = true;
      [submit, modalEl && modalEl.querySelector('[data-sig-final]')].forEach(function (b) {
        if (!b) return;
        b.disabled = true;
        var sp = b.querySelector('.spinner-border');
        if (sp) sp.classList.remove('d-none');
        else b.insertAdjacentHTML('afterbegin', '<span class="spinner-border spinner-border-sm" aria-hidden="true"></span> ');
      });
      form.classList.add('is-sending');
      HTMLFormElement.prototype.submit.call(form);
    }
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      if (!ok() || sending) return;
      if (modalEl && window.bootstrap) {
        var prev = modalEl.querySelector('[data-sig-preview]');
        if (prev) prev.innerHTML = pad.svg();
        bootstrap.Modal.getOrCreateInstance(modalEl).show();
      } else if (window.confirm('Submit your signature? It cannot be changed afterwards.')) {
        send();
      }
    });
    if (modalEl) {
      var fin = modalEl.querySelector('[data-sig-final]');
      if (fin) fin.addEventListener('click', send);
    }
  });

  // ------------------------------------------------------------------ the voucher viewer
  document.querySelectorAll('[data-sig-doc]').forEach(function (box) {
    var paper = box.querySelector('[data-sig-paper]');
    var sheet = paper && paper.querySelector('.sig-paper-sheet');
    var pdf = box.querySelector('[data-sig-pdf]');
    var frame = pdf && pdf.querySelector('iframe');
    var SHEET = 760;
    function fit() {
      if (!sheet || paper.classList.contains('d-none')) return;
      var avail = paper.clientWidth - 2;
      var k = Math.min(1, avail / SHEET);
      sheet.style.width = SHEET + 'px';
      sheet.style.transform = k < 1 ? 'scale(' + k + ')' : '';
      paper.style.height = k < 1 ? Math.ceil(sheet.offsetHeight * k + 4) + 'px' : '';
    }
    function show(which) {
      box.querySelectorAll('[data-sig-view]').forEach(function (b) { b.classList.toggle('active', b.dataset.sigView === which); b.setAttribute('aria-pressed', b.dataset.sigView === which ? 'true' : 'false'); });
      paper.classList.toggle('d-none', which !== 'page');
      pdf.classList.toggle('d-none', which !== 'pdf');
      if (which === 'pdf' && frame && !frame.getAttribute('src')) frame.setAttribute('src', frame.dataset.src);
      fit();
    }
    box.querySelectorAll('[data-sig-view]').forEach(function (b) { b.addEventListener('click', function () { show(b.dataset.sigView); }); });
    window.addEventListener('resize', fit);
    // the PDF on large screens; the fitted page on phones and tablets, whose browsers often cannot show a PDF in a page
    show(window.matchMedia('(min-width: 992px)').matches && !/iPhone|iPad|Android/i.test(navigator.userAgent) ? 'pdf' : 'page');
    window.addEventListener('load', fit);
  });

  // ------------------------------------------------------------------ copy and share the link
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    return new Promise(function (resolve, reject) {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy') ? resolve() : reject(); } catch (err) { reject(err); }
      ta.remove();
    });
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest('[data-copy]');
    if (!b) return;
    var label = b.querySelector('span');
    var before = label ? label.textContent : '';
    copyText(b.dataset.copy).then(function () {
      b.classList.add('is-copied');
      if (label) label.textContent = 'Copied';
      setTimeout(function () { b.classList.remove('is-copied'); if (label) label.textContent = before; }, 1800);
    }, function () {
      window.prompt('Copy the link:', b.dataset.copy);
    });
  });
  document.querySelectorAll('[data-share]').forEach(function (b) {
    if (!navigator.share) return;
    b.classList.remove('d-none');
    b.addEventListener('click', function () {
      navigator.share({ title: b.dataset.shareTitle || document.title, url: b.dataset.share }).catch(function () { /* closed */ });
    });
  });
  document.querySelectorAll('[data-select-all]').forEach(function (i) {
    i.addEventListener('focus', function () { i.select(); });
  });
  // busy state on plain forms (Request Signature)
  document.querySelectorAll('form[data-busy]').forEach(function (f) {
    f.addEventListener('submit', function () {
      var b = f.querySelector('button:not([type="button"])');
      if (b) setTimeout(function () { b.disabled = true; b.insertAdjacentHTML('afterbegin', '<span class="spinner-border spinner-border-sm" aria-hidden="true"></span> '); }, 0);
    });
  });
  window.addEventListener('load', function () {
    var m = document.querySelector('.modal[data-show-now]');
    if (m && window.bootstrap) bootstrap.Modal.getOrCreateInstance(m).show();
  });
})();
