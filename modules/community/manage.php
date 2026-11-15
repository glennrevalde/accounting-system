<?php
declare(strict_types=1);

/**
 * v41: Community > Community Management, for the moderators: activity, unresolved inquiries, reports, announcements,
 * channels, inquiry categories, mutes and suspensions, and the moderation log. Every action is checked against the
 * rights on this page (see app/Community.php) and written to the moderation log and the audit trail.
 * Private messages are never listed here; a reported private message is seen only as the words that were reported.
 */
$pageKey = 'comm.manage';
if (!Community::ready()) {
    layout_start('Community Management');
    echo '<div class="alert alert-warning">Run database/migrations/2027_02_04_community.sql to set up the Community.</div>';
    layout_end();
    return;
}
$tab = (string)g('tab', 'overview');
$tabs = ['overview' => ['Overview', 'speedometer2'], 'reports' => ['Reports', 'flag'], 'channels' => ['Channels', 'hash'], 'categories' => ['Inquiry categories', 'tags'],
    'members' => ['Members', 'people'], 'log' => ['Moderation log', 'journal-text']];
if (!isset($tabs[$tab])) {
    $tab = 'overview';
}
$now = Community::now();
$need = function (string $right, string $what): void {
    if (!Access::can('comm.manage', $right)) {
        fail('Your role may not ' . $what . ' (it needs the ' . ucfirst($right) . ' right on Community Management).');
    }
};

handle_post(function () use ($pageKey, $need, $now) {
    $act = (string)p('act');
    $back = current_url();
    switch ($act) {
        case 'announce': {
            $need('edit', 'publish announcements');
            $c = Community::channel((int)p('channel'));
            if (!$c || $c['kind'] !== 'announcement') {
                fail('Choose the announcement channel.');
            }
            $title = trim((string)p('title'));
            $body = trim((string)p('body'));
            $text = ($title !== '' ? $title . "\n\n" : '') . $body;
            [$ids, $problems] = Community::takeUploads('files');
            $id = Community::post($c, $text, null, Community::clientKey(p('key')), $ids);
            if (p('pin') === '1') {
                Community::setPinned($id, true);
            }
            Community::log('announce', 'message', $id, null, '', Community::excerpt($text, 200));
            foreach ($problems as $pr) {
                flash('warning', $pr);
            }
            flash('success', 'The announcement was published in ' . $c['name'] . ' and everyone was notified.');
            redirect(url($pageKey));
        }
        case 'report': {
            $need('edit', 'handle reports');
            $r = DB::row('SELECT * FROM community_reports WHERE id = :id', ['id' => (int)p('id')]);
            if (!$r) {
                fail('The report was not found.');
            }
            $do = (string)p('do');
            if ($do === 'hide' && in_array($r['target_type'], ['message', 'inquiry', 'response'], true)) {
                Community::setHidden($r['target_type'], (int)$r['target_id'], true, (string)p('note') ?: 'Reported: ' . (Community::REPORT_REASONS[$r['reason']] ?? $r['reason']));
                Community::handleReport((int)$r['id'], 'actioned', 'Hidden. ' . (string)p('note'));
                // the other open reports of the same post are closed with it
                DB::run("UPDATE community_reports SET status = 'actioned', handled_by = :u, handled_at = :n, resolution = 'Hidden (another report)' WHERE target_type = :t AND target_id = :i AND status = 'open'",
                    ['u' => Community::me(), 'n' => $now, 't' => $r['target_type'], 'i' => (int)$r['target_id']]);
                flash('success', 'The post is hidden and the report is closed.');
            } elseif ($do === 'actioned' || $do === 'dismissed') {
                Community::handleReport((int)$r['id'], $do, (string)p('note'));
                flash('success', $do === 'dismissed' ? 'The report was dismissed.' : 'The report is closed.');
            } else {
                fail('Choose what to do with the report.');
            }
            redirect(url($pageKey, ['tab' => 'reports']));
        }
        case 'sanction': {
            $until = match ((string)p('length')) {
                '1h' => date('Y-m-d H:i:s', time() + 3600), '1d' => date('Y-m-d H:i:s', time() + 86400), '7d' => date('Y-m-d H:i:s', time() + 7 * 86400),
                '30d' => date('Y-m-d H:i:s', time() + 30 * 86400), default => null,
            };
            Community::sanctionUser((int)p('user'), (string)p('kind'), (string)p('reason'), $until);
            flash('success', (p('kind') === 'suspend' ? 'Suspended: ' : 'Muted: ') . Community::user((int)p('user'))['name'] . '.');
            redirect(url($pageKey, ['tab' => 'members']));
        }
        case 'lift':
            Community::liftSanction((int)p('id'));
            flash('success', 'Lifted.');
            redirect(url($pageKey, ['tab' => 'members']));
        case 'channel_save': {
            $need('create', 'manage channels');
            $id = (int)p('id');
            $name = trim((string)p('name'));
            if (mb_strlen($name) < 2 || mb_strlen($name) > 80) {
                fail('The channel name needs 2 to 80 characters.');
            }
            $row = ['name' => $name, 'description' => mb_substr(trim((string)p('description')), 0, 255) ?: null,
                'kind' => p('kind') === 'announcement' ? 'announcement' : 'chat', 'post_policy' => p('post_policy') === 'moderators' || p('kind') === 'announcement' ? 'moderators' : 'everyone',
                'is_restricted' => p('restricted') === '1' ? 1 : 0, 'updated_at' => $now];
            $roles = array_values(array_filter(array_map('intval', (array)($_POST['roles'] ?? []))));
            if ($row['is_restricted'] && !$roles) {
                fail('A restricted channel needs at least one role that may see it (moderators always do).');
            }
            DB::tx(function () use (&$id, $row, $roles, $name, $now) {
                if ($id) {
                    DB::update('community_channels', $row, 'id = :id', ['id' => $id]);
                } else {
                    $slug = trim(preg_replace('/[^a-z0-9]+/', '-', strtolower($name)) ?? '', '-') ?: 'channel';
                    $slug = substr($slug, 0, 30);
                    $base = $slug;
                    for ($i = 2; DB::value('SELECT 1 FROM community_channels WHERE slug = :s', ['s' => $slug]); $i++) {
                        $slug = $base . '-' . $i;
                    }
                    $id = (int)DB::insert('community_channels', $row + ['slug' => $slug, 'sort_order' => (int)DB::value('SELECT COALESCE(MAX(sort_order), 0) + 10 FROM community_channels'),
                        'created_by' => Community::me(), 'created_at' => $now]);
                }
                DB::run('DELETE FROM community_channel_roles WHERE channel_id = :c', ['c' => $id]);
                foreach ($row['is_restricted'] ? $roles : [] as $r) {
                    DB::run('INSERT IGNORE INTO community_channel_roles (channel_id, role_id) VALUES (:c, :r)', ['c' => $id, 'r' => $r]);
                }
            });
            Community::log((int)p('id') ? 'channel_edit' : 'channel_create', 'channel', $id, null, '', $name . ($row['is_restricted'] ? ' (restricted)' : ''));
            flash('success', 'Channel saved.');
            redirect(url($pageKey, ['tab' => 'channels']));
        }
        case 'channel_archive': {
            $need('create', 'manage channels');
            $c = Community::channel((int)p('id'));
            if (!$c) {
                fail('Channel not found.');
            }
            $on = p('on') === '1';
            if ($on && (int)DB::value('SELECT COUNT(*) FROM community_channels WHERE is_archived = 0') <= 1) {
                fail('Keep at least one channel open.');
            }
            DB::update('community_channels', ['is_archived' => $on ? 1 : 0, 'updated_at' => $now], 'id = :id', ['id' => (int)$c['id']]);
            Community::log($on ? 'channel_archive' : 'channel_restore', 'channel', (int)$c['id'], null, '', $c['name']);
            flash('success', $c['name'] . ($on ? ' is archived: it can be read but not posted in, and only moderators see it.' : ' is open again.'));
            redirect(url($pageKey, ['tab' => 'channels']));
        }
        case 'channel_move': {
            $need('create', 'manage channels');
            $ids = array_map('intval', DB::column('SELECT id FROM community_channels ORDER BY sort_order, id'));
            $i = array_search((int)p('id'), $ids, true);
            $j = $i === false ? false : $i + (p('dir') === 'up' ? -1 : 1);
            if ($i !== false && $j >= 0 && $j < count($ids)) {
                [$ids[$i], $ids[$j]] = [$ids[$j], $ids[$i]];
                foreach ($ids as $n => $cid) {
                    DB::update('community_channels', ['sort_order' => ($n + 1) * 10], 'id = :id', ['id' => $cid]);
                }
            }
            redirect(url($pageKey, ['tab' => 'channels']));
        }
        case 'category_save': {
            $need('create', 'manage categories');
            $name = trim((string)p('name'));
            if (mb_strlen($name) < 2 || mb_strlen($name) > 80) {
                fail('The category name needs 2 to 80 characters.');
            }
            $id = (int)p('id');
            if (DB::value('SELECT 1 FROM community_inquiry_categories WHERE name = :n AND id <> :i', ['n' => $name, 'i' => $id])) {
                fail('There is already a category named ' . $name . '.');
            }
            $row = ['name' => $name, 'description' => mb_substr(trim((string)p('description')), 0, 255) ?: null, 'is_active' => p('is_active', '1') === '1' ? 1 : 0];
            if ($id) {
                DB::update('community_inquiry_categories', $row, 'id = :id', ['id' => $id]);
            } else {
                $id = (int)DB::insert('community_inquiry_categories', $row + ['sort_order' => (int)DB::value('SELECT COALESCE(MAX(sort_order), 0) + 10 FROM community_inquiry_categories')]);
            }
            Community::log((int)p('id') ? 'category_edit' : 'category_create', 'category', $id, null, '', $name . ($row['is_active'] ? '' : ' (not in use)'));
            flash('success', 'Category saved.');
            redirect(url($pageKey, ['tab' => 'categories']));
        }
    }
    fail('Unknown action.');
});

$actions = btn_link(url('comm.chat'), 'Community Chat', 'btn-outline-secondary', 'chat-dots') . ' ' . btn_link(url('comm.inquiries'), 'Questions & Inquiries', 'btn-outline-secondary', 'patch-question');
layout_start('Community Management', ['actions' => $actions]);
echo form_error();
$openReports = (int)DB::value("SELECT COUNT(*) FROM community_reports WHERE status = 'open'");
?>
<nav class="iq-tabs cmm-tabs" aria-label="Sections">
  <?php foreach ($tabs as $k => [$label, $icon]): ?>
    <a class="iq-tab<?= $tab === $k ? ' is-on' : '' ?>" href="<?= h(url($pageKey, ['tab' => $k])) ?>"<?= $tab === $k ? ' aria-current="page"' : '' ?>><i class="bi bi-<?= $icon ?>"></i> <?= h($label) ?>
      <?php if ($k === 'reports' && $openReports): ?><span><?= $openReports ?></span><?php endif; ?></a>
  <?php endforeach; ?>
</nav>
<?php

// ======================================================================= overview
if ($tab === 'overview'):
    $d1 = date('Y-m-d 00:00:00');
    $d7 = date('Y-m-d H:i:s', time() - 7 * 86400);
    $stats = [
        ['Messages today', (int)DB::value('SELECT COUNT(*) FROM community_messages WHERE created_at >= :d AND deleted_at IS NULL', ['d' => $d1]), 'chat-dots'],
        ['Messages, last 7 days', (int)DB::value('SELECT COUNT(*) FROM community_messages WHERE created_at >= :d AND deleted_at IS NULL', ['d' => $d7]), 'chat-square-text'],
        ['Active members, 7 days', (int)DB::value('SELECT COUNT(*) FROM community_settings WHERE last_seen_at >= :d', ['d' => $d7]), 'people'],
        ['Open inquiries', (int)DB::value("SELECT COUNT(*) FROM community_inquiries WHERE status = 'open' AND is_hidden = 0"), 'patch-question'],
        ['Unanswered over 2 days', (int)DB::value("SELECT COUNT(*) FROM community_inquiries WHERE status = 'open' AND is_hidden = 0 AND response_count = 0 AND created_at < :d", ['d' => date('Y-m-d H:i:s', time() - 2 * 86400)]), 'hourglass-split'],
        ['Open reports', $openReports, 'flag'],
        ['Muted or suspended', (int)DB::value('SELECT COUNT(DISTINCT user_id) FROM community_sanctions WHERE lifted_at IS NULL AND (ends_at IS NULL OR ends_at > :n)', ['n' => $now]), 'slash-circle'],
    ];
    $busy = DB::all('SELECT c.name, COUNT(m.id) AS n FROM community_channels c LEFT JOIN community_messages m ON m.channel_id = c.id AND m.created_at >= :d AND m.deleted_at IS NULL
                      WHERE c.is_archived = 0 GROUP BY c.id, c.name ORDER BY n DESC, c.sort_order LIMIT 6', ['d' => $d7]);
    $maxBusy = max(1, ...array_map(fn($b) => (int)$b['n'], $busy ?: [['n' => 1]]));
    $unresolved = DB::all("SELECT q.*, c.name AS category_name FROM community_inquiries q LEFT JOIN community_inquiry_categories c ON c.id = q.category_id
                            WHERE q.status = 'open' AND q.is_hidden = 0 ORDER BY q.response_count, q.created_at LIMIT 10");
    $annCh = DB::all("SELECT * FROM community_channels WHERE kind = 'announcement' AND is_archived = 0 ORDER BY sort_order");
?>
<div class="cmm-stats">
  <?php foreach ($stats as [$label, $n, $icon]): ?>
    <div class="cmm-stat"><i class="bi bi-<?= $icon ?>"></i><strong><?= number_format($n) ?></strong><span><?= h($label) ?></span></div>
  <?php endforeach; ?>
</div>
<div class="row g-3">
  <div class="col-lg-7">
    <div class="card mb-3"><div class="card-header fw-semibold">Unresolved inquiries</div>
      <?php if (!$unresolved): ?><div class="card-body"><p class="cm-muted mb-0">Every inquiry has been answered or resolved.</p></div><?php endif; ?>
      <div class="list-group list-group-flush">
        <?php foreach ($unresolved as $q): ?>
          <a class="list-group-item list-group-item-action cmm-row" href="<?= h(url('comm.inquiries', ['id' => (int)$q['id']])) ?>">
            <span class="cmm-row-main"><strong><?= h($q['title']) ?></strong><small><?= h($q['category_name'] ?? 'General') ?>, asked <?= h(Community::ago($q['created_at'])) ?> by <?= h(Community::user((int)$q['user_id'])['name']) ?></small></span>
            <span class="cmm-row-n<?= (int)$q['response_count'] ? '' : ' is-zero' ?>"><?= (int)$q['response_count'] ?> response<?= (int)$q['response_count'] === 1 ? '' : 's' ?></span></a>
        <?php endforeach; ?>
      </div>
    </div>
    <div class="card"><div class="card-header fw-semibold">Activity by channel, last 7 days</div><div class="card-body">
      <?php foreach ($busy as $b): ?>
        <div class="cmm-bar"><span><?= h($b['name']) ?></span><span class="cmm-bar-track"><span style="width:<?= round((int)$b['n'] / $maxBusy * 100) ?>%"></span></span><b><?= (int)$b['n'] ?></b></div>
      <?php endforeach; ?>
    </div></div>
  </div>
  <div class="col-lg-5">
    <?php if (Community::canModerate() && $annCh): ?>
    <form method="post" enctype="multipart/form-data" class="card"><div class="card-header fw-semibold"><i class="bi bi-megaphone"></i> Publish an announcement</div><div class="card-body">
      <?= csrf_field() ?><input type="hidden" name="act" value="announce"><input type="hidden" name="key" value="<?= h(bin2hex(random_bytes(10))) ?>">
      <?php if (count($annCh) > 1): ?><div class="mb-2"><label class="form-label">Channel</label><select class="form-select form-select-sm" name="channel"><?php foreach ($annCh as $c): ?><option value="<?= (int)$c['id'] ?>"><?= h($c['name']) ?></option><?php endforeach; ?></select></div>
      <?php else: ?><input type="hidden" name="channel" value="<?= (int)$annCh[0]['id'] ?>"><?php endif; ?>
      <div class="mb-2"><label class="form-label" for="annT">Title</label><input class="form-control form-control-sm" id="annT" name="title" maxlength="150" value="<?= h((string)p('title')) ?>"></div>
      <div class="mb-2"><label class="form-label" for="annB">Message</label><textarea class="form-control form-control-sm" id="annB" name="body" rows="5" maxlength="3800" required><?= h((string)p('body')) ?></textarea></div>
      <div class="mb-2"><input type="file" class="form-control form-control-sm" name="files[]" multiple aria-label="Attach files"></div>
      <div class="form-check mb-2"><input class="form-check-input" type="checkbox" name="pin" value="1" id="annPin" checked><label class="form-check-label" for="annPin">Pin it to the channel</label></div>
      <button class="btn btn-primary btn-sm"><i class="bi bi-send"></i> Publish and notify everyone</button>
    </div></form>
    <?php endif; ?>
  </div>
</div>
<?php

// ======================================================================= reports
elseif ($tab === 'reports'):
    $st = in_array(g('status'), ['open', 'actioned', 'dismissed'], true) ? (string)g('status') : 'open';
    $reports = DB::all('SELECT * FROM community_reports WHERE status = :s ORDER BY id DESC LIMIT 100', ['s' => $st]);
    $users = Community::users(array_merge(array_column($reports, 'reporter_id'), array_column($reports, 'target_user_id'), array_column($reports, 'handled_by')));
    $canMod = Community::canModerate();
?>
<div class="d-flex gap-2 mb-3">
  <?php foreach (['open' => 'Open', 'actioned' => 'Action taken', 'dismissed' => 'Dismissed'] as $k => $v): ?>
    <a class="btn btn-sm <?= $st === $k ? 'btn-secondary' : 'btn-outline-secondary' ?>" href="<?= h(url($pageKey, ['tab' => 'reports', 'status' => $k])) ?>"><?= h($v) ?></a>
  <?php endforeach; ?>
</div>
<?php if (!$reports): ?><div class="card"><div class="card-body cm-muted">No <?= $st === 'open' ? 'open ' : '' ?>reports.</div></div><?php endif; ?>
<?php foreach ($reports as $r):
    $link = match ($r['target_type']) {
        'message' => ($m = Community::message((int)$r['target_id'])) && ($c = Community::channel((int)$m['channel_id'])) ? url('comm.chat', ['ch' => $c['slug'], 'm' => (int)$m['id']]) : '',
        'inquiry' => url('comm.inquiries', ['id' => (int)$r['target_id']]),
        'response' => ($x = Inquiries::response((int)$r['target_id'])) ? url('comm.inquiries', ['id' => (int)$x['inquiry_id']]) . '#r' . (int)$x['id'] : '',
        default => '',
    };
?>
<div class="card mb-2 cmm-report"><div class="card-body">
  <div class="cmm-report-head"><strong><?= h(Community::REPORT_REASONS[$r['reason']] ?? $r['reason']) ?></strong>
    <span><?= h(['message' => 'Chat message', 'dm' => 'Private message', 'inquiry' => 'Inquiry', 'response' => 'Response', 'user' => 'User'][$r['target_type']] ?? $r['target_type']) ?>
      by <?= h($users[(int)$r['target_user_id']]['name'] ?? '?') ?></span>
    <span class="text-muted">reported by <?= h($users[(int)$r['reporter_id']]['name'] ?? '?') ?>, <?= h(Community::ago($r['created_at'])) ?></span></div>
  <blockquote class="cmm-snapshot"><?= nl2br(h((string)$r['snapshot']), false) ?></blockquote>
  <?php if ($r['details']): ?><p class="small mb-2"><strong>Details:</strong> <?= h($r['details']) ?></p><?php endif; ?>
  <?php if ($r['target_type'] === 'dm'): ?><p class="small text-muted mb-2">A private message: moderators see only the words reported, never the conversation. Mute or suspend the sender if needed.</p><?php endif; ?>
  <?php if ($st !== 'open'): ?>
    <p class="small text-muted mb-0">Handled by <?= h($users[(int)$r['handled_by']]['name'] ?? '?') ?> <?= h(Community::ago((string)$r['handled_at'])) ?><?= $r['resolution'] ? ': ' . h($r['resolution']) : '' ?></p>
  <?php elseif ($canMod): ?>
    <form method="post" class="cmm-report-form"><?= csrf_field() ?><input type="hidden" name="act" value="report"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>">
      <input class="form-control form-control-sm" name="note" maxlength="200" placeholder="Note (optional)" aria-label="Note">
      <?php if (in_array($r['target_type'], ['message', 'inquiry', 'response'], true)): ?><button class="btn btn-sm btn-warning" name="do" value="hide"><i class="bi bi-eye-slash"></i> Hide the post</button><?php endif; ?>
      <button class="btn btn-sm btn-outline-primary" name="do" value="actioned"><i class="bi bi-check2"></i> Close: action taken</button>
      <button class="btn btn-sm btn-outline-secondary" name="do" value="dismissed">Dismiss</button>
      <?php if ($link): ?><a class="btn btn-sm btn-light" href="<?= h($link) ?>" target="_blank" rel="noopener"><i class="bi bi-box-arrow-up-right"></i> Open</a><?php endif; ?>
      <?php if (Community::canSanction() && $r['target_user_id']): ?><a class="btn btn-sm btn-light" href="<?= h(url($pageKey, ['tab' => 'members', 'user' => (int)$r['target_user_id']])) ?>"><i class="bi bi-slash-circle"></i> Mute or suspend</a><?php endif; ?>
    </form>
  <?php endif; ?>
</div></div>
<?php endforeach; ?>
<?php

// ======================================================================= channels
elseif ($tab === 'channels'):
    $chs = DB::all('SELECT c.*, (SELECT COUNT(*) FROM community_messages m WHERE m.channel_id = c.id AND m.deleted_at IS NULL) AS msgs FROM community_channels c ORDER BY c.sort_order, c.id');
    $roles = DB::pairs('SELECT id, name FROM roles ORDER BY name');
    $chRoles = [];
    foreach (DB::all('SELECT channel_id, role_id FROM community_channel_roles') as $x) {
        $chRoles[(int)$x['channel_id']][] = (int)$x['role_id'];
    }
    $edit = (int)g('edit') ? Community::channel((int)g('edit')) : null;
    $canCfg = Community::canConfigure();
?>
<div class="row g-3">
  <div class="col-lg-7">
    <div class="card"><div class="table-responsive"><table class="table table-sm align-middle mb-0">
      <thead><tr><th>Channel</th><th>Who posts</th><th>Seen by</th><th class="num">Messages</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($chs as $i => $c): ?>
        <tr class="<?= (int)$c['is_archived'] ? 'text-muted' : '' ?>">
          <td><strong><i class="bi bi-<?= $c['kind'] === 'announcement' ? 'megaphone' : ((int)$c['is_restricted'] ? 'lock' : 'hash') ?>"></i> <?= h($c['name']) ?></strong><?= (int)$c['is_archived'] ? ' (archived)' : '' ?>
            <div class="small text-muted"><?= h((string)$c['description']) ?></div></td>
          <td class="small"><?= $c['post_policy'] === 'moderators' ? 'Moderators' : 'Everyone' ?></td>
          <td class="small"><?= (int)$c['is_restricted'] ? h(implode(', ', array_map(fn($r) => $roles[$r] ?? '?', $chRoles[(int)$c['id']] ?? []))) . ', moderators' : 'Everyone' ?></td>
          <td class="num"><?= number_format((int)$c['msgs']) ?></td>
          <td class="text-end text-nowrap"><?php if ($canCfg): ?>
            <form method="post" class="d-inline"><?= csrf_field() ?><input type="hidden" name="act" value="channel_move"><input type="hidden" name="id" value="<?= (int)$c['id'] ?>">
              <button class="btn btn-sm btn-light" name="dir" value="up" title="Move up" aria-label="Move up" <?= $i === 0 ? 'disabled' : '' ?>><i class="bi bi-arrow-up"></i></button>
              <button class="btn btn-sm btn-light" name="dir" value="down" title="Move down" aria-label="Move down" <?= $i === count($chs) - 1 ? 'disabled' : '' ?>><i class="bi bi-arrow-down"></i></button></form>
            <a class="btn btn-sm btn-light" href="<?= h(url($pageKey, ['tab' => 'channels', 'edit' => (int)$c['id']])) ?>"><i class="bi bi-pencil"></i><span class="cm-hide-xs"> Edit</span></a>
            <form method="post" class="d-inline"><?= csrf_field() ?><input type="hidden" name="act" value="channel_archive"><input type="hidden" name="id" value="<?= (int)$c['id'] ?>"><input type="hidden" name="on" value="<?= (int)$c['is_archived'] ? '0' : '1' ?>">
              <button class="btn btn-sm btn-light" <?= (int)$c['is_archived'] ? '' : 'data-confirm="Archive ' . h($c['name']) . '? It can still be read by moderators, but nobody can post."' ?>><i class="bi bi-<?= (int)$c['is_archived'] ? 'box-arrow-up' : 'archive' ?>"></i><span class="cm-hide-xs"> <?= (int)$c['is_archived'] ? 'Restore' : 'Archive' ?></span></button></form>
          <?php endif; ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody></table></div></div>
  </div>
  <div class="col-lg-5">
    <?php if ($canCfg): $er = $edit ? ($chRoles[(int)$edit['id']] ?? []) : array_map('intval', (array)($_POST['roles'] ?? [])); ?>
    <form method="post" class="card"><div class="card-header fw-semibold"><?= $edit ? 'Edit ' . h($edit['name']) : 'New channel' ?></div><div class="card-body">
      <?= csrf_field() ?><input type="hidden" name="act" value="channel_save"><input type="hidden" name="id" value="<?= (int)($edit['id'] ?? 0) ?>">
      <div class="mb-2"><label class="form-label" for="chN">Name</label><input class="form-control form-control-sm" id="chN" name="name" maxlength="80" required value="<?= h((string)fv('name', $edit)) ?>"></div>
      <div class="mb-2"><label class="form-label" for="chD">Description</label><input class="form-control form-control-sm" id="chD" name="description" maxlength="255" value="<?= h((string)fv('description', $edit)) ?>"></div>
      <div class="row g-2 mb-2">
        <div class="col-6"><label class="form-label" for="chK">Kind</label><select class="form-select form-select-sm" id="chK" name="kind"><?= options(['chat' => 'Discussion', 'announcement' => 'Announcements'], (string)fv('kind', $edit, 'chat')) ?></select></div>
        <div class="col-6"><label class="form-label" for="chP">Who posts</label><select class="form-select form-select-sm" id="chP" name="post_policy"><?= options(['everyone' => 'Everyone', 'moderators' => 'Moderators only'], (string)fv('post_policy', $edit, 'everyone')) ?></select></div>
      </div>
      <div class="form-check mb-1"><input type="hidden" name="restricted" value="0"><input class="form-check-input" type="checkbox" name="restricted" value="1" id="chR" <?= (int)fv('is_restricted', $edit, 0) ? 'checked' : '' ?>>
        <label class="form-check-label" for="chR">Only some roles see this channel</label></div>
      <div class="cmm-roles" data-toggle-by="#chR" data-show-when="1"><?php foreach ($roles as $rid => $rn): ?>
        <div class="form-check"><input class="form-check-input" type="checkbox" name="roles[]" value="<?= (int)$rid ?>" id="chRole<?= (int)$rid ?>" <?= in_array((int)$rid, $er, true) ? 'checked' : '' ?>><label class="form-check-label" for="chRole<?= (int)$rid ?>"><?= h($rn) ?></label></div>
      <?php endforeach; ?></div>
      <div class="mt-3 d-flex gap-2"><button class="btn btn-primary btn-sm"><i class="bi bi-check-lg"></i> Save channel</button>
        <?php if ($edit): ?><a class="btn btn-outline-secondary btn-sm" href="<?= h(url($pageKey, ['tab' => 'channels'])) ?>">Cancel</a><?php endif; ?></div>
    </div></form>
    <?php else: ?><div class="card"><div class="card-body cm-muted">Changing channels needs the Create right on Community Management.</div></div><?php endif; ?>
  </div>
</div>
<?php

// ======================================================================= categories
elseif ($tab === 'categories'):
    $cats = DB::all('SELECT c.*, (SELECT COUNT(*) FROM community_inquiries q WHERE q.category_id = c.id) AS n FROM community_inquiry_categories c ORDER BY c.sort_order, c.name');
    $edit = (int)g('edit') ? DB::row('SELECT * FROM community_inquiry_categories WHERE id = :id', ['id' => (int)g('edit')]) : null;
    $canCfg = Community::canConfigure();
?>
<div class="row g-3">
  <div class="col-lg-7"><div class="card"><div class="table-responsive"><table class="table table-sm align-middle mb-0">
    <thead><tr><th>Category</th><th class="num">Inquiries</th><th>In use</th><th></th></tr></thead><tbody>
    <?php foreach ($cats as $c): ?>
      <tr class="<?= (int)$c['is_active'] ? '' : 'text-muted' ?>"><td><strong><?= h($c['name']) ?></strong><div class="small text-muted"><?= h((string)$c['description']) ?></div></td>
        <td class="num"><?= (int)$c['n'] ?></td><td><?= (int)$c['is_active'] ? 'Yes' : 'No' ?></td>
        <td class="text-end"><?php if ($canCfg): ?><a class="btn btn-sm btn-light" href="<?= h(url($pageKey, ['tab' => 'categories', 'edit' => (int)$c['id']])) ?>"><i class="bi bi-pencil"></i> Edit</a><?php endif; ?></td></tr>
    <?php endforeach; ?></tbody></table></div></div></div>
  <div class="col-lg-5">
    <?php if ($canCfg): ?>
    <form method="post" class="card"><div class="card-header fw-semibold"><?= $edit ? 'Edit ' . h($edit['name']) : 'New category' ?></div><div class="card-body">
      <?= csrf_field() ?><input type="hidden" name="act" value="category_save"><input type="hidden" name="id" value="<?= (int)($edit['id'] ?? 0) ?>">
      <div class="mb-2"><label class="form-label" for="caN">Name</label><input class="form-control form-control-sm" id="caN" name="name" maxlength="80" required value="<?= h((string)fv('name', $edit)) ?>"></div>
      <div class="mb-2"><label class="form-label" for="caD">Description</label><input class="form-control form-control-sm" id="caD" name="description" maxlength="255" value="<?= h((string)fv('description', $edit)) ?>"></div>
      <div class="form-check mb-3"><input type="hidden" name="is_active" value="0"><input class="form-check-input" type="checkbox" name="is_active" value="1" id="caA" <?= (int)fv('is_active', $edit, 1) ? 'checked' : '' ?>>
        <label class="form-check-label" for="caA">In use (offered when asking a question)</label></div>
      <div class="d-flex gap-2"><button class="btn btn-primary btn-sm"><i class="bi bi-check-lg"></i> Save category</button>
        <?php if ($edit): ?><a class="btn btn-outline-secondary btn-sm" href="<?= h(url($pageKey, ['tab' => 'categories'])) ?>">Cancel</a><?php endif; ?></div>
    </div></form>
    <?php endif; ?>
  </div>
</div>
<?php

// ======================================================================= members
elseif ($tab === 'members'):
    $q = trim((string)g('q'));
    $pick = (int)g('user');
    $found = $q !== '' ? DB::all("SELECT id FROM users WHERE status = 'active' AND is_platform = 0 AND (username LIKE :a OR full_name LIKE :b) ORDER BY full_name LIMIT 20", ['a' => $q . '%', 'b' => '%' . $q . '%']) : [];
    $active = DB::all('SELECT * FROM community_sanctions WHERE lifted_at IS NULL AND (ends_at IS NULL OR ends_at > :n) ORDER BY id DESC', ['n' => $now]);
    $past = DB::all('SELECT * FROM community_sanctions WHERE lifted_at IS NOT NULL OR (ends_at IS NOT NULL AND ends_at <= :n) ORDER BY id DESC LIMIT 20', ['n' => $now]);
    $users = Community::users(array_merge(array_column($found, 'id'), array_column($active, 'user_id'), array_column($active, 'created_by'), array_column($past, 'user_id'), [$pick]));
    $canS = Community::canSanction();
?>
<div class="row g-3">
  <div class="col-lg-6">
    <div class="card mb-3"><div class="card-header fw-semibold">Muted and suspended now</div>
      <?php if (!$active): ?><div class="card-body cm-muted">Nobody.</div><?php endif; ?>
      <div class="list-group list-group-flush">
      <?php foreach ($active as $s): $u = $users[(int)$s['user_id']]; ?>
        <div class="list-group-item cmm-row"><?= Community::avatar($u, 'sm') ?>
          <span class="cmm-row-main"><strong><?= h($u['name']) ?></strong><small><?= $s['kind'] === 'suspend' ? 'Suspended' : 'Muted' ?> <?= $s['ends_at'] ? 'until ' . h(fdatetime($s['ends_at'])) : 'until lifted' ?>, by <?= h($users[(int)$s['created_by']]['name'] ?? '?') ?>: <?= h($s['reason']) ?></small></span>
          <?php if ($canS): ?><form method="post"><?= csrf_field() ?><input type="hidden" name="act" value="lift"><input type="hidden" name="id" value="<?= (int)$s['id'] ?>"><button class="btn btn-sm btn-outline-secondary">Lift</button></form><?php endif; ?></div>
      <?php endforeach; ?></div>
    </div>
    <?php if ($past): ?>
    <div class="card"><div class="card-header fw-semibold">Ended</div><div class="list-group list-group-flush small">
      <?php foreach ($past as $s): ?><div class="list-group-item"><?= h($users[(int)$s['user_id']]['name']) ?>: <?= $s['kind'] === 'suspend' ? 'suspended' : 'muted' ?> <?= h(fdate($s['created_at'])) ?>, <?= $s['lifted_at'] ? 'lifted ' . h(fdate($s['lifted_at'])) : 'ended ' . h(fdate((string)$s['ends_at'])) ?> (<?= h($s['reason']) ?>)</div><?php endforeach; ?>
    </div></div>
    <?php endif; ?>
  </div>
  <div class="col-lg-6">
    <div class="card"><div class="card-header fw-semibold">Mute or suspend a member</div><div class="card-body">
      <?php if (!$canS): ?><p class="cm-muted mb-0">Muting and suspending need the Delete right on Community Management.</p><?php else: ?>
      <form method="get" class="d-flex gap-2 mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>"><input type="hidden" name="tab" value="members">
        <input class="form-control form-control-sm" type="search" name="q" value="<?= h($q) ?>" placeholder="Find a member by name or username" aria-label="Find a member"><button class="btn btn-sm btn-secondary">Find</button></form>
      <?php foreach ($found as $f): $u = $users[(int)$f['id']]; ?>
        <a class="cmm-pick<?= $pick === $u['id'] ? ' is-on' : '' ?>" href="<?= h(url($pageKey, ['tab' => 'members', 'q' => $q, 'user' => $u['id']])) ?>"><?= Community::avatar($u, 'xs') ?> <?= h($u['name']) ?> <small>@<?= h($u['username']) ?></small></a>
      <?php endforeach; ?>
      <?php if ($pick && isset($users[$pick])): $u = $users[$pick]; ?>
      <form method="post" class="cmm-sanction"><?= csrf_field() ?><input type="hidden" name="act" value="sanction"><input type="hidden" name="user" value="<?= $pick ?>">
        <div class="d-flex align-items-center gap-2 mb-2"><?= Community::avatar($u, 'sm') ?><strong><?= h($u['name']) ?></strong></div>
        <div class="row g-2">
          <div class="col-sm-6"><label class="form-label">Action</label><select class="form-select form-select-sm" name="kind"><option value="mute">Mute: may read, may not post</option><option value="suspend">Suspend: no community at all</option></select></div>
          <div class="col-sm-6"><label class="form-label">For</label><select class="form-select form-select-sm" name="length"><option value="1h">1 hour</option><option value="1d" selected>1 day</option><option value="7d">7 days</option><option value="30d">30 days</option><option value="">Until lifted</option></select></div>
          <div class="col-12"><label class="form-label">Reason (the member sees it)</label><input class="form-control form-control-sm" name="reason" maxlength="255" required></div>
          <div class="col-12"><button class="btn btn-sm btn-warning"><i class="bi bi-slash-circle"></i> Apply</button></div>
        </div></form>
      <?php endif; ?>
      <?php endif; ?>
    </div></div>
  </div>
</div>
<?php

// ======================================================================= log
else:
    $fa = (string)g('action');
    $labels = Community::logActions();
    $w = $fa !== '' ? 'WHERE action = :a' : '';
    $logs = DB::all("SELECT * FROM community_mod_log $w ORDER BY id DESC LIMIT 200", $fa !== '' ? ['a' => $fa] : []);
    $users = Community::users(array_merge(array_column($logs, 'moderator_id'), array_column($logs, 'target_user_id')));
?>
<form method="get" class="d-flex gap-2 mb-3 filters"><input type="hidden" name="p" value="<?= h($pageKey) ?>"><input type="hidden" name="tab" value="log">
  <select class="form-select form-select-sm" name="action" style="max-width:320px" aria-label="Action"><?= options($labels, $fa, 'Every action') ?></select><button class="btn btn-sm btn-secondary">Filter</button></form>
<div class="card"><div class="table-responsive"><table class="table table-sm mb-0">
  <thead><tr><th>When</th><th>Moderator</th><th>Action</th><th>Member</th><th>Reason and detail</th></tr></thead><tbody>
  <?php if (!$logs): ?><tr><td colspan="5" class="text-center text-muted py-3">Nothing recorded yet.</td></tr><?php endif; ?>
  <?php foreach ($logs as $l): ?>
    <tr><td class="small text-nowrap"><?= h(fdatetime($l['created_at'])) ?></td><td class="small"><?= h($users[(int)$l['moderator_id']]['name'] ?? '?') ?></td>
      <td class="small"><?= h($labels[$l['action']] ?? $l['action']) ?></td><td class="small"><?= $l['target_user_id'] ? h($users[(int)$l['target_user_id']]['name'] ?? '?') : '' ?></td>
      <td class="small"><?= h((string)$l['reason']) ?><?= $l['detail'] ? '<div class="text-muted cmm-detail">' . h(Community::excerpt($l['detail'], 240)) . '</div>' : '' ?></td></tr>
  <?php endforeach; ?></tbody></table></div></div>
<p class="small text-muted mt-2">Every moderation action is also in System Administration &gt; Audit Trail (actions starting with "Community").</p>
<?php
endif;
layout_end();
