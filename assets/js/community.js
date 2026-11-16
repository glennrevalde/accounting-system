/* G-SMaRT Accounting - Community Chat (v41): channels, private messages, the composer and live updates.
   Talks to index.php?p=comm.api (modules/community/api.php). New messages arrive by polling: every 3 seconds while
   the page is in view, every 15 seconds in a background tab, slower after a failure. Every message carries a key
   made here, so one sent twice on a bad connection is kept once. Text from the server is already escaped. */
(function () {
  'use strict';
  const app = document.getElementById('cmApp');
  if (!app) return;
  const API = app.dataset.api;
  const HOME = app.dataset.home;
  const CSRF = (document.querySelector('meta[name="csrf-token"]') || {}).content || '';
  const $ = (id) => document.getElementById(id);
  const el = {
    side: $('cmSide'), scrim: $('cmScrim'), channels: $('cmChannels'), dms: $('cmDms'), sideBtn: $('cmSideBtn'), sideDot: $('cmSideDot'),
    title: $('cmTitle'), desc: $('cmDesc'), scroll: $('cmScroll'), list: $('cmList'), older: $('cmOlder'), newbar: $('cmNewBar'), banner: $('cmBanner'),
    info: $('cmInfo'), infoBtn: $('cmInfoBtn'), infoClose: $('cmInfoClose'), about: $('cmAbout'), pinned: $('cmPinned'), online: $('cmOnline'),
    input: $('cmInput'), send: $('cmSend'), file: $('cmFile'), chips: $('cmChips'), context: $('cmContext'), contextIco: $('cmContextIco'),
    contextText: $('cmContextText'), contextClose: $('cmContextClose'), mentions: $('cmMentions'), emoji: $('cmEmoji'), emojiBtn: $('cmEmojiBtn'),
    hint: $('cmHint'), readonly: $('cmReadonly'), composer: $('cmComposer'), searchBtn: $('cmSearchBtn'), search: $('cmSearch'),
    searchClose: $('cmSearchClose'), results: $('cmResults'), dmMenuBtn: $('cmDmMenuBtn'), dmMenu: $('cmDmMenu'),
  };
  const EMOJI = ['😀', '😁', '😂', '🙂', '😊', '😍', '😎', '🤔', '😅', '😮', '😢', '😡', '👍', '👎', '👏', '🙏', '💪', '👌', '✌️', '🤝', '❤️', '🎉',
    '🔥', '✅', '❌', '⚠️', '📌', '📎', '📄', '📊', '💡', '⏰', '📅', '☕', '🍔', '🎂', '🚀', '⭐'];
  const S = {
    me: null, rights: {}, view: null, msgs: [], byId: new Map(), lastId: 0, since: '', channels: [], dms: [], online: [], reactions: [], reasons: {},
    settings: {}, blocked: [], pinned: [], theirRead: 0, more: false, reply: null, edit: null, files: [], uploading: 0, timer: null,
    fails: 0, stopped: false, lastRead: 0, readTimer: null, maxFile: 0, maxFiles: 6, exts: [], notif: 0, loading: false, unreadBelow: 0,
  };
  const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const key = () => (Date.now().toString(36) + Math.random().toString(36).slice(2, 12)).slice(0, 24);
  const isNarrow = () => window.matchMedia('(max-width: 991.98px)').matches;
  const modal = (id) => bootstrap.Modal.getOrCreateInstance(document.getElementById(id));

  // ---------------------------------------------------------------- talking to the server
  class ApiError extends Error { constructor(msg, status, logout) { super(msg); this.status = status; this.logout = !!logout; } }
  async function parse(r) {
    if (!(r.headers.get('content-type') || '').includes('application/json')) throw new ApiError('Your session ended. Log in again to continue.', r.status, true);
    const j = await r.json();
    if (!j.ok) throw new ApiError(j.error || 'Something went wrong.', r.status, false);
    return j;
  }
  async function get(params, background) {
    const h = { Accept: 'application/json' };
    if (background) h['X-Background'] = '1';
    return parse(await fetch(API + '&' + new URLSearchParams(params).toString(), { credentials: 'same-origin', headers: h }));
  }
  async function post(a, data, files) {
    const fd = new FormData();
    fd.append('_csrf', CSRF);
    Object.keys(data || {}).forEach((k) => {
      const v = data[k];
      if (Array.isArray(v)) v.forEach((x) => fd.append(k + '[]', x)); else if (v !== undefined && v !== null) fd.append(k, v);
    });
    (files || []).forEach((f) => fd.append('files[]', f));
    return parse(await fetch(API + '&a=' + encodeURIComponent(a), { method: 'POST', body: fd, credentials: 'same-origin', headers: { Accept: 'application/json' } }));
  }
  function toast(msg, kind) {
    let box = document.querySelector('.cm-toasts');
    if (!box) { box = document.createElement('div'); box.className = 'cm-toasts'; box.setAttribute('role', 'status'); document.body.appendChild(box); }
    const t = document.createElement('div');
    t.className = 'cm-toast' + (kind === 'error' ? ' is-error' : '');
    t.textContent = msg;
    box.appendChild(t);
    setTimeout(() => t.remove(), kind === 'error' ? 6000 : 3500);
  }
  function banner(text, kind, html) {
    el.banner.hidden = !text;
    el.banner.className = 'cm-banner' + (kind ? ' is-' + kind : '');
    if (html) el.banner.innerHTML = text; else el.banner.textContent = text || '';
  }
  function failed(e) {
    if (e && e.logout) { stop(); S.stopped = true; banner('Your session ended. <a href="login.php">Log in again</a> to continue.', 'error', true); return; }
    toast(e && e.message ? e.message : 'Something went wrong. Try again.', 'error');
  }

  // ---------------------------------------------------------------- the sidebar
  function avatar(u, size) {
    const cls = 'cm-av cm-av-c' + (u.color || 0) + (size ? ' cm-av-' + size : '');
    return u.avatar ? '<span class="' + cls + '"><img src="' + esc(u.avatar) + '" alt="" loading="lazy"></span>' : '<span class="' + cls + '" aria-hidden="true">' + esc(u.initials) + '</span>';
  }
  function drawSide() {
    const v = S.view || {};
    const live = S.channels.filter((c) => !c.archived);
    const arch = S.channels.filter((c) => c.archived);
    const row = (c) => '<a href="' + esc(HOME + '&ch=' + c.slug) + '" class="cm-nav-item' + (v.type === 'channel' && v.id === c.id ? ' is-active' : '') + (c.unread ? ' has-unread' : '') + '" data-ch="' + esc(c.slug) + '"'
      + (v.type === 'channel' && v.id === c.id ? ' aria-current="page"' : '') + '>'
      + '<i class="bi bi-' + (c.kind === 'announcement' ? 'megaphone' : (c.restricted ? 'lock' : 'hash')) + '"></i><span class="cm-nav-name">' + esc(c.name) + '</span>'
      + (c.unread ? '<span class="cm-count" aria-label="' + c.unread + ' unread">' + (c.unread > 99 ? '99+' : c.unread) + '</span>' : '') + '</a>';
    el.channels.innerHTML = live.map(row).join('') + (arch.length ? '<div class="cm-nav-sub">Archived</div>' + arch.map(row).join('') : '');
    el.dms.innerHTML = S.dms.length ? S.dms.map((d) => '<a href="' + esc(HOME + '&dm=' + d.id) + '" class="cm-nav-item cm-nav-dm' + (v.type === 'dm' && v.id === d.id ? ' is-active' : '') + (d.unread ? ' has-unread' : '') + '" data-dm="' + d.id + '">'
      + avatar(d.user, 'xs') + '<span class="cm-nav-name">' + esc(d.user.name) + '<small>' + esc(d.last) + '</small></span>'
      + (d.unread ? '<span class="cm-count">' + d.unread + '</span>' : '') + '</a>').join('')
      : '<p class="cm-muted cm-nav-empty">No private messages yet.</p>';
    const any = S.channels.some((c) => c.unread && !(v.type === 'channel' && v.id === c.id)) || S.dms.some((d) => d.unread && !(v.type === 'dm' && v.id === d.id));
    el.sideDot.hidden = !any;
    const total = S.channels.reduce((s, c) => s + (c.unread || 0), 0) + S.dms.reduce((s, d) => s + (d.unread || 0), 0);
    document.title = (total ? '(' + total + ') ' : '') + document.title.replace(/^\(\d+\)\s/, '');
  }
  function drawInfo() {
    const v = S.view;
    if (!v) return;
    if (v.type === 'channel') {
      el.about.textContent = (v.channel.description || '') + (v.channel.mods_only ? ' Only moderators post here.' : '') + (v.channel.archived ? ' This channel is archived.' : '');
      el.pinned.innerHTML = S.pinned.length ? S.pinned.map((m) => '<button type="button" class="cm-pin" data-jump="' + m.id + '"><span class="cm-pin-who">' + esc(m.user.name) + ', ' + esc(m.full) + '</span>'
        + '<span class="cm-pin-text">' + (m.html ? m.html.replace(/<br>/g, ' ') : '(files)') + '</span></button>').join('') : '<p class="cm-muted">No pinned messages.</p>';
      el.pinned.parentElement.querySelectorAll('.cm-info-title')[0].hidden = false;
    } else {
      el.about.textContent = 'A private conversation with ' + v.user.name + '. Only the two of you can read it.';
      el.pinned.innerHTML = '';
      el.pinned.parentElement.querySelectorAll('.cm-info-title')[0].hidden = true;
    }
    el.online.innerHTML = S.online.length ? S.online.map((u) => '<button type="button" class="cm-person" data-user="' + u.id + '"' + (u.id === S.me.id ? ' disabled' : '') + ' title="' + (u.id === S.me.id ? 'You' : 'Send ' + esc(u.name) + ' a private message') + '">'
      + avatar(u, 'sm') + '<span>' + esc(u.name) + (u.mod ? '<small>Moderator</small>' : '') + '</span></button>').join('') : '<p class="cm-muted">Nobody else right now.</p>';
  }

  // ---------------------------------------------------------------- messages
  function dayLabel(day) {
    const d = new Date(day + 'T00:00:00');
    const t = new Date(); t.setHours(0, 0, 0, 0);
    const diff = Math.round((t - d) / 86400000);
    if (diff === 0) return 'Today';
    if (diff === 1) return 'Yesterday';
    return d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: d.getFullYear() === t.getFullYear() ? undefined : 'numeric' });
  }
  function fileIcon(n) {
    const e = (String(n).split('.').pop() || '').toLowerCase();
    if (e === 'pdf') return 'file-earmark-pdf';
    if (/^(docx?)$/.test(e)) return 'file-earmark-word';
    if (/^(xlsx?|csv)$/.test(e)) return 'file-earmark-excel';
    if (/^(pptx?)$/.test(e)) return 'file-earmark-ppt';
    if (e === 'zip') return 'file-earmark-zip';
    return 'file-earmark-text';
  }
  function msgHtml(m, compact) {
    const isDm = S.view.type === 'dm';
    let body;
    if (m.deleted) body = '<div class="cm-body cm-gone"><i class="bi bi-trash3"></i> This message was deleted.</div>';
    else if (m.hidden && !m.html) body = '<div class="cm-body cm-gone"><i class="bi bi-eye-slash"></i> This message was hidden by a moderator.</div>';
    else body = (m.html ? '<div class="cm-body">' + m.html + '</div>' : '');
    const imgs = (m.files || []).filter((f) => f.image);
    const docs = (m.files || []).filter((f) => !f.image);
    const files = (imgs.length ? '<div class="cm-imgs">' + imgs.map((f) => '<a href="' + esc(f.view) + '" target="_blank" rel="noopener" class="cm-img"><img src="' + esc(f.view) + '" alt="' + esc(f.name) + '" loading="lazy"></a>').join('') + '</div>' : '')
      + (docs.length ? '<div class="cm-docs">' + docs.map((f) => '<a href="' + esc(f.url) + '" class="cm-doc"><i class="bi bi-' + fileIcon(f.name) + '"></i><span>' + esc(f.name) + '<small>' + esc(f.size) + '</small></span></a>').join('') + '</div>' : '');
    const rx = (m.reactions || []).map((r) => '<button type="button" class="cm-rx' + (r.mine ? ' is-mine' : '') + '" data-act="react" data-e="' + esc(r.e) + '" title="' + esc(r.who) + '" aria-pressed="' + (r.mine ? 'true' : 'false') + '"'
      + (m.can.react ? '' : ' disabled') + '>' + r.e + ' <span>' + r.n + '</span></button>').join('');
    const reply = m.reply ? '<button type="button" class="cm-quote" data-jump="' + m.reply.id + '"><i class="bi bi-reply"></i><b>' + esc(m.reply.name) + '</b> ' + esc(m.reply.text) + '</button>' : '';
    let status = '';
    if (m._pending) status = '<span class="cm-status"><i class="bi bi-clock"></i> Sending…</span>';
    else if (m._failed) status = '<span class="cm-status is-failed"><i class="bi bi-exclamation-circle"></i> Not sent: ' + esc(m._failed) + ' <button type="button" class="btn btn-link btn-sm p-0" data-act="retry">Retry</button> <button type="button" class="btn btn-link btn-sm p-0" data-act="discard">Discard</button></span>';
    else if (isDm && m.own && m.id === S.lastOwnSeen) status = '<span class="cm-status"><i class="bi bi-check2-all"></i> Seen</span>';
    else if (m.own && m.id === S.lastOwnId && !isDm) status = '<span class="cm-status"><i class="bi bi-check2"></i> Sent</span>';
    const tools = m._pending || m._failed || m.deleted ? '' : '<div class="cm-tools">'
      + (m.can.react ? '<button type="button" class="cm-tool" data-act="rxpick" title="React" aria-label="React"><i class="bi bi-emoji-smile"></i></button>' : '')
      + (m.can.reply ? '<button type="button" class="cm-tool" data-act="reply" title="Reply" aria-label="Reply"><i class="bi bi-reply"></i></button>' : '')
      + '<div class="dropdown"><button type="button" class="cm-tool" data-bs-toggle="dropdown" aria-expanded="false" title="More" aria-label="More actions"><i class="bi bi-three-dots"></i></button><ul class="dropdown-menu dropdown-menu-end">'
      + (m.can.reply ? '<li class="cm-touch-only"><button class="dropdown-item" data-act="reply"><i class="bi bi-reply"></i> Reply</button></li>' : '')
      + (m.can.react ? '<li class="cm-touch-only"><button class="dropdown-item" data-act="rxpick"><i class="bi bi-emoji-smile"></i> React</button></li>' : '')
      + (m.can.edit ? '<li><button class="dropdown-item" data-act="edit"><i class="bi bi-pencil"></i> Edit</button></li>' : '')
      + (!isDm ? '<li><button class="dropdown-item" data-act="link"><i class="bi bi-link-45deg"></i> Copy link</button></li>' : '')
      + (m.can.pin ? '<li><button class="dropdown-item" data-act="pin"><i class="bi bi-pin-angle"></i> ' + (m.pinned ? 'Unpin' : 'Pin to channel') + '</button></li>' : '')
      + (m.can.hide ? '<li><button class="dropdown-item" data-act="hide"><i class="bi bi-eye' + (m.hidden ? '' : '-slash') + '"></i> ' + (m.hidden ? 'Show again' : 'Hide') + '</button></li>' : '')
      + (m.can.report ? '<li><button class="dropdown-item" data-act="report"><i class="bi bi-flag"></i> Report</button></li>' : '')
      + (m.can.delete ? '<li><hr class="dropdown-divider"></li><li><button class="dropdown-item text-danger" data-act="delete"><i class="bi bi-trash3"></i> Delete</button></li>' : '')
      + '</ul></div></div>';
    const cls = 'cm-msg' + (compact ? ' is-compact' : '') + (m.own ? ' is-own' : '') + (m.hidden ? ' is-hidden' : '') + (m.deleted ? ' is-deleted' : '')
      + (m.pinned ? ' is-pinned' : '') + (m.official ? ' is-official' : '') + (m._pending ? ' is-pending' : '') + (m._failed ? ' is-failed' : '');
    return '<div class="' + cls + '" data-id="' + esc(m.id) + '" id="m' + esc(m.id) + '">'
      + '<div class="cm-msg-av">' + (compact ? '<time class="cm-time-sm" title="' + esc(m.full) + '">' + esc(m.time) + '</time>' : avatar(m.user)) + '</div>'
      + '<div class="cm-msg-main">'
      + (compact ? '' : '<div class="cm-msg-head"><span class="cm-name">' + esc(m.user.name) + '</span>' + (m.user.mod ? '<span class="cm-role">Moderator</span>' : '')
        + (m.official ? '<span class="cm-role is-official">Official</span>' : '') + '<time title="' + esc(m.full) + '">' + esc(m.time) + '</time></div>')
      + reply + body + files
      + (m.edited && !m.deleted ? '<span class="cm-edited">(edited)</span>' : '')
      + (m.pinned ? '<span class="cm-pinned-flag"><i class="bi bi-pin-angle-fill"></i> Pinned</span>' : '')
      + (m.hidden && m.html ? '<span class="cm-hidden-flag"><i class="bi bi-eye-slash"></i> Hidden' + (m.hidden_reason ? ': ' + esc(m.hidden_reason) : '') + '</span>' : '')
      + (rx ? '<div class="cm-rxs">' + rx + '</div>' : '')
      + status + '</div>' + tools + '</div>';
  }
  function grouped(prev, m) {
    if (!prev || prev.user.id !== m.user.id || prev.day !== m.day || m.reply || prev.deleted || m.official) return false;
    return (new Date(m.at.replace(' ', 'T')) - new Date(prev.at.replace(' ', 'T'))) < 5 * 60000;
  }
  function render(keepBottom) {
    const atBottom = keepBottom === 'top' ? false : (keepBottom === undefined ? nearBottom() : keepBottom);
    const prevH = el.scroll.scrollHeight, prevTop = el.scroll.scrollTop;
    const own = S.msgs.filter((m) => m.own && !m._pending && !m._failed && !m.deleted && typeof m.id === 'number');
    S.lastOwnId = own.length ? own[own.length - 1].id : 0;
    S.lastOwnSeen = S.view && S.view.type === 'dm' ? (own.filter((m) => m.id <= S.theirRead).pop() || {}).id || 0 : 0;
    const old = new Map();
    el.list.querySelectorAll('.cm-msg').forEach((n) => old.set(n.dataset.id, n));
    const frag = document.createDocumentFragment();
    let prev = null;
    if (!S.msgs.length) {
      const empty = document.createElement('div');
      empty.className = 'cm-empty';
      empty.innerHTML = '<i class="bi bi-chat-square-text"></i><p>' + (S.view.type === 'dm' ? 'No messages yet. Say hello to ' + esc(S.view.user.name) + '.' : 'No messages in this channel yet. Start the conversation.') + '</p>';
      frag.appendChild(empty);
    }
    S.msgs.forEach((m) => {
      if (!prev || prev.day !== m.day) {
        const d = document.createElement('div');
        d.className = 'cm-day';
        d.innerHTML = '<span>' + esc(dayLabel(m.day)) + '</span>';
        frag.appendChild(d);
      }
      const compact = grouped(prev, m);
      const html = msgHtml(m, compact);
      let node = old.get(String(m.id));
      if (!node || node._html !== html) {
        const t = document.createElement('div');
        t.innerHTML = html;
        node = t.firstChild;
        node._html = html;
      }
      frag.appendChild(node);
      prev = m;
    });
    el.list.replaceChildren(frag);
    if (atBottom) toBottom();
    else el.scroll.scrollTop = prevTop + (keepBottom === 'top' ? el.scroll.scrollHeight - prevH : 0);
  }
  function nearBottom() { return el.scroll.scrollHeight - el.scroll.scrollTop - el.scroll.clientHeight < 80; }
  function toBottom() { el.scroll.scrollTop = el.scroll.scrollHeight; el.newbar.hidden = true; S.unreadBelow = 0; }
  function put(list) {
    list.forEach((m) => {
      if (!m) return;
      const i = S.msgs.findIndex((x) => x.id === m.id);
      if (i >= 0) S.msgs[i] = m; else S.msgs.push(m);
      if (typeof m.id === 'number' && m.id > S.lastId) S.lastId = m.id;
    });
    S.msgs.sort((a, b) => (typeof a.id === 'number' ? a.id : 9e15) - (typeof b.id === 'number' ? b.id : 9e15));
  }
  function jump(id) {
    const n = document.getElementById('m' + id);
    if (n) {
      n.scrollIntoView({ block: 'center', behavior: 'smooth' });
      n.classList.add('is-focus');
      setTimeout(() => n.classList.remove('is-focus'), 2200);
      return true;
    }
    if (S.view.type === 'channel') open({ ch: S.view.channel.slug, m: id });
    return false;
  }

  // ---------------------------------------------------------------- opening a channel or a conversation
  async function open(target, push) {
    stop();
    S.loading = true;
    cancelContext();
    el.list.innerHTML = '<div class="cm-loading"><span class="spinner-border spinner-border-sm"></span> Loading messages…</div>';
    try {
      const params = { a: 'boot' };
      if (target.dm) params.dm = target.dm; else if (target.ch) params.ch = target.ch;
      if (target.m) params.m = target.m;
      const j = await get(params);
      S.me = j.me; S.rights = j.rights; S.channels = j.channels; S.dms = j.dms; S.online = j.online; S.reactions = j.reactions; S.reasons = j.reasons;
      S.maxFile = j.max_file; S.maxFiles = j.max_files; S.exts = j.exts; S.settings = j.settings; S.blocked = j.blocked; S.notif = j.notif;
      S.since = j.now; S.msgs = []; S.lastId = 0; S.view = j.view || null; S.pinned = (j.view && j.view.pinned) || []; S.theirRead = (j.view && j.view.their_read) || 0;
      S.more = !!(j.view && j.view.more); S.lastRead = 0;
      window.dispatchEvent(new CustomEvent('comm:notif', { detail: S.notif }));
      if (!S.view) {
        el.title.textContent = 'No channels';
        el.desc.textContent = 'No channel is open to you yet. Ask a moderator.';
        el.list.innerHTML = '';
        el.composer.hidden = true;
        drawSide();
        return;
      }
      put(S.view.messages || []);
      if (push !== false) {
        const url = HOME + (S.view.type === 'dm' ? '&dm=' + S.view.id : '&ch=' + encodeURIComponent(S.view.channel.slug));
        const st = { dm: S.view.type === 'dm' ? S.view.id : 0, ch: S.view.type === 'channel' ? S.view.channel.slug : '' };
        if (push === 'replace') history.replaceState(st, '', url); else history.pushState(st, '', url);
      }
      head();
      drawSide();
      drawInfo();
      composerState();
      el.older.hidden = !S.more;
      render(true);
      if (target.m || (j.view && j.view.focus)) setTimeout(() => jump(target.m || j.view.focus), 60);
      if (j.sanction) banner(j.sanction + '.', 'warn'); else banner('');
      markRead();
      if (isNarrow()) closeSide();
    } catch (e) {
      el.list.innerHTML = '<div class="cm-empty"><i class="bi bi-exclamation-triangle"></i><p>' + esc(e.message || 'Could not load the messages.') + '</p></div>';
      failed(e);
    } finally {
      S.loading = false;
      if (!S.stopped || S.view) schedule(800);
    }
  }
  function head() {
    const v = S.view;
    if (v.type === 'channel') {
      el.title.innerHTML = '<i class="bi bi-' + (v.channel.kind === 'announcement' ? 'megaphone' : (v.channel.restricted ? 'lock' : 'hash')) + '"></i> ' + esc(v.channel.name);
      el.desc.textContent = v.channel.description || '';
      el.searchBtn.hidden = false;
      el.dmMenuBtn.hidden = true;
    } else {
      el.title.innerHTML = avatar(v.user, 'sm') + ' ' + esc(v.user.name) + (v.user.mod ? ' <span class="cm-role">Moderator</span>' : '');
      el.desc.textContent = 'Private conversation';
      el.searchBtn.hidden = true;
      el.dmMenuBtn.hidden = false;
      el.dmMenu.innerHTML = '<li><button class="dropdown-item" data-dmact="' + (v.blocked ? 'unblock' : 'block') + '"><i class="bi bi-slash-circle"></i> ' + (v.blocked ? 'Unblock ' : 'Block ') + esc(v.user.name) + '</button></li>'
        + '<li><button class="dropdown-item" data-dmact="report"><i class="bi bi-flag"></i> Report ' + esc(v.user.name) + '</button></li>';
    }
    closeSearch();
  }
  function composerState() {
    const v = S.view;
    let why = '';
    if (!S.rights.post) why = S.rights && S.me ? 'You can read the community, but your role may not post. Ask your administrator if you need to.' : '';
    if (v.type === 'channel') {
      if (v.channel.archived) why = 'This channel is archived. You can read it, but not post.';
      else if (!v.channel.can_post) why = v.channel.mods_only ? 'Only moderators post in ' + v.channel.name + '.' : (why || 'You cannot post here.');
    } else if (v.refusal) why = v.refusal;
    el.readonly.hidden = !why;
    el.readonly.textContent = why;
    el.composer.querySelector('.cm-compose-row').hidden = !!why;
    el.hint.hidden = !!why;
    el.chips.hidden = !!why;
    el.composer.hidden = false;
    el.input.placeholder = isNarrow() ? 'Write a message' : (v.type === 'dm' ? 'Message ' + v.user.name : 'Message ' + (v.channel ? '#' + v.channel.name : ''));
  }

  // ---------------------------------------------------------------- live updates
  function stop() { clearTimeout(S.timer); S.timer = null; }
  function schedule(ms) {
    stop();
    if (S.stopped) return;
    S.timer = setTimeout(poll, ms !== undefined ? ms : (document.hidden ? 15000 : 3000));
  }
  async function poll() {
    if (!S.view || S.loading) { schedule(); return; }
    const v = S.view;
    // the people active now are asked for every 30 seconds
    const wantOnline = !S.onlineAt || Date.now() - S.onlineAt > 30000;
    if (wantOnline) S.onlineAt = Date.now();
    const p = { a: 'poll', after: S.lastId, since: S.since, online: wantOnline ? '1' : '0' };
    if (v.type === 'dm') p.dm = v.id; else p.ch = v.id;
    try {
      const j = await get(p, true);
      if (S.view !== v) return;      // another channel was opened meanwhile
      S.fails = 0;
      if (el.banner.classList.contains('is-offline')) banner('');
      S.since = j.now;
      const fresh = j.messages || [];
      const wasBottom = nearBottom();
      // a message of this user still shown as "sending" is replaced by the server's copy (same key)
      fresh.forEach((m) => { const t = S.msgs.findIndex((x) => x._key && m.key && x._key === m.key); if (t >= 0) S.msgs.splice(t, 1); });
      const newOthers = fresh.filter((m) => !S.msgs.some((x) => x.id === m.id) && !m.own);
      put(fresh);
      put(j.changed || []);
      if (j.pinned) S.pinned = j.pinned;
      if (j.their_read !== undefined) S.theirRead = j.their_read;
      if (j.channel) { v.channel = j.channel; }
      S.channels.forEach((c) => { c.unread = (j.counts && j.counts[c.id]) || 0; });
      S.dms = j.dms || S.dms;
      if (j.online) S.online = j.online;
      if (S.notif !== j.notif) { S.notif = j.notif; window.dispatchEvent(new CustomEvent('comm:notif', { detail: j.notif })); }
      if (fresh.length || (j.changed || []).length || j.their_read !== undefined) render(wasBottom);
      if (newOthers.length && !wasBottom) { S.unreadBelow += newOthers.length; el.newbar.hidden = false; el.newbar.innerHTML = '<i class="bi bi-arrow-down"></i> ' + S.unreadBelow + ' new message' + (S.unreadBelow === 1 ? '' : 's'); }
      if (j.pinned || j.online) drawInfo();
      drawSide();
      markRead();
    } catch (e) {
      if (e.logout) { failed(e); return; }
      S.fails++;
      if (S.fails >= 2) banner('Connection lost. Trying again…', 'offline');
      schedule(Math.min(30000, 3000 * Math.pow(2, S.fails - 1)));
      return;
    }
    schedule();
  }
  function markRead() {
    if (!S.view || document.hidden || !nearBottom()) return;
    const last = S.msgs.filter((m) => typeof m.id === 'number').map((m) => m.id).pop() || 0;
    if (!last || last <= S.lastRead) return;
    S.lastRead = last;
    clearTimeout(S.readTimer);
    S.readTimer = setTimeout(async () => {
      try {
        const v = S.view;
        const j = await post('read', v.type === 'dm' ? { dm: v.id, last } : { ch: v.id, last });
        if (v.type === 'channel') { const c = S.channels.find((x) => x.id === v.id); if (c) c.unread = 0; } else { const d = S.dms.find((x) => x.id === v.id); if (d) d.unread = 0; }
        if (j.notif !== S.notif) { S.notif = j.notif; window.dispatchEvent(new CustomEvent('comm:notif', { detail: j.notif })); }
        drawSide();
      } catch (e) { /* tried again with the next message */ }
    }, 600);
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden) { markRead(); schedule(200); } });
  window.addEventListener('online', () => schedule(200));
  el.scroll.addEventListener('scroll', () => { if (nearBottom()) { el.newbar.hidden = true; S.unreadBelow = 0; markRead(); } });
  el.newbar.addEventListener('click', toBottom);

  // ---------------------------------------------------------------- earlier messages
  el.older.addEventListener('click', async () => {
    const first = S.msgs.find((m) => typeof m.id === 'number');
    if (!first) return;
    el.older.disabled = true;
    try {
      const v = S.view;
      const j = await get(v.type === 'dm' ? { a: 'older', dm: v.id, before: first.id } : { a: 'older', ch: v.id, before: first.id });
      put(j.messages);
      S.more = j.more;
      el.older.hidden = !S.more;
      render('top');
    } catch (e) { failed(e); } finally { el.older.disabled = false; }
  });

  // ---------------------------------------------------------------- the composer
  function grow() { el.input.style.height = 'auto'; el.input.style.height = Math.min(180, el.input.scrollHeight) + 'px'; }
  el.input.addEventListener('input', () => { grow(); mentionLookup(); });
  function setContext(kind, m) {
    S.reply = kind === 'reply' ? m : null;
    S.edit = kind === 'edit' ? m : null;
    el.context.hidden = false;
    el.contextIco.className = 'bi bi-' + (kind === 'reply' ? 'reply' : 'pencil');
    el.contextText.innerHTML = kind === 'reply' ? 'Replying to <b>' + esc(m.user.name) + '</b>' : 'Editing your message';
    if (kind === 'edit') { el.input.value = m.raw; grow(); }
    el.input.focus();
  }
  function cancelContext() {
    if (S.edit) { el.input.value = ''; grow(); }
    S.reply = null; S.edit = null; el.context.hidden = true;
  }
  el.contextClose.addEventListener('click', cancelContext);
  el.input.addEventListener('keydown', (e) => {
    if (!el.mentions.hidden && ['ArrowDown', 'ArrowUp', 'Enter', 'Tab', 'Escape'].includes(e.key)) { mentionKey(e); return; }
    if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); send(); return; }
    if (e.key === 'Escape') { cancelContext(); el.emoji.hidden = true; return; }
    if (e.key === 'ArrowUp' && !el.input.value) {
      const mine = S.msgs.filter((m) => m.own && m.can && m.can.edit).pop();
      if (mine) { e.preventDefault(); setContext('edit', mine); }
    }
  });
  el.send.addEventListener('click', send);

  async function send() {
    const v = S.view;
    if (!v) return;
    const body = el.input.value.replace(/\s+$/, '');
    if (S.uploading) { toast('Wait for the files to finish uploading.'); return; }
    if (S.edit) {
      const m = S.edit;
      if (!body.trim()) { toast('A message cannot be empty. Delete it instead.', 'error'); return; }
      el.send.disabled = true;
      try {
        const j = await post('edit', { id: m.id, body, scope: v.type === 'dm' ? 'dm' : 'message' });
        put([j.message]); cancelContext(); el.input.value = ''; grow(); render();
      } catch (e) { failed(e); } finally { el.send.disabled = false; }
      return;
    }
    if (!body.trim() && !S.files.length) return;
    const k = key();
    const temp = { id: 't' + k, _key: k, _pending: true, own: true, user: S.me, html: esc(body).replace(/\n/g, '<br>'), raw: body, files: S.files.map((f) => ({ ...f })),
      reactions: [], reply: S.reply ? { id: S.reply.id, name: S.reply.user.name, text: (S.reply.raw || '').slice(0, 120) } : null,
      at: new Date().toISOString().slice(0, 19).replace('T', ' '), day: new Date().toISOString().slice(0, 10), time: 'now', full: 'Sending', can: {},
      _send: { body, reply: S.reply ? S.reply.id : '', files: S.files.map((f) => f.id), dest: v.type === 'dm' ? { dm: v.id } : { ch: v.id } } };
    temp.day = S.msgs.length ? S.msgs[S.msgs.length - 1].day : temp.day;
    S.msgs.push(temp);
    el.input.value = ''; grow(); S.files = []; drawChips(); cancelContext();
    render(true);
    deliver(temp);
  }
  async function deliver(temp) {
    const v = S.view;
    temp._pending = true; temp._failed = '';
    render();
    try {
      const j = await post('send', { ...temp._send.dest, body: temp._send.body, reply: temp._send.reply, key: temp._key, files: temp._send.files });
      if (S.view !== v) return;
      const i = S.msgs.indexOf(temp);
      if (i >= 0) S.msgs.splice(i, 1);
      put([j.message]);
      render(true);
      S.lastRead = Math.max(S.lastRead, j.message.id);
    } catch (e) {
      temp._pending = false;
      temp._failed = e.logout ? 'your session ended' : (e.message || 'no connection');
      render();
      if (e.logout) failed(e);
    }
  }

  // files: uploaded as soon as they are chosen, sent with the message
  function drawChips() {
    el.chips.innerHTML = S.files.map((f, i) => '<span class="cm-chip' + (f.busy ? ' is-busy' : '') + '">' + (f.image && f.url ? '<img src="' + esc(f.url) + '" alt="">' : '<i class="bi bi-' + fileIcon(f.name) + '"></i>')
      + '<span>' + esc(f.name) + '<small>' + (f.busy ? 'Uploading…' : esc(f.size)) + '</small></span>'
      + (f.busy ? '<span class="spinner-border spinner-border-sm"></span>' : '<button type="button" class="cm-chip-x" data-i="' + i + '" aria-label="Remove ' + esc(f.name) + '"><i class="bi bi-x"></i></button>') + '</span>').join('');
  }
  el.chips.addEventListener('click', (e) => { const b = e.target.closest('.cm-chip-x'); if (b) { S.files.splice(+b.dataset.i, 1); drawChips(); } });
  async function addFiles(list) {
    const files = Array.from(list || []);
    const room = S.maxFiles - S.files.length;
    if (files.length > room) toast('At most ' + S.maxFiles + ' files on one message.', 'error');
    const ok = [];
    files.slice(0, Math.max(0, room)).forEach((f) => {
      const ext = (f.name.split('.').pop() || '').toLowerCase();
      if (!S.exts.includes(ext)) toast('"' + f.name + '" cannot be attached. Pictures, PDF, Word, Excel, PowerPoint, CSV, text and ZIP files only.', 'error');
      else if (f.size > S.maxFile) toast('"' + f.name + '" is larger than ' + (S.maxFile / 1048576).toFixed(1) + ' MB.', 'error');
      else ok.push(f);
    });
    for (const f of ok) {
      const slot = { name: f.name, size: '', busy: true };
      S.files.push(slot); S.uploading++; drawChips();
      try {
        const j = await post('upload', {}, [f]);
        if (j.files && j.files[0]) Object.assign(slot, j.files[0], { busy: false });
        else { S.files.splice(S.files.indexOf(slot), 1); toast(j.error || 'The file was not accepted.', 'error'); }
      } catch (e) { S.files.splice(S.files.indexOf(slot), 1); failed(e); } finally { S.uploading--; drawChips(); }
    }
  }
  el.file.addEventListener('change', () => { addFiles(el.file.files); el.file.value = ''; });
  el.scroll.addEventListener('dragover', (e) => { if (!el.composer.querySelector('.cm-compose-row').hidden) { e.preventDefault(); app.classList.add('is-drop'); } });
  el.scroll.addEventListener('dragleave', () => app.classList.remove('is-drop'));
  el.scroll.addEventListener('drop', (e) => { e.preventDefault(); app.classList.remove('is-drop'); if (e.dataTransfer && e.dataTransfer.files.length) addFiles(e.dataTransfer.files); });
  el.input.addEventListener('paste', (e) => { const f = e.clipboardData && e.clipboardData.files; if (f && f.length) { e.preventDefault(); addFiles(f); } });

  // emoji
  el.emoji.innerHTML = EMOJI.map((x) => '<button type="button" data-emo="' + x + '" aria-label="' + x + '">' + x + '</button>').join('');
  el.emojiBtn.addEventListener('click', () => { el.emoji.hidden = !el.emoji.hidden; el.emojiBtn.setAttribute('aria-expanded', String(!el.emoji.hidden)); });
  el.emoji.addEventListener('click', (e) => {
    const b = e.target.closest('[data-emo]');
    if (!b) return;
    insertText(b.dataset.emo);
    el.emoji.hidden = true;
  });
  function insertText(t) {
    const s = el.input.selectionStart || el.input.value.length, en = el.input.selectionEnd || s;
    el.input.value = el.input.value.slice(0, s) + t + el.input.value.slice(en);
    el.input.selectionStart = el.input.selectionEnd = s + t.length;
    el.input.focus(); grow();
  }

  // @mentions
  let mTimer = null, mItems = [], mIdx = 0;
  function mentionWord() {
    const upto = el.input.value.slice(0, el.input.selectionStart);
    const m = upto.match(/(?:^|\s)@([A-Za-z0-9._-]{0,30})$/);
    return m ? m[1] : null;
  }
  function mentionLookup() {
    const w = mentionWord();
    clearTimeout(mTimer);
    if (w === null) { el.mentions.hidden = true; return; }
    mTimer = setTimeout(async () => {
      try {
        const j = await get({ a: 'users', q: w });
        mItems = j.users.filter((u) => u.id !== S.me.id);
        mIdx = 0;
        drawMentions();
      } catch (e) { el.mentions.hidden = true; }
    }, 180);
  }
  function drawMentions() {
    el.mentions.hidden = !mItems.length;
    el.mentions.innerHTML = mItems.map((u, i) => '<button type="button" role="option" class="cm-mention-opt' + (i === mIdx ? ' is-on' : '') + '" data-i="' + i + '" aria-selected="' + (i === mIdx) + '">'
      + avatar(u, 'xs') + '<span>' + esc(u.name) + ' <small>@' + esc(u.username) + '</small></span></button>').join('');
  }
  function pickMention(i) {
    const u = mItems[i];
    if (!u) return;
    const pos = el.input.selectionStart;
    const upto = el.input.value.slice(0, pos);
    const start = upto.lastIndexOf('@');
    el.input.value = el.input.value.slice(0, start) + '@' + u.username + ' ' + el.input.value.slice(pos);
    el.input.selectionStart = el.input.selectionEnd = start + u.username.length + 2;
    el.mentions.hidden = true;
    el.input.focus();
  }
  function mentionKey(e) {
    e.preventDefault();
    if (e.key === 'Escape') { el.mentions.hidden = true; return; }
    if (e.key === 'ArrowDown') mIdx = (mIdx + 1) % mItems.length;
    else if (e.key === 'ArrowUp') mIdx = (mIdx - 1 + mItems.length) % mItems.length;
    else { pickMention(mIdx); return; }
    drawMentions();
  }
  el.mentions.addEventListener('mousedown', (e) => { const b = e.target.closest('[data-i]'); if (b) { e.preventDefault(); pickMention(+b.dataset.i); } });

  // ---------------------------------------------------------------- what a message offers
  let rxPop = null;
  function closeRx() { if (rxPop) { rxPop.remove(); rxPop = null; } }
  document.addEventListener('click', (e) => { if (rxPop && !e.target.closest('.cm-rxpop') && !e.target.closest('[data-act="rxpick"]')) closeRx(); if (!e.target.closest('#cmEmoji') && !e.target.closest('#cmEmojiBtn')) el.emoji.hidden = true; });
  el.list.addEventListener('click', async (e) => {
    const j = e.target.closest('[data-jump]');
    if (j) { jump(+j.dataset.jump); return; }
    const b = e.target.closest('[data-act]');
    if (!b) return;
    const node = b.closest('.cm-msg');
    const id = node ? node.dataset.id : null;
    const m = S.msgs.find((x) => String(x.id) === id);
    if (!m) return;
    const act = b.dataset.act;
    const scope = S.view.type === 'dm' ? 'dm' : 'message';
    try {
      if (act === 'retry') { deliver(m); return; }
      if (act === 'discard') { S.msgs.splice(S.msgs.indexOf(m), 1); render(); return; }
      if (act === 'reply') { setContext('reply', m); return; }
      if (act === 'edit') { setContext('edit', m); return; }
      if (act === 'link') {
        const u = location.origin + location.pathname + '?p=comm.chat&ch=' + encodeURIComponent(S.view.channel.slug) + '&m=' + m.id;
        try { await navigator.clipboard.writeText(u); toast('Link copied.'); } catch (er) { window.prompt('Copy the link to this message:', u); }
        return;
      }
      if (act === 'react') { const r = await post('react', { id: m.id, emoji: b.dataset.e }); put([r.message]); render(); return; }
      if (act === 'rxpick') {
        closeRx();
        rxPop = document.createElement('div');
        rxPop.className = 'cm-rxpop';
        rxPop.innerHTML = S.reactions.map((x) => '<button type="button" data-e="' + x + '" aria-label="React with ' + x + '">' + x + '</button>').join('');
        node.querySelector('.cm-msg-main').appendChild(rxPop);
        rxPop.addEventListener('click', async (ev) => {
          const x = ev.target.closest('[data-e]');
          if (!x) return;
          closeRx();
          try { const r = await post('react', { id: m.id, emoji: x.dataset.e }); put([r.message]); render(); } catch (er) { failed(er); }
        });
        return;
      }
      if (act === 'pin') { const r = await post('pin', { id: m.id, on: m.pinned ? '0' : '1' }); put([r.message]); S.pinned = r.pinned || S.pinned; render(); drawInfo(); toast(m.pinned ? 'Unpinned.' : 'Pinned to the channel.'); return; }
      if (act === 'hide') {
        if (m.hidden) { const r = await post('hide', { id: m.id, on: '0' }); put([r.message]); render(); return; }
        askReason('Hide this message', 'Reason (the author sees it; recorded in the moderation log)', async (reason) => { const r = await post('hide', { id: m.id, on: '1', reason }); put([r.message]); render(); toast('The message is hidden.'); });
        return;
      }
      if (act === 'delete') {
        if (!m.own) { askReason('Delete this message', 'Reason (recorded in the moderation log)', async (reason) => { const r = await post('delete', { id: m.id, scope, reason }); put([r.message]); render(); }); return; }
        if (!confirm('Delete this message? It cannot be brought back.')) return;
        const r = await post('delete', { id: m.id, scope });
        put([r.message]); render();
        return;
      }
      if (act === 'report') { openReport(scope, m.id, 'Report the message of ' + m.user.name + '.'); return; }
    } catch (er) { failed(er); }
  });

  // reasons, reports
  let reasonFn = null;
  function askReason(title, label, fn) {
    document.getElementById('cmReasonT').textContent = title;
    document.getElementById('cmReasonLabel').textContent = label;
    document.getElementById('cmReasonText').value = '';
    reasonFn = fn;
    modal('cmReason').show();
    setTimeout(() => document.getElementById('cmReasonText').focus(), 300);
  }
  document.getElementById('cmReasonForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const t = document.getElementById('cmReasonText').value.trim();
    if (!t || !reasonFn) return;
    try { await reasonFn(t); modal('cmReason').hide(); } catch (er) { failed(er); }
  });
  let reportOf = null;
  function openReport(type, id, what) {
    reportOf = { type, id };
    document.getElementById('cmReportWhat').textContent = what;
    document.getElementById('cmReportReason').value = '';
    document.getElementById('cmReportDetails').value = '';
    modal('cmReport').show();
  }
  document.getElementById('cmReportForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const reason = document.getElementById('cmReportReason').value;
    if (!reason || !reportOf) return;
    try {
      const j = await post('report', { type: reportOf.type, id: reportOf.id, reason, details: document.getElementById('cmReportDetails').value });
      modal('cmReport').hide();
      toast(j.text);
    } catch (er) { failed(er); }
  });

  // ---------------------------------------------------------------- search
  function closeSearch() { el.search.hidden = true; el.results.hidden = true; el.searchBtn.setAttribute('aria-expanded', 'false'); }
  el.searchBtn.addEventListener('click', () => {
    const show = el.search.hidden;
    if (!show) { closeSearch(); return; }
    el.search.hidden = false;
    el.searchBtn.setAttribute('aria-expanded', 'true');
    el.search.q.focus();
  });
  el.searchClose.addEventListener('click', closeSearch);
  el.search.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!S.view || S.view.type !== 'channel') return;
    el.results.hidden = false;
    el.results.innerHTML = '<div class="cm-loading"><span class="spinner-border spinner-border-sm"></span> Searching…</div>';
    try {
      const j = await get({ a: 'search', ch: S.view.id, q: el.search.q.value, has: el.search.has.value });
      el.results.innerHTML = '<div class="cm-results-head">' + j.messages.length + (j.messages.length === 50 ? '+' : '') + ' result' + (j.messages.length === 1 ? '' : 's') + '</div>'
        + (j.messages.length ? j.messages.map((m) => '<button type="button" class="cm-result" data-jump="' + m.id + '">' + avatar(m.user, 'xs')
          + '<span><b>' + esc(m.user.name) + '</b> <small>' + esc(m.full) + '</small><span class="cm-result-text">' + (m.html || '(files)') + '</span></span></button>').join('')
          : '<p class="cm-muted p-2 mb-0">Nothing found.</p>');
    } catch (er) { el.results.innerHTML = ''; failed(er); }
  });
  el.results.addEventListener('click', (e) => { const b = e.target.closest('[data-jump]'); if (b && !e.target.closest('a')) { closeSearch(); jump(+b.dataset.jump); } });
  el.pinned.addEventListener('click', (e) => { const b = e.target.closest('[data-jump]'); if (b && !e.target.closest('a')) { if (isNarrow()) closeInfo(); jump(+b.dataset.jump); } });

  // ---------------------------------------------------------------- sidebars
  function openSide() { el.side.classList.add('is-open'); el.scrim.hidden = false; }
  function closeSide() { el.side.classList.remove('is-open'); if (!el.info.classList.contains('is-open')) el.scrim.hidden = true; }
  function openInfo() { el.info.classList.add('is-open'); if (isNarrow()) el.scrim.hidden = false; app.classList.remove('info-off'); }
  function closeInfo() { el.info.classList.remove('is-open'); if (!el.side.classList.contains('is-open')) el.scrim.hidden = true; }
  el.sideBtn.addEventListener('click', openSide);
  el.scrim.addEventListener('click', () => { closeSide(); closeInfo(); });
  el.infoBtn.addEventListener('click', () => {
    if (isNarrow()) { openInfo(); return; }
    app.classList.toggle('info-off');
    try { localStorage.setItem('cmInfoOff', app.classList.contains('info-off') ? '1' : '0'); } catch (e) { /* no storage */ }
  });
  el.infoClose.addEventListener('click', closeInfo);
  try { if (localStorage.getItem('cmInfoOff') === '1') app.classList.add('info-off'); } catch (e) { /* no storage */ }
  app.addEventListener('click', (e) => {
    const a = e.target.closest('a[data-ch], a[data-dm]');
    if (a && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
      e.preventDefault();
      open(a.dataset.dm ? { dm: +a.dataset.dm } : { ch: a.dataset.ch });
      return;
    }
    const p = e.target.closest('.cm-person[data-user]');
    if (p) startDm(+p.dataset.user);
  });
  window.addEventListener('popstate', (e) => { const s = e.state || {}; if (s.dm) open({ dm: s.dm }, false); else if (s.ch) open({ ch: s.ch }, false); });

  // ---------------------------------------------------------------- private messages
  async function startDm(uid) {
    try {
      const j = await post('dm_start', { user: uid });
      bootstrap.Modal.getInstance(document.getElementById('cmNewDm'))?.hide();
      closeInfo();
      open({ dm: j.id });
    } catch (e) { failed(e); }
  }
  const dmSearch = document.getElementById('cmDmSearch');
  const dmPeople = document.getElementById('cmDmPeople');
  let dmTimer = null;
  dmSearch.addEventListener('input', () => {
    clearTimeout(dmTimer);
    const q = dmSearch.value.trim();
    if (!q) { dmPeople.innerHTML = '<p class="cm-muted mt-2">Type at least one letter.</p>'; return; }
    dmTimer = setTimeout(async () => {
      try {
        const j = await get({ a: 'users', q, for: 'dm' });
        dmPeople.innerHTML = j.users.length ? j.users.map((u) => '<button type="button" class="cm-person cm-person-row" data-pick="' + u.id + '"' + (u.refusal ? ' disabled' : '') + '>' + avatar(u, 'sm')
          + '<span>' + esc(u.name) + ' <small>@' + esc(u.username) + (u.refusal ? ' : ' + esc(u.refusal) : '') + '</small></span></button>').join('') : '<p class="cm-muted mt-2">Nobody found.</p>';
      } catch (e) { failed(e); }
    }, 200);
  });
  dmPeople.addEventListener('click', (e) => { const b = e.target.closest('[data-pick]'); if (b && !b.disabled) startDm(+b.dataset.pick); });
  el.dmMenu.addEventListener('click', async (e) => {
    const b = e.target.closest('[data-dmact]');
    if (!b || !S.view || S.view.type !== 'dm') return;
    const u = S.view.user;
    try {
      if (b.dataset.dmact === 'report') { openReport('user', u.id, 'Report ' + u.name + '. To report one message, use Report on the message.'); return; }
      const on = b.dataset.dmact === 'block';
      if (on && !confirm('Block ' + u.name + '? Neither of you can send private messages to the other until you unblock.')) return;
      await post('block', { user: u.id, on: on ? '1' : '0' });
      toast(on ? u.name + ' is blocked.' : u.name + ' is unblocked.');
      open({ dm: S.view.id }, false);
    } catch (er) { failed(er); }
  });

  // ---------------------------------------------------------------- settings
  const setForm = document.getElementById('cmSettingsForm');
  function fillSettings() {
    const s = S.settings || {};
    setForm.querySelectorAll('[name="dm_policy"]').forEach((r) => { r.checked = r.value === (s.dm_policy || 'everyone'); });
    ['notify_mentions', 'notify_dm', 'notify_inquiries', 'notify_announcements'].forEach((k) => { setForm[k].checked = String(s[k] ?? '1') === '1'; });
    setForm.avatar.value = '';
    setForm.remove_avatar.checked = false;
    document.getElementById('cmSetAvatar').innerHTML = S.me ? avatar(S.me, 'lg') : '';
    const bl = document.getElementById('cmBlocked');
    bl.innerHTML = S.blocked.length ? S.blocked.map((u) => '<div class="cm-person cm-person-row">' + avatar(u, 'sm') + '<span>' + esc(u.name) + '</span><button type="button" class="btn btn-sm btn-outline-secondary ms-auto" data-unblock="' + u.id + '">Unblock</button></div>').join('')
      : '<p class="cm-muted">Nobody.</p>';
  }
  document.getElementById('cmBlocked').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-unblock]');
    if (!b) return;
    try { const j = await post('block', { user: b.dataset.unblock, on: '0' }); S.blocked = j.blocked; fillSettings(); } catch (er) { failed(er); }
  });
  setForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
      dm_policy: (setForm.querySelector('[name="dm_policy"]:checked') || {}).value || 'everyone',
      notify_mentions: setForm.notify_mentions.checked ? '1' : '0', notify_dm: setForm.notify_dm.checked ? '1' : '0',
      notify_inquiries: setForm.notify_inquiries.checked ? '1' : '0', notify_announcements: setForm.notify_announcements.checked ? '1' : '0',
      remove_avatar: setForm.remove_avatar.checked ? '1' : '0',
    };
    const fd = new FormData();
    fd.append('_csrf', CSRF);
    Object.keys(data).forEach((k) => fd.append(k, data[k]));
    if (setForm.avatar.files[0]) fd.append('avatar', setForm.avatar.files[0]);
    try {
      const j = await parse(await fetch(API + '&a=settings', { method: 'POST', body: fd, credentials: 'same-origin', headers: { Accept: 'application/json' } }));
      S.settings = j.settings; S.me = Object.assign(S.me || {}, j.me);
      modal('cmSettings').hide();
      toast('Settings saved.');
      open(S.view && S.view.type === 'dm' ? { dm: S.view.id } : { ch: S.view ? S.view.channel.slug : '' }, false);
    } catch (er) { failed(er); }
  });
  document.querySelectorAll('[data-cm-open]').forEach((b) => b.addEventListener('click', () => {
    if (b.dataset.cmOpen === 'settings') { fillSettings(); modal('cmSettings').show(); }
    if (b.dataset.cmOpen === 'newdm') { dmSearch.value = ''; dmPeople.innerHTML = '<p class="cm-muted mt-2">Type at least one letter.</p>'; modal('cmNewDm').show(); setTimeout(() => dmSearch.focus(), 300); }
  }));

  // ---------------------------------------------------------------- size: the chat fills the window below the page bar
  function fit() {
    const top = app.getBoundingClientRect().top + window.scrollY;
    const h = Math.max(380, window.innerHeight - top - 12);
    app.style.height = h + 'px';
  }
  window.addEventListener('resize', fit);
  fit();

  open({ ch: app.dataset.ch, dm: +app.dataset.dm || 0, m: +app.dataset.m || 0 }, 'replace');
})();
