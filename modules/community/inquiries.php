<?php
declare(strict_types=1);

/**
 * v41: Community > Questions & Inquiries: the list (search, status, category, mine, unanswered), asking a question,
 * the inquiry with its responses and comments, the accepted answer and the status. See app/Inquiries.php.
 */
$pageKey = 'comm.inquiries';
if (!Community::ready()) {
    layout_start('Questions & Inquiries');
    echo '<div class="alert alert-warning">Run database/migrations/2027_02_04_community.sql to set up the Community.</div>';
    layout_end();
    return;
}
if (Community::suspended()) {
    layout_start('Questions & Inquiries');
    echo '<div class="card"><div class="card-body"><h2 class="h5">Community access suspended</h2><p class="mb-0">' . h(Community::sanctionText(Community::sanction())) . '.</p></div></div>';
    layout_end();
    return;
}
$a = (string)g('a');
$me = Community::me();
$mod = Community::isMod();
$canPost = Access::can($pageKey, 'create') && !Community::muted();
$cats = Inquiries::categories(false);
$catNames = array_column($cats, 'name', 'id');

/** pictures and documents of a post */
$fileList = function (array $files): string {
    if (!$files) {
        return '';
    }
    $imgs = '';
    $docs = '';
    foreach ($files as $f) {
        $u = url('comm.file', ['id' => (int)$f['id']]);
        if ((int)$f['is_image'] === 1) {
            $v = url('comm.file', ['id' => (int)$f['id'], 'view' => 1]);
            $imgs .= '<a class="cm-img" href="' . h($v) . '" target="_blank" rel="noopener"><img src="' . h($v) . '" alt="' . h($f['file_name']) . '" loading="lazy"></a>';
        } else {
            $docs .= '<a class="cm-doc" href="' . h($u) . '"><i class="bi bi-file-earmark"></i><span>' . h($f['file_name']) . '<small>' . h(Community::size((int)$f['file_size'])) . '</small></span></a>';
        }
    }
    return ($imgs ? '<div class="cm-imgs">' . $imgs . '</div>' : '') . ($docs ? '<div class="cm-docs">' . $docs . '</div>' : '');
};
$statusLabel = fn(string $s) => '<span class="iq-status iq-' . h($s) . '"><i class="bi bi-' . ($s === 'resolved' ? 'check2-all' : ($s === 'answered' ? 'check2-circle' : 'circle')) . '"></i> ' . h(Community::STATUSES[$s] ?? $s) . '</span>';
/** files chosen on a form that came back with an error stay with it */
$keptFiles = function () use ($me): array {
    $ids = array_values(array_filter(array_map('intval', (array)($_POST['kept_files'] ?? []))));
    [$new, $problems] = Community::takeUploads('files');
    foreach ($problems as $p) {
        flash('warning', $p);
    }
    $ids = Community::ownPending(array_slice(array_merge($ids, $new), 0, Community::MAX_FILES));
    $GLOBALS['IQ_KEPT'] = $ids;
    return $ids;
};
$filesField = function () {
    $kept = $GLOBALS['IQ_KEPT'] ?? [];
    $h = '';
    if ($kept) {
        [$in, $p] = DB::in('k', $kept);
        foreach (DB::all("SELECT id, file_name, file_size FROM community_files WHERE id IN $in", $p) as $f) {
            $h .= '<span class="cm-chip"><i class="bi bi-paperclip"></i><span>' . h($f['file_name']) . '<small>' . h(Community::size((int)$f['file_size'])) . ', attached when you post</small></span>'
                . '<input type="hidden" name="kept_files[]" value="' . (int)$f['id'] . '"></span>';
        }
    }
    return '<div class="iq-files"><label class="form-label">Attachments (optional)</label>'
        . ($h ? '<div class="cm-chips mb-2">' . $h . '</div>' : '')
        . '<input type="file" class="form-control form-control-sm" name="files[]" multiple accept="' . h('.' . implode(',.', Community::allowedExt())) . '">'
        . '<div class="form-text">Pictures, PDF, Word, Excel, PowerPoint, CSV, text or ZIP; up to ' . Community::MAX_FILES . ' files of ' . h(Community::size(Community::maxFile())) . ' each.</div></div>';
};
$userLine = function (array $u, string $at, bool $official = false) {
    return Community::avatar($u, 'sm') . '<span class="iq-who"><strong>' . h($u['name']) . '</strong>' . ($u['mod'] ? '<span class="cm-role">Moderator</span>' : '')
        . ($official ? '<span class="cm-role is-official">Official</span>' : '') . '<time title="' . h(fdatetime($at)) . '">' . h(Community::ago($at)) . '</time></span>';
};

// ======================================================================= ask / edit
if ($a === 'ask' || $a === 'edit') {
    $q = null;
    if ($a === 'edit') {
        $q = Inquiries::find((int)g('id'));
        if (!$q || (int)$q['user_id'] !== $me || !Access::can($pageKey, 'edit')) {
            flash('warning', 'You can edit only your own inquiries.');
            redirect(url($pageKey));
        }
    } elseif (!$canPost) {
        flash('warning', Community::muted() ? Community::sanctionText(Community::sanction()) . '.' : 'Your role may read inquiries but not ask.');
        redirect(url($pageKey));
    }
    handle_post(function () use ($q, $keptFiles, $pageKey) {
        if ($q) {
            Inquiries::edit($q, (int)p('category_id'), (string)p('title'), (string)p('body'));
            flash('success', 'Inquiry updated.');
            redirect(url($pageKey, ['id' => (int)$q['id']]));
        }
        $files = $keptFiles();
        $id = Inquiries::ask((int)p('category_id'), (string)p('title'), (string)p('body'), Community::clientKey(p('key')), $files);
        flash('success', 'Your inquiry was posted. You are notified when someone responds.');
        redirect(url($pageKey, ['id' => $id]));
    });
    if (is_post() && !$q && !isset($GLOBALS['IQ_KEPT'])) {
        $keptFiles();
    }
    layout_start($q ? 'Edit inquiry' : 'Ask a question', ['actions' => btn_link($q ? url($pageKey, ['id' => (int)$q['id']]) : url($pageKey), 'Cancel', 'btn-outline-secondary')]);
    echo form_error();
    ?>
    <form method="post" enctype="multipart/form-data" class="iq-ask" id="iqAsk" data-similar="<?= h(url('comm.api', ['a' => 'similar'])) ?>">
      <?= csrf_field() ?>
      <input type="hidden" name="key" value="<?= h((string)(p('key') ?: bin2hex(random_bytes(10)))) ?>">
      <div class="row g-3">
        <div class="col-lg-8">
          <div class="card"><div class="card-body">
            <div class="mb-3"><label class="form-label" for="iqTitle">Title</label>
              <input class="form-control" id="iqTitle" name="title" maxlength="200" required value="<?= h((string)fv('title', $q)) ?>" placeholder="Say what you need in one line" autocomplete="off">
              <div class="iq-similar" id="iqSimilar" hidden></div></div>
            <div class="mb-3"><label class="form-label" for="iqCat">Category</label>
              <select class="form-select" id="iqCat" name="category_id" required><option value="">Choose a category</option>
                <?php foreach ($cats as $c): if ((int)$c['is_active'] === 0 && (int)($q['category_id'] ?? 0) !== (int)$c['id']) { continue; } ?>
                  <option value="<?= (int)$c['id'] ?>" <?= (string)fv('category_id', $q) === (string)$c['id'] ? 'selected' : '' ?>><?= h($c['name']) ?></option>
                <?php endforeach; ?></select></div>
            <div class="mb-3"><label class="form-label" for="iqBody">Your question</label>
              <textarea class="form-control" id="iqBody" name="body" rows="8" maxlength="<?= Inquiries::MAX_BODY ?>" required placeholder="Describe what you did, what you expected and what happened. Mention people with @username."><?= h((string)fv('body', $q)) ?></textarea></div>
            <?= $q ? '' : $filesField() ?>
          </div></div>
          <div class="mt-3 d-flex gap-2"><button class="btn btn-primary"><i class="bi bi-send"></i> <?= $q ? 'Save changes' : 'Post inquiry' ?></button>
            <?= btn_link($q ? url($pageKey, ['id' => (int)$q['id']]) : url($pageKey), 'Cancel', 'btn-outline-secondary') ?></div>
        </div>
        <div class="col-lg-4"><div class="card iq-tips"><div class="card-body">
          <h2 class="h6">Getting a good answer</h2>
          <ul class="small mb-0">
            <li>Look at the similar questions that appear under the title: yours may already be answered.</li>
            <li>Name the page and the document number you were working on.</li>
            <li>Attach a screenshot of the message you saw.</li>
            <li>Do not post passwords or other private information.</li>
          </ul></div></div></div>
      </div>
    </form>
    <script>
    (function () {
      const t = document.getElementById('iqTitle'), box = document.getElementById('iqSimilar'), url = document.getElementById('iqAsk').dataset.similar;
      if (!t || !box) return;
      let timer = null;
      const esc = (v) => String(v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
      t.addEventListener('input', () => {
        clearTimeout(timer);
        if (t.value.trim().length < 6) { box.hidden = true; return; }
        timer = setTimeout(async () => {
          try {
            const r = await fetch(url + '&q=' + encodeURIComponent(t.value), { headers: { Accept: 'application/json' } });
            const j = await r.json();
            box.hidden = !(j.items || []).length;
            box.innerHTML = '<div class="iq-similar-head">Similar questions</div>' + j.items.map((x) => '<a href="' + esc(x.url) + '" target="_blank" rel="noopener">' + esc(x.title)
              + '<small>' + esc(x.status) + ', ' + x.responses + ' response' + (x.responses === 1 ? '' : 's') + '</small></a>').join('');
          } catch (e) { box.hidden = true; }
        }, 300);
      });
    })();
    </script>
    <?php
    layout_end();
    return;
}

// ======================================================================= one inquiry
if ($id = (int)g('id')) {
    $q = Inquiries::find($id);
    if (!$q || !Inquiries::canSee($q)) {
        flash('warning', 'The inquiry was not found.');
        redirect(url($pageKey));
    }
    handle_post(function () use ($q, $pageKey, $keptFiles) {
        $act = (string)p('act');
        $back = url($pageKey, ['id' => (int)$q['id']]);
        switch ($act) {
            case 'respond':
                $files = $keptFiles();
                $rid = Inquiries::respond($q, (string)p('body'), null, p('official') === '1', Community::clientKey(p('key')), $files);
                flash('success', 'Your response was posted.');
                redirect($back . '#r' . $rid);
            case 'comment':
                $rid = Inquiries::respond($q, (string)p('body'), (int)p('parent'), false, Community::clientKey(p('key')), []);
                redirect($back . '#r' . $rid);
            case 'accept':
                Inquiries::accept($q, (int)p('response') ?: null);
                flash('success', (int)p('response') ? 'The response is marked as the accepted answer. The inquiry is Answered.' : 'The accepted answer was cleared.');
                redirect($back);
            case 'status':
                Inquiries::setStatus($q, (string)p('status'));
                flash('success', 'The inquiry is now ' . Community::STATUSES[(string)p('status')] . '.');
                redirect($back);
            case 'edit_response':
                $r = Inquiries::response((int)p('response'));
                if (!$r || (int)$r['inquiry_id'] !== (int)$q['id']) {
                    fail('The response was not found.');
                }
                Inquiries::editResponse($r, (string)p('body'));
                redirect($back . '#r' . (int)$r['id']);
            case 'delete_response':
                $r = Inquiries::response((int)p('response'));
                if (!$r || (int)$r['inquiry_id'] !== (int)$q['id']) {
                    fail('The response was not found.');
                }
                Inquiries::deleteResponse($r, (string)p('reason'));
                flash('success', 'The response was deleted.');
                redirect($back);
            case 'delete':
                Inquiries::delete($q, (string)p('reason'));
                flash('success', 'The inquiry was deleted.');
                redirect(url($pageKey));
            case 'hide':
                Community::setHidden((string)p('type') === 'response' ? 'response' : 'inquiry', (int)p('target'), p('on') === '1', (string)p('reason'));
                flash('success', p('on') === '1' ? 'Hidden. Only moderators and the author see it now.' : 'Shown again.');
                redirect($back);
            case 'report':
                Community::report((string)p('type') === 'response' ? 'response' : 'inquiry', (int)p('target'), (string)p('reason'), (string)p('details'));
                flash('success', 'Thank you. A moderator will review the report.');
                redirect($back);
        }
        fail('Unknown action.');
    });
    if (!is_post()) {
        Inquiries::viewed($q);
    } elseif (!isset($GLOBALS['IQ_KEPT']) && p('act') === 'respond') {
        $keptFiles();
    }
    $q = Inquiries::find($id);
    $author = Community::user((int)$q['user_id']);
    $responses = Inquiries::responses($q);
    $qFiles = Community::files('inquiry', [(int)$q['id']])[(int)$q['id']] ?? [];
    $manage = Inquiries::canManage($q);
    $own = (int)$q['user_id'] === $me;
    $count = count(array_filter($responses, fn($r) => !$r['deleted_at']));
    $total = (int)DB::value('SELECT COUNT(*) FROM community_inquiry_responses WHERE inquiry_id = :i AND deleted_at IS NULL', ['i' => $id]);
    layout_start(Community::excerpt($q['title'], 70), ['actions' => btn_link(url($pageKey), 'All inquiries', 'btn-outline-secondary', 'arrow-left')
        . ($canPost ? ' ' . btn_link(url($pageKey, ['a' => 'ask']), 'Ask a question', 'btn-primary', 'plus-lg') : '')]);
    echo form_error();
    $reasons = Community::REPORT_REASONS;
    $editId = (int)g('edit');
    ?>
    <div class="iq-live" id="iqLive" data-poll="<?= h(url('comm.api', ['a' => 'inq_poll', 'id' => $id])) ?>" data-count="<?= $total ?>" data-status="<?= h($q['status']) ?>" hidden>
      <i class="bi bi-arrow-repeat"></i> <span>There are new responses.</span> <a href="<?= h(url($pageKey, ['id' => $id])) ?>">Show them</a></div>
    <div class="row g-3">
      <div class="col-lg-8">
        <article class="card iq-question<?= (int)$q['is_hidden'] ? ' is-hidden' : '' ?>">
          <div class="card-body">
            <div class="iq-qhead"><?= $statusLabel($q['status']) ?><span class="iq-cat"><?= h($catNames[(int)$q['category_id']] ?? 'General') ?></span></div>
            <h1 class="iq-title"><?= h($q['title']) ?></h1>
            <div class="iq-byline"><?= $userLine($author, $q['created_at']) ?><?= $q['edited_at'] ? '<span class="cm-edited">(edited)</span>' : '' ?></div>
            <?php if ((int)$q['is_hidden']): ?><div class="cm-hidden-flag"><i class="bi bi-eye-slash"></i> Hidden by a moderator<?= $q['hidden_reason'] ? ': ' . h($q['hidden_reason']) : '' ?></div><?php endif; ?>
            <div class="iq-text"><?= Community::render($q['body']) ?></div>
            <?= $fileList($qFiles) ?>
            <div class="iq-actions">
              <?php if ($own && Access::can($pageKey, 'edit') && !Community::muted()): ?><a class="btn btn-sm btn-light" href="<?= h(url($pageKey, ['a' => 'edit', 'id' => $id])) ?>"><i class="bi bi-pencil"></i> Edit</a><?php endif; ?>
              <?php if ($manage): ?>
                <form method="post" class="d-inline"><?= csrf_field() ?><input type="hidden" name="act" value="status">
                  <?php if ($q['status'] === 'resolved'): ?><button class="btn btn-sm btn-light" name="status" value="<?= $q['accepted_response_id'] ? 'answered' : 'open' ?>"><i class="bi bi-arrow-counterclockwise"></i> Reopen</button>
                  <?php else: ?><button class="btn btn-sm btn-light" name="status" value="resolved"><i class="bi bi-check2-all"></i> Mark as resolved</button><?php endif; ?></form>
              <?php endif; ?>
              <?php if (!$own): ?><button type="button" class="btn btn-sm btn-light" data-bs-toggle="collapse" data-bs-target="#iqRepQ" aria-expanded="false"><i class="bi bi-flag"></i> Report</button><?php endif; ?>
              <?php if (Community::canModerate()): ?><button type="button" class="btn btn-sm btn-light" data-bs-toggle="collapse" data-bs-target="#iqHideQ" aria-expanded="false"><i class="bi bi-eye<?= (int)$q['is_hidden'] ? '' : '-slash' ?>"></i> <?= (int)$q['is_hidden'] ? 'Show again' : 'Hide' ?></button><?php endif; ?>
              <?php if (($own && Access::can($pageKey, 'delete') && (int)$q['response_count'] === 0) || Community::canSanction()): ?>
                <button type="button" class="btn btn-sm btn-light text-danger" data-bs-toggle="collapse" data-bs-target="#iqDelQ" aria-expanded="false"><i class="bi bi-trash3"></i> Delete</button><?php endif; ?>
            </div>
            <?php if (!$own): ?>
            <form method="post" class="collapse iq-inline-form" id="iqRepQ"><?= csrf_field() ?><input type="hidden" name="act" value="report"><input type="hidden" name="type" value="inquiry"><input type="hidden" name="target" value="<?= $id ?>">
              <div class="row g-2 align-items-end"><div class="col-sm-4"><label class="form-label">Reason</label><select class="form-select form-select-sm" name="reason" required><option value="">Choose</option>
                <?php foreach ($reasons as $k => $v): ?><option value="<?= h($k) ?>"><?= h($v) ?></option><?php endforeach; ?></select></div>
                <div class="col-sm-6"><label class="form-label">Details (optional)</label><input class="form-control form-control-sm" name="details" maxlength="500"></div>
                <div class="col-sm-2"><button class="btn btn-sm btn-danger w-100">Report</button></div></div></form>
            <?php endif; ?>
            <?php if (Community::canModerate()): ?>
            <form method="post" class="collapse iq-inline-form" id="iqHideQ"><?= csrf_field() ?><input type="hidden" name="act" value="hide"><input type="hidden" name="type" value="inquiry"><input type="hidden" name="target" value="<?= $id ?>">
              <input type="hidden" name="on" value="<?= (int)$q['is_hidden'] ? '0' : '1' ?>">
              <div class="row g-2 align-items-end"><?php if (!(int)$q['is_hidden']): ?><div class="col-sm-9"><label class="form-label">Reason (the author sees it)</label><input class="form-control form-control-sm" name="reason" maxlength="255" required></div><?php endif; ?>
                <div class="col-sm-3"><button class="btn btn-sm btn-primary w-100"><?= (int)$q['is_hidden'] ? 'Show again' : 'Hide' ?></button></div></div></form>
            <?php endif; ?>
            <form method="post" class="collapse iq-inline-form" id="iqDelQ"><?= csrf_field() ?><input type="hidden" name="act" value="delete">
              <div class="row g-2 align-items-end"><?php if (!$own): ?><div class="col-sm-9"><label class="form-label">Reason (recorded in the moderation log)</label><input class="form-control form-control-sm" name="reason" maxlength="255" required></div><?php endif; ?>
                <div class="col-sm-3"><button class="btn btn-sm btn-danger w-100">Delete inquiry</button></div></div></form>
          </div>
        </article>

        <h2 class="iq-resp-title"><?= $count ?> response<?= $count === 1 ? '' : 's' ?></h2>
        <?php foreach ($responses as $r):
            if (!$r['visible'] && !$r['comments']) { continue; }
            $rid = (int)$r['id'];
            $accepted = (int)$q['accepted_response_id'] === $rid;
            $mine = (int)$r['user_id'] === $me;
        ?>
        <article class="card iq-resp<?= $accepted ? ' is-accepted' : '' ?><?= (int)$r['is_official'] ? ' is-official' : '' ?><?= (int)$r['is_hidden'] ? ' is-hidden' : '' ?>" id="r<?= $rid ?>">
          <div class="card-body">
            <?php if ($accepted): ?><div class="iq-accepted"><i class="bi bi-check-circle-fill"></i> Accepted answer</div><?php endif; ?>
            <?php if ($r['visible']): ?>
              <div class="iq-byline"><?= $userLine($r['user'], $r['created_at'], (int)$r['is_official'] === 1) ?><?= $r['edited_at'] ? '<span class="cm-edited">(edited)</span>' : '' ?></div>
              <?php if ((int)$r['is_hidden']): ?><div class="cm-hidden-flag"><i class="bi bi-eye-slash"></i> Hidden by a moderator<?= $r['hidden_reason'] ? ': ' . h($r['hidden_reason']) : '' ?></div><?php endif; ?>
              <?php if ($editId === $rid && $mine): ?>
                <form method="post" class="mt-2"><?= csrf_field() ?><input type="hidden" name="act" value="edit_response"><input type="hidden" name="response" value="<?= $rid ?>">
                  <textarea class="form-control" name="body" rows="5" required><?= h($r['body']) ?></textarea>
                  <div class="mt-2 d-flex gap-2"><button class="btn btn-sm btn-primary">Save</button><a class="btn btn-sm btn-outline-secondary" href="<?= h(url($pageKey, ['id' => $id])) ?>#r<?= $rid ?>">Cancel</a></div></form>
              <?php else: ?>
                <div class="iq-text"><?= Community::render($r['body']) ?></div>
                <?= $fileList($r['files']) ?>
              <?php endif; ?>
              <div class="iq-actions">
                <?php if ($manage && !(int)$r['is_hidden']): ?>
                  <form method="post" class="d-inline"><?= csrf_field() ?><input type="hidden" name="act" value="accept"><input type="hidden" name="response" value="<?= $accepted ? '' : $rid ?>">
                    <button class="btn btn-sm <?= $accepted ? 'btn-light' : 'btn-outline-success' ?>"><i class="bi bi-check2-circle"></i> <?= $accepted ? 'Clear accepted answer' : 'Accept as the answer' ?></button></form>
                <?php endif; ?>
                <?php if ($canPost): ?><button type="button" class="btn btn-sm btn-light" data-bs-toggle="collapse" data-bs-target="#iqC<?= $rid ?>" aria-expanded="false"><i class="bi bi-chat-left"></i> Comment</button><?php endif; ?>
                <?php if ($mine && Access::can($pageKey, 'edit') && !Community::muted()): ?><a class="btn btn-sm btn-light" href="<?= h(url($pageKey, ['id' => $id, 'edit' => $rid])) ?>#r<?= $rid ?>"><i class="bi bi-pencil"></i> Edit</a><?php endif; ?>
                <?php if (!$mine): ?><button type="button" class="btn btn-sm btn-light" data-bs-toggle="collapse" data-bs-target="#iqR<?= $rid ?>" aria-expanded="false"><i class="bi bi-flag"></i> Report</button><?php endif; ?>
                <?php if (Community::canModerate()): ?>
                  <form method="post" class="d-inline"><?= csrf_field() ?><input type="hidden" name="act" value="hide"><input type="hidden" name="type" value="response"><input type="hidden" name="target" value="<?= $rid ?>">
                    <input type="hidden" name="on" value="<?= (int)$r['is_hidden'] ? '0' : '1' ?>"><input type="hidden" name="reason" value="Hidden from the inquiry page">
                    <button class="btn btn-sm btn-light"><i class="bi bi-eye<?= (int)$r['is_hidden'] ? '' : '-slash' ?>"></i> <?= (int)$r['is_hidden'] ? 'Show again' : 'Hide' ?></button></form>
                <?php endif; ?>
                <?php if (($mine && Access::can($pageKey, 'delete')) || Community::canSanction()): ?>
                  <form method="post" class="d-inline"><?= csrf_field() ?><input type="hidden" name="act" value="delete_response"><input type="hidden" name="response" value="<?= $rid ?>">
                    <?php if (!$mine): ?><input type="hidden" name="reason" value="Removed from the inquiry page"><?php endif; ?>
                    <button class="btn btn-sm btn-light text-danger" data-confirm="Delete this response?"><i class="bi bi-trash3"></i> Delete</button></form>
                <?php endif; ?>
              </div>
              <?php if (!$mine): ?>
              <form method="post" class="collapse iq-inline-form" id="iqR<?= $rid ?>"><?= csrf_field() ?><input type="hidden" name="act" value="report"><input type="hidden" name="type" value="response"><input type="hidden" name="target" value="<?= $rid ?>">
                <div class="row g-2 align-items-end"><div class="col-sm-4"><label class="form-label">Reason</label><select class="form-select form-select-sm" name="reason" required><option value="">Choose</option>
                  <?php foreach ($reasons as $k => $v): ?><option value="<?= h($k) ?>"><?= h($v) ?></option><?php endforeach; ?></select></div>
                  <div class="col-sm-6"><label class="form-label">Details (optional)</label><input class="form-control form-control-sm" name="details" maxlength="500"></div>
                  <div class="col-sm-2"><button class="btn btn-sm btn-danger w-100">Report</button></div></div></form>
              <?php endif; ?>
            <?php else: ?>
              <p class="cm-gone mb-0"><i class="bi bi-trash3"></i> This response was removed.</p>
            <?php endif; ?>

            <?php if ($r['comments'] || $canPost): ?>
            <div class="iq-comments">
              <?php foreach ($r['comments'] as $c): if (!$c['visible']) { continue; } $cmine = (int)$c['user_id'] === $me; ?>
                <div class="iq-comment" id="r<?= (int)$c['id'] ?>"><?= Community::avatar($c['user'], 'xs') ?>
                  <div><span class="iq-cwho"><strong><?= h($c['user']['name']) ?></strong><?= $c['user']['mod'] ? '<span class="cm-role">Moderator</span>' : '' ?><time><?= h(Community::ago($c['created_at'])) ?></time></span>
                    <?php if ((int)$c['is_hidden']): ?><span class="cm-hidden-flag"><i class="bi bi-eye-slash"></i> Hidden</span><?php endif; ?>
                    <div class="iq-ctext"><?= Community::render($c['body']) ?></div>
                    <?php if (($cmine && Access::can($pageKey, 'delete')) || Community::canSanction()): ?>
                      <form method="post" class="d-inline"><?= csrf_field() ?><input type="hidden" name="act" value="delete_response"><input type="hidden" name="response" value="<?= (int)$c['id'] ?>">
                        <?php if (!$cmine): ?><input type="hidden" name="reason" value="Comment removed from the inquiry page"><?php endif; ?>
                        <button class="btn btn-link btn-sm p-0 text-danger" data-confirm="Delete this comment?">Delete</button></form>
                    <?php endif; ?>
                  </div></div>
              <?php endforeach; ?>
              <?php if ($canPost): ?>
              <form method="post" class="collapse iq-cform" id="iqC<?= $rid ?>"><?= csrf_field() ?><input type="hidden" name="act" value="comment"><input type="hidden" name="parent" value="<?= $rid ?>">
                <input type="hidden" name="key" value="<?= h(bin2hex(random_bytes(10))) ?>">
                <div class="input-group input-group-sm"><input class="form-control" name="body" maxlength="2000" required placeholder="Add a comment" aria-label="Comment">
                  <button class="btn btn-outline-primary">Comment</button></div></form>
              <?php endif; ?>
            </div>
            <?php endif; ?>
          </div>
        </article>
        <?php endforeach; ?>

        <?php if ($canPost && !(int)$q['is_hidden']): ?>
        <form method="post" enctype="multipart/form-data" class="card iq-reply" id="answer"><div class="card-body">
          <?= csrf_field() ?><input type="hidden" name="act" value="respond">
          <input type="hidden" name="key" value="<?= h((string)(p('key') ?: bin2hex(random_bytes(10)))) ?>">
          <h2 class="h6 mb-2">Your response</h2>
          <textarea class="form-control" name="body" rows="5" maxlength="<?= Inquiries::MAX_BODY ?>" required placeholder="Share what you know. Mention people with @username."><?= h(p('act') === 'respond' ? (string)p('body') : '') ?></textarea>
          <div class="mt-2"><?= $filesField() ?></div>
          <div class="d-flex flex-wrap align-items-center gap-3 mt-2">
            <button class="btn btn-primary btn-sm"><i class="bi bi-send"></i> Post response</button>
            <?php if (Community::canModerate()): ?><div class="form-check mb-0"><input class="form-check-input" type="checkbox" name="official" value="1" id="iqOff" checked>
              <label class="form-check-label small" for="iqOff">Official response (labelled "Official")</label></div><?php endif; ?>
          </div>
        </div></form>
        <?php elseif (!$canPost): ?>
          <p class="cm-muted mt-3"><?= h(Community::muted() ? Community::sanctionText(Community::sanction()) . '.' : 'Your role may read inquiries but not respond.') ?></p>
        <?php endif; ?>
      </div>

      <div class="col-lg-4">
        <div class="card iq-side"><div class="card-body">
          <dl class="iq-facts">
            <dt>Status</dt><dd><?= $statusLabel($q['status']) ?></dd>
            <dt>Category</dt><dd><?= h($catNames[(int)$q['category_id']] ?? 'General') ?></dd>
            <dt>Asked</dt><dd><?= h(fdatetime($q['created_at'])) ?></dd>
            <dt>Last activity</dt><dd><?= h(Community::ago($q['last_activity_at'])) ?></dd>
            <dt>Responses</dt><dd><?= $count ?></dd>
            <dt>Views</dt><dd><?= (int)$q['views'] ?></dd>
            <?php if ($q['resolved_at']): ?><dt>Resolved</dt><dd><?= h(fdatetime($q['resolved_at'])) ?></dd><?php endif; ?>
          </dl>
          <p class="small text-muted mb-0">The author or a moderator chooses the accepted answer (the inquiry is then Answered) and marks it Resolved when the matter is closed.</p>
        </div></div>
      </div>
    </div>
    <script>
    (function () {
      const live = document.getElementById('iqLive');
      if (!live) return;
      setInterval(async () => {
        if (document.hidden) return;
        try {
          const r = await fetch(live.dataset.poll, { headers: { Accept: 'application/json', 'X-Background': '1' } });
          if (!(r.headers.get('content-type') || '').includes('json')) return;
          const j = await r.json();
          if (j.ok && (j.count > +live.dataset.count || j.status !== live.dataset.status)) live.hidden = false;
          if (j.ok) window.dispatchEvent(new CustomEvent('comm:notif', { detail: j.notif }));
        } catch (e) { /* try again */ }
      }, 15000);
    })();
    </script>
    <?php
    layout_end();
    return;
}

// ======================================================================= the list
$f = ['q' => (string)g('q'), 'status' => (string)g('status'), 'category' => (int)g('category'), 'mine' => g('mine') === '1', 'unanswered' => g('unanswered') === '1', 'sort' => (string)g('sort')];
$page = max(1, (int)g('page', '1'));
[$rows, $total] = Inquiries::search($f, $page, 20);
$users = Community::users(array_column($rows, 'user_id'));
$counts = DB::pairs("SELECT status, COUNT(*) FROM community_inquiries WHERE is_hidden = 0 GROUP BY status");
layout_start('Questions & Inquiries', ['actions' => ($canPost ? btn_link(url($pageKey, ['a' => 'ask']), 'Ask a question', 'btn-primary', 'plus-lg') . ' ' : '')
    . (Access::page('comm.chat') ? btn_link(url('comm.chat'), 'Community Chat', 'btn-outline-secondary', 'chat-dots') : '')]);
?>
<div class="iq-tabs" role="tablist" aria-label="Status">
  <?php foreach (['' => 'All', 'open' => 'Open', 'answered' => 'Answered', 'resolved' => 'Resolved'] as $k => $v): ?>
    <a role="tab" class="iq-tab<?= $f['status'] === $k ? ' is-on' : '' ?>" aria-selected="<?= $f['status'] === $k ? 'true' : 'false' ?>" href="<?= h(current_url(['status' => $k ?: null, 'page' => null])) ?>"><?= h($v) ?>
      <span><?= $k === '' ? array_sum(array_map('intval', $counts)) : (int)($counts[$k] ?? 0) ?></span></a>
  <?php endforeach; ?>
</div>
<form class="row g-2 mb-3 filters align-items-end" method="get">
  <input type="hidden" name="p" value="<?= h($pageKey) ?>"><?php if ($f['status']): ?><input type="hidden" name="status" value="<?= h($f['status']) ?>"><?php endif; ?>
  <div class="col-md-4"><label class="form-label" for="iqQ">Search</label><input class="form-control form-control-sm" id="iqQ" type="search" name="q" value="<?= h($f['q']) ?>" placeholder="Words in the question or its answers"></div>
  <div class="col-md-3"><label class="form-label" for="iqC">Category</label><select class="form-select form-select-sm" id="iqC" name="category"><option value="">All categories</option>
    <?php foreach ($cats as $c): ?><option value="<?= (int)$c['id'] ?>" <?= $f['category'] === (int)$c['id'] ? 'selected' : '' ?>><?= h($c['name']) ?></option><?php endforeach; ?></select></div>
  <div class="col-md-2"><label class="form-label" for="iqS">Sort</label><select class="form-select form-select-sm" id="iqS" name="sort">
    <?= options(['' => 'Recent activity', 'new' => 'Newest', 'unanswered' => 'Fewest responses'], $f['sort']) ?></select></div>
  <div class="col-md-auto d-flex gap-3 pb-1">
    <div class="form-check mb-0"><input class="form-check-input" type="checkbox" name="mine" value="1" id="iqMine" <?= $f['mine'] ? 'checked' : '' ?>><label class="form-check-label" for="iqMine">Mine</label></div>
    <div class="form-check mb-0"><input class="form-check-input" type="checkbox" name="unanswered" value="1" id="iqUn" <?= $f['unanswered'] ? 'checked' : '' ?>><label class="form-check-label" for="iqUn">No responses yet</label></div></div>
  <div class="col-md-auto"><button class="btn btn-sm btn-secondary"><i class="bi bi-funnel"></i> Filter</button></div>
</form>
<div class="card iq-list">
  <?php if (!$rows): ?>
    <div class="cm-empty py-5"><i class="bi bi-patch-question"></i><p><?= $f['q'] || $f['category'] || $f['mine'] || $f['unanswered'] ? 'No inquiries match these filters.' : 'No questions yet.' ?>
      <?php if ($canPost): ?><br><a href="<?= h(url($pageKey, ['a' => 'ask'])) ?>">Ask the first one</a><?php endif; ?></p></div>
  <?php endif; ?>
  <?php foreach ($rows as $r): $u = $users[(int)$r['user_id']]; ?>
    <a class="iq-row<?= (int)$r['is_hidden'] ? ' is-hidden' : '' ?>" href="<?= h(url($pageKey, ['id' => (int)$r['id']])) ?>">
      <div class="iq-row-stats"><span class="iq-num<?= $r['accepted_response_id'] ? ' is-answered' : '' ?>"><strong><?= (int)$r['response_count'] ?></strong> <?= (int)$r['response_count'] === 1 ? 'response' : 'responses' ?></span>
        <span class="iq-views"><?= (int)$r['views'] ?> view<?= (int)$r['views'] === 1 ? '' : 's' ?></span></div>
      <div class="iq-row-main">
        <div class="iq-row-title"><?= h($r['title']) ?><?= (int)$r['is_hidden'] ? ' <span class="cm-hidden-flag">Hidden</span>' : '' ?></div>
        <div class="iq-row-text"><?= h(Community::excerpt($r['body'], 160)) ?></div>
        <div class="iq-row-meta"><?= $statusLabel($r['status']) ?><span><?= h($r['category_name'] ?? 'General') ?></span>
          <span><?= Community::avatar($u, 'xs') ?> <?= h($u['name']) ?></span><span><?= h(Community::ago($r['last_activity_at'])) ?></span></div>
      </div>
    </a>
  <?php endforeach; ?>
</div>
<?php if ($total > 20): $pages = (int)ceil($total / 20); ?>
<nav class="mt-3 d-flex justify-content-between align-items-center" aria-label="Pages">
  <span class="small text-muted"><?= number_format($total) ?> inquiries, page <?= $page ?> of <?= $pages ?></span>
  <div class="btn-group btn-group-sm">
    <a class="btn btn-outline-secondary<?= $page <= 1 ? ' disabled' : '' ?>" href="<?= h(current_url(['page' => $page - 1])) ?>"><i class="bi bi-chevron-left"></i> Previous</a>
    <a class="btn btn-outline-secondary<?= $page >= $pages ? ' disabled' : '' ?>" href="<?= h(current_url(['page' => $page + 1])) ?>">Next <i class="bi bi-chevron-right"></i></a>
  </div>
</nav>
<?php endif; ?>
<?php
layout_end();
