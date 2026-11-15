<?php
declare(strict_types=1);

/**
 * v41: Community > Community Chat: the channels, private messages and the composer. The page is drawn by
 * assets/js/community.js, which talks to modules/community/api.php.
 */
$pageKey = 'comm.chat';
if (!Community::ready()) {
    layout_start('Community Chat');
    echo '<div class="alert alert-warning">Run database/migrations/2027_02_04_community.sql to set up the Community.</div>';
    layout_end();
    return;
}
if ($s = Community::sanction()) {
    if ($s['kind'] === 'suspend') {
        layout_start('Community Chat');
        echo '<div class="card"><div class="card-body"><h2 class="h5">Community access suspended</h2><p class="mb-0">' . h(Community::sanctionText($s)) . '.</p></div></div>';
        layout_end();
        return;
    }
}
$actions = (Access::page('comm.inquiries') ? btn_link(url('comm.inquiries'), 'Questions & Inquiries', 'btn-outline-secondary', 'patch-question') . ' ' : '')
    . (Access::page('comm.manage') ? btn_link(url('comm.manage'), 'Management', 'btn-outline-secondary', 'shield-check') . ' ' : '')
    . '<button type="button" class="btn btn-outline-secondary btn-sm" data-cm-open="settings"><i class="bi bi-gear"></i> Settings</button>';
layout_start('Community Chat', ['actions' => $actions, 'js' => ['js/community.js'], 'body_class' => 'cm-page']);
$reasons = Community::REPORT_REASONS;
?>
<div class="cm-app" id="cmApp" data-api="<?= h(url('comm.api')) ?>" data-home="<?= h(url('comm.chat')) ?>"
     data-ch="<?= h((string)g('ch')) ?>" data-dm="<?= (int)g('dm') ?>" data-m="<?= (int)g('m') ?>">
  <aside class="cm-side" id="cmSide" aria-label="Channels and private messages">
    <div class="cm-side-scroll">
      <div class="cm-side-head"><span>Channels</span></div>
      <nav class="cm-nav" id="cmChannels" aria-label="Channels"><div class="cm-skel"></div><div class="cm-skel"></div><div class="cm-skel"></div></nav>
      <div class="cm-side-head"><span>Private messages</span>
        <button type="button" class="cm-icon-btn" data-cm-open="newdm" title="New private message" aria-label="New private message"><i class="bi bi-pencil-square"></i></button></div>
      <nav class="cm-nav" id="cmDms" aria-label="Private messages"></nav>
    </div>
  </aside>
  <div class="cm-scrim" id="cmScrim" hidden></div>

  <section class="cm-main" aria-label="Messages">
    <header class="cm-head">
      <button type="button" class="cm-icon-btn cm-only-narrow" id="cmSideBtn" aria-label="Show channels" aria-controls="cmSide"><i class="bi bi-list"></i><span class="cm-side-dot" id="cmSideDot" hidden></span></button>
      <div class="cm-title-wrap">
        <h2 class="cm-title" id="cmTitle">Loading…</h2>
        <p class="cm-desc" id="cmDesc"></p>
      </div>
      <div class="cm-head-tools">
        <button type="button" class="cm-icon-btn" id="cmSearchBtn" title="Search this channel" aria-label="Search this channel" aria-expanded="false"><i class="bi bi-search"></i></button>
        <button type="button" class="cm-icon-btn" id="cmDmMenuBtn" hidden title="Block or report" aria-label="Block or report this person" data-bs-toggle="dropdown" aria-expanded="false"><i class="bi bi-three-dots-vertical"></i></button>
        <ul class="dropdown-menu dropdown-menu-end" id="cmDmMenu"></ul>
        <button type="button" class="cm-icon-btn" id="cmInfoBtn" title="Pinned messages and members" aria-label="Pinned messages and members" aria-controls="cmInfo"><i class="bi bi-layout-sidebar-reverse"></i></button>
      </div>
    </header>
    <form class="cm-search" id="cmSearch" hidden role="search">
      <input type="search" class="form-control form-control-sm" name="q" placeholder="Search messages in this channel" aria-label="Search messages">
      <select class="form-select form-select-sm" name="has" aria-label="Show">
        <option value="">All messages</option><option value="files">With files</option><option value="pinned">Pinned</option><option value="mentions">Mentioning me</option>
      </select>
      <button class="btn btn-sm btn-primary"><i class="bi bi-search"></i><span class="cm-hide-xs"> Search</span></button>
      <button type="button" class="btn btn-sm btn-outline-secondary" id="cmSearchClose">Close</button>
    </form>
    <div class="cm-results" id="cmResults" hidden></div>
    <div class="cm-banner" id="cmBanner" role="status" hidden></div>
    <div class="cm-scroll" id="cmScroll">
      <div class="cm-older"><button type="button" class="btn btn-sm btn-light" id="cmOlder" hidden><i class="bi bi-arrow-up"></i> Load earlier messages</button></div>
      <div class="cm-list" id="cmList" role="log" aria-live="polite" aria-relevant="additions"></div>
    </div>
    <button type="button" class="cm-newbar" id="cmNewBar" hidden><i class="bi bi-arrow-down"></i> New messages</button>

    <footer class="cm-composer" id="cmComposer">
      <div class="cm-context" id="cmContext" hidden><i class="bi" id="cmContextIco"></i><span id="cmContextText"></span>
        <button type="button" class="cm-icon-btn" id="cmContextClose" aria-label="Cancel"><i class="bi bi-x-lg"></i></button></div>
      <div class="cm-chips" id="cmChips"></div>
      <div class="cm-mentions" id="cmMentions" role="listbox" hidden></div>
      <div class="cm-emoji" id="cmEmoji" hidden></div>
      <div class="cm-compose-row">
        <label class="cm-icon-btn cm-attach" title="Attach files" aria-label="Attach files"><i class="bi bi-paperclip"></i>
          <input type="file" id="cmFile" multiple hidden></label>
        <button type="button" class="cm-icon-btn" id="cmEmojiBtn" title="Emoji" aria-label="Insert an emoji" aria-expanded="false"><i class="bi bi-emoji-smile"></i></button>
        <textarea id="cmInput" rows="1" maxlength="<?= Community::MAX_BODY ?>" placeholder="Write a message" aria-label="Message"></textarea>
        <button type="button" class="btn btn-primary cm-send" id="cmSend" aria-label="Send"><i class="bi bi-send-fill"></i></button>
      </div>
      <div class="cm-hint" id="cmHint">Enter sends, Shift+Enter starts a new line. Type @ to mention someone.</div>
      <div class="cm-readonly" id="cmReadonly" hidden></div>
    </footer>
  </section>

  <aside class="cm-info" id="cmInfo" aria-label="Channel information">
    <div class="cm-info-head"><span>About</span><button type="button" class="cm-icon-btn cm-only-narrow" id="cmInfoClose" aria-label="Close"><i class="bi bi-x-lg"></i></button></div>
    <div class="cm-info-body">
      <p class="cm-info-about" id="cmAbout"></p>
      <h3 class="cm-info-title"><i class="bi bi-pin-angle"></i> Pinned</h3>
      <div id="cmPinned" class="cm-pinned"><p class="cm-muted">No pinned messages.</p></div>
      <h3 class="cm-info-title"><i class="bi bi-circle-fill cm-online-dot"></i> Active now</h3>
      <div id="cmOnline" class="cm-online"></div>
    </div>
  </aside>
</div>

<!-- new private message -->
<div class="modal fade" id="cmNewDm" tabindex="-1" aria-labelledby="cmNewDmT"><div class="modal-dialog modal-dialog-scrollable modal-fullscreen-sm-down"><div class="modal-content">
  <div class="modal-header"><h5 class="modal-title" id="cmNewDmT">New private message</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
  <div class="modal-body">
    <input type="search" class="form-control" id="cmDmSearch" placeholder="Type a name or username" aria-label="Find a person" autocomplete="off">
    <div class="cm-people" id="cmDmPeople"><p class="cm-muted mt-2">Type at least one letter.</p></div>
  </div>
</div></div></div>

<!-- report -->
<div class="modal fade" id="cmReport" tabindex="-1" aria-labelledby="cmReportT"><div class="modal-dialog"><div class="modal-content"><form id="cmReportForm">
  <div class="modal-header"><h5 class="modal-title" id="cmReportT">Report</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
  <div class="modal-body">
    <p class="small text-muted" id="cmReportWhat"></p>
    <label class="form-label" for="cmReportReason">Reason</label>
    <select class="form-select" id="cmReportReason" required><option value="">Choose a reason</option>
      <?php foreach ($reasons as $k => $v): ?><option value="<?= h($k) ?>"><?= h($v) ?></option><?php endforeach; ?></select>
    <label class="form-label mt-2" for="cmReportDetails">Details (optional)</label>
    <textarea class="form-control" id="cmReportDetails" rows="3" maxlength="500"></textarea>
    <p class="small text-muted mt-2 mb-0">Moderators see the reported words and your reason. Your report is not shown to the person you report.</p>
  </div>
  <div class="modal-footer"><button type="button" class="btn btn-outline-secondary btn-sm" data-bs-dismiss="modal">Cancel</button><button class="btn btn-danger btn-sm"><i class="bi bi-flag"></i> Send report</button></div>
</form></div></div></div>

<!-- a moderator's reason (hide, delete) -->
<div class="modal fade" id="cmReason" tabindex="-1" aria-labelledby="cmReasonT"><div class="modal-dialog"><div class="modal-content"><form id="cmReasonForm">
  <div class="modal-header"><h5 class="modal-title" id="cmReasonT">Reason</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
  <div class="modal-body"><label class="form-label" for="cmReasonText" id="cmReasonLabel">Reason (recorded in the moderation log)</label>
    <input class="form-control" id="cmReasonText" maxlength="255" required></div>
  <div class="modal-footer"><button type="button" class="btn btn-outline-secondary btn-sm" data-bs-dismiss="modal">Cancel</button><button class="btn btn-primary btn-sm" id="cmReasonOk">Confirm</button></div>
</form></div></div></div>

<!-- settings -->
<div class="modal fade" id="cmSettings" tabindex="-1" aria-labelledby="cmSettingsT"><div class="modal-dialog modal-dialog-scrollable modal-fullscreen-sm-down"><div class="modal-content"><form id="cmSettingsForm">
  <div class="modal-header"><h5 class="modal-title" id="cmSettingsT">Community settings</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
  <div class="modal-body">
    <h6 class="cm-set-title">Your picture</h6>
    <div class="d-flex align-items-center gap-3 mb-3"><span id="cmSetAvatar"></span>
      <div><input type="file" class="form-control form-control-sm" name="avatar" accept=".jpg,.jpeg,.png,.gif,.webp" aria-label="Choose a picture">
        <div class="form-check mt-1"><input class="form-check-input" type="checkbox" name="remove_avatar" value="1" id="cmSetRm"><label class="form-check-label small" for="cmSetRm">Remove my picture</label></div></div></div>
    <h6 class="cm-set-title">Who may send you private messages</h6>
    <div class="mb-3">
      <div class="form-check"><input class="form-check-input" type="radio" name="dm_policy" value="everyone" id="cmDp1"><label class="form-check-label" for="cmDp1">Everyone in the community</label></div>
      <div class="form-check"><input class="form-check-input" type="radio" name="dm_policy" value="moderators" id="cmDp2"><label class="form-check-label" for="cmDp2">Moderators only</label></div>
      <div class="form-check"><input class="form-check-input" type="radio" name="dm_policy" value="nobody" id="cmDp3"><label class="form-check-label" for="cmDp3">Nobody</label></div>
    </div>
    <h6 class="cm-set-title">Notify me of</h6>
    <div class="mb-3">
      <div class="form-check form-switch"><input class="form-check-input" type="checkbox" name="notify_mentions" value="1" id="cmN1"><label class="form-check-label" for="cmN1">Mentions and replies to my messages</label></div>
      <div class="form-check form-switch"><input class="form-check-input" type="checkbox" name="notify_dm" value="1" id="cmN2"><label class="form-check-label" for="cmN2">New private messages</label></div>
      <div class="form-check form-switch"><input class="form-check-input" type="checkbox" name="notify_inquiries" value="1" id="cmN3"><label class="form-check-label" for="cmN3">Responses to my inquiries</label></div>
      <div class="form-check form-switch"><input class="form-check-input" type="checkbox" name="notify_announcements" value="1" id="cmN4"><label class="form-check-label" for="cmN4">Announcements</label></div>
    </div>
    <h6 class="cm-set-title">People you blocked</h6>
    <div id="cmBlocked" class="cm-people"></div>
  </div>
  <div class="modal-footer"><button type="button" class="btn btn-outline-secondary btn-sm" data-bs-dismiss="modal">Cancel</button><button class="btn btn-primary btn-sm"><i class="bi bi-check-lg"></i> Save</button></div>
</form></div></div></div>
<?php
layout_end();
