<?php
declare(strict_types=1);

/**
 * v42: the signing screens of the vouchers that are signed (Check Voucher of Write Checks, Cash Voucher, Journal Entry).
 *
 *   ?a=sign          Sign Voucher: review the voucher, choose the line, draw, confirm
 *   ?a=sign_request  Request Signature (POST): a link for one person and one line
 *   ?a=sign_revoke   revoke a link (POST)
 *   ?a=sign_reset    reset the signatures (POST, Delete/Void right, reason)
 *   ?a=sign_pdf      the PDF: doc=<id> a saved copy (original or signed), doc=review the voucher as it is now;
 *                    dl=1 to download
 *
 * The pad, the document viewer and the signatures box are also used by the outside signer's page (sign.php).
 */

/** Handles the signing actions of txn_common_actions(); true when one was handled */
function voucher_sign_actions(string $pageKey, array $t, string $a): bool
{
    $id = (int)$t['id'];
    if (!Signatures::on($t)) {
        flash('warning', Signatures::ready() ? 'This document is not signed digitally.' : 'Voucher signatures need a database update: run database/migrations/2027_02_11_voucher_signatures.sql.');
        redirect(Txn::url($t));
    }
    switch ($a) {
        case 'sign':
            if (!Signatures::canSign($pageKey)) {
                Access::denyPage($pageKey, 'sign vouchers on');
            }
            render_sign_page($t, $pageKey);
            return true;

        case 'sign_request':
            if (!Signatures::canRequest($pageKey)) {
                Access::denyPage($pageKey, 'request signatures on');
            }
            if (!is_post()) {
                redirect(Txn::url($t));
            }
            try {
                $r = Signatures::request($t, (string)p('slot'), (string)p('signer_name'), (string)p('signer_email'), (string)p('message'), (int)p('days', 7));
                $_SESSION['sig_new_link'] = ['txn' => $id, 'id' => $r['id'], 'link' => $r['link'], 'name' => trim((string)p('signer_name')), 'email' => trim((string)p('signer_email'))];
                flash('success', 'Signature link created. Copy it and send it to ' . trim((string)p('signer_name')) . '.');
            } catch (UserError $e) {
                flash('danger', $e->getMessage());
            }
            redirect(Txn::url($t));

        case 'sign_revoke':
            if (!Signatures::canRequest($pageKey)) {
                Access::denyPage($pageKey, 'revoke signature links on');
            }
            if (is_post()) {
                try {
                    Signatures::revoke($t, (int)p('request_id'), (string)p('reason'));
                    flash('success', 'The link was revoked. It no longer opens the voucher.');
                } catch (UserError $e) {
                    flash('danger', $e->getMessage());
                }
            }
            redirect(Txn::url($t));

        case 'sign_reset':
            if (!Signatures::canReset($pageKey)) {
                Access::denyPage($pageKey, 'reset signatures on');
            }
            if (is_post()) {
                try {
                    $n = Signatures::reset($t, (string)p('reason'));
                    flash('success', $n . ' signature' . ($n === 1 ? ' was' : 's were') . ' reset. The voucher can be changed again; the signed copies stay on record.');
                } catch (UserError $e) {
                    flash('danger', $e->getMessage());
                }
            }
            redirect(Txn::url($t));

        case 'sign_pdf':
            if (!Signatures::canView($pageKey)) {
                Access::denyPage($pageKey, 'open the PDF copies of');
            }
            $download = g('dl') === '1';
            if (g('doc') === 'review') {
                Signatures::send(VoucherPdf::build($t, Signatures::active($id), ['kind' => 'preview']), Signatures::fileName($t, 'review'), $download);
            }
            $doc = Signatures::doc($id, (int)g('doc'));
            if (!$doc) {
                flash('warning', 'That PDF copy was not found.');
                redirect(Txn::url($t));
            }
            try {
                $pdf = Signatures::content($doc);
            } catch (UserError $e) {
                flash('danger', $e->getMessage());
                redirect(Txn::url($t));
            }
            if ($download) {
                Signatures::audit('sign_pdf', $t, 'Downloaded ' . $doc['file_name'] . '.');
            }
            Signatures::send($pdf, (string)$doc['file_name'], $download);
    }
    return false;
}

/** Signature lines still open: not signed and no link waiting */
function sign_free_slots(array $t): array
{
    $id = (int)$t['id'];
    return array_diff_key(Signatures::slots($t), Signatures::active($id), Signatures::pending($id));
}

/** The Sign Voucher page */
function render_sign_page(array $t, string $pageKey): void
{
    $id = (int)$t['id'];
    if ((int)$t['is_voided'] === 1) {
        flash('warning', 'A voided voucher cannot be signed.');
        redirect(Txn::url($t));
    }
    $me = Auth::user();
    $active = Signatures::active($id);
    foreach ($active as $s) {
        if ((int)$s['signer_user_id'] === (int)Auth::id()) {
            flash('info', 'You already signed this voucher (' . Signatures::SLOTS[$s['slot']] . '). Each person signs one line.');
            redirect(Txn::url($t));
        }
    }
    $free = sign_free_slots($t);
    if (!$free) {
        flash('info', 'Every signature line of this voucher is signed or waiting for a signature link.');
        redirect(Txn::url($t));
    }
    if (is_post()) {
        try {
            $slot = (string)p('slot');
            if (!isset($free[$slot])) {
                fail('Choose a signature line that is still open.');
            }
            if (p('consent') !== '1') {
                fail('Tick the box to confirm that you reviewed the voucher and sign it.');
            }
            $drawing = Signatures::parseStrokes((string)p('strokes'));
            Signatures::sign($t, $slot, ['name' => (string)$me['full_name'], 'user_id' => (int)Auth::id()], $drawing, (string)p('doc_hash'));
            flash('success', 'You signed ' . Txn::ref($t) . ' (' . Signatures::SLOTS[$slot] . '). The signed PDF was saved.');
            redirect(Txn::url($t) . '#signatures');
        } catch (UserError $e) {
            flash('danger', $e->getMessage());
            redirect(Txn::url($t, 'sign'));
        }
    }
    // the line most likely meant: Prepared by for whoever recorded it, Approved by for whoever approved it
    $pick = array_key_first($free);
    if ((int)$t['created_by'] === (int)Auth::id() && isset($free['prepared'])) {
        $pick = 'prepared';
    } elseif ((int)($t['approved_by'] ?? 0) === (int)Auth::id() && isset($free['approved'])) {
        $pick = 'approved';
    }
    $hash = VoucherPdf::hash($t);
    layout_start('Sign ' . Txn::ref($t), ['actions' => btn_link(Txn::url($t), 'Back to voucher', 'btn-outline-secondary', 'arrow-left'),
        'js' => ['js/signature.js'], 'body_class' => 'sig-page']);
    ?>
    <div class="row g-3 sig-layout">
      <div class="col-lg-7 col-xl-8">
        <?= sign_document_viewer($t, Txn::url($t, 'sign_pdf') . '&doc=review') ?>
      </div>
      <div class="col-lg-5 col-xl-4">
        <form method="post" class="card sig-panel" data-sig-form data-sig-confirm="#sigConfirmModal">
          <?= csrf_field() ?>
          <input type="hidden" name="doc_hash" value="<?= h($hash) ?>">
          <div class="card-body">
            <h2 class="sig-panel-title">Your signature</h2>
            <p class="sig-panel-who">Signing as <strong><?= h($me['full_name']) ?></strong><span class="text-muted"> (<?= h($me['username']) ?>)</span></p>
            <div class="mb-3">
              <div class="form-label">Signature line</div>
              <div class="sig-slot-pick">
                <?php foreach (Signatures::slots($t) as $slot => $label): $isFree = isset($free[$slot]); ?>
                  <label class="sig-slot-opt<?= $isFree ? '' : ' is-taken' ?>">
                    <input type="radio" name="slot" value="<?= h($slot) ?>" <?= $slot === $pick ? 'checked' : '' ?> <?= $isFree ? '' : 'disabled' ?> required>
                    <span class="sig-slot-name"><?= h($label) ?></span>
                    <span class="sig-slot-note"><?= $isFree ? 'Open' : (isset($active[$slot]) ? 'Signed by ' . h($active[$slot]['signer_name']) : 'Link sent') ?></span>
                  </label>
                <?php endforeach; ?>
              </div>
            </div>
            <?= sign_pad_html() ?>
            <div class="form-check sig-consent mt-3">
              <input class="form-check-input" type="checkbox" name="consent" value="1" id="sigConsent" data-sig-consent>
              <label class="form-check-label" for="sigConsent">I reviewed <?= h(Txn::ref($t)) ?> for <?= money($t['total']) ?> and I sign it as shown.</label>
            </div>
            <div class="d-grid gap-2 mt-3">
              <button type="submit" class="btn btn-primary" data-sig-submit disabled><i class="bi bi-pen"></i> Confirm and sign</button>
              <a class="btn btn-outline-secondary" href="<?= h(Txn::url($t)) ?>">Cancel</a>
            </div>
          </div>
        </form>
      </div>
    </div>
    <?= sign_confirm_modal('Sign ' . Txn::ref($t) . '?', 'Your signature will be placed on the selected line and a signed PDF copy will be saved. The voucher cannot be changed while it is signed.', 'Sign voucher') ?>
    <?php
    layout_end();
}

/** The drawing pad: Undo, Clear, and a larger pad on phones */
function sign_pad_html(): string
{
    return '<div class="sig-pad" data-sig-pad>'
        . '<div class="sig-pad-head"><span class="form-label mb-0">Draw your signature</span>'
        . '<span class="sig-pad-tools"><button type="button" class="btn btn-sm btn-light" data-sig-undo disabled title="Undo the last stroke"><i class="bi bi-arrow-counterclockwise"></i> <span>Undo</span></button>'
        . '<button type="button" class="btn btn-sm btn-light" data-sig-redo disabled title="Redo the stroke taken off"><i class="bi bi-arrow-clockwise"></i> <span>Redo</span></button>'
        . '<button type="button" class="btn btn-sm btn-light" data-sig-clear disabled title="Clear the pad and sign again"><i class="bi bi-eraser"></i> <span>Clear</span></button>'
        . '<button type="button" class="btn btn-sm btn-light d-lg-none" data-sig-expand title="Larger pad"><i class="bi bi-arrows-fullscreen"></i></button></span></div>'
        . '<div class="sig-pad-area"><canvas aria-label="Signature pad: draw with a mouse, finger or stylus"></canvas>'
        . '<div class="sig-pad-guide" aria-hidden="true"><span class="sig-pad-x">&times;</span><span class="sig-pad-hint">Sign here</span></div>'
        . '<div class="sig-pad-fullbar"><span>Sign in the white box. Turn your phone sideways for more room.</span>'
        . '<button type="button" class="btn btn-sm btn-light" data-sig-clear2><i class="bi bi-eraser"></i> Clear</button>'
        . '<button type="button" class="btn btn-primary btn-sm" data-sig-collapse>Done</button></div></div>'
        . '<div class="sig-pad-foot">Use a mouse, your finger or a stylus. Sign as you would on paper.</div>'
        . '<input type="hidden" name="strokes" value="" data-sig-data>'
        . '</div>';
}

/** The voucher to review: as a page (fits any screen) or as the PDF */
function sign_document_viewer(array $t, string $pdfUrl, string $title = 'Review the voucher', ?string $logoUrl = null): string
{
    ob_start();
    txn_print_body($t);
    $body = (string)ob_get_clean();
    if ($logoUrl !== null && ($own = Logo::url()) !== '') {
        $body = str_replace(h($own), h($logoUrl), $body);   // the outside signer's page shows the logo through the link
    }
    ob_start();
    ?>
    <div class="card sig-doc" data-sig-doc>
      <div class="card-header sig-doc-head">
        <div class="sig-doc-title"><i class="bi bi-file-earmark-text"></i> <?= h($title) ?></div>
        <div class="sig-doc-tools">
          <div class="btn-group btn-group-sm" role="group" aria-label="View">
            <button type="button" class="btn btn-outline-secondary active" data-sig-view="page">Page</button>
            <button type="button" class="btn btn-outline-secondary" data-sig-view="pdf">PDF</button>
          </div>
          <a class="btn btn-sm btn-outline-secondary" href="<?= h($pdfUrl) ?>" target="_blank" rel="noopener"><i class="bi bi-box-arrow-up-right"></i> Open PDF</a>
        </div>
      </div>
      <div class="sig-doc-body">
        <div class="sig-paper" data-sig-paper><div class="sig-paper-sheet"><?= $body ?></div></div>
        <div class="sig-pdf d-none" data-sig-pdf><iframe title="Voucher PDF" data-src="<?= h($pdfUrl) ?>"></iframe></div>
      </div>
      <div class="sig-doc-foot"><i class="bi bi-info-circle"></i> Read the whole voucher before you sign: payee, amount, accounts and lines.</div>
    </div>
    <?php
    return (string)ob_get_clean();
}

/** "Are you sure?" before a signature is submitted */
function sign_confirm_modal(string $title, string $text, string $button): string
{
    return '<div class="modal fade" id="sigConfirmModal" tabindex="-1" aria-hidden="true"><div class="modal-dialog modal-dialog-centered"><div class="modal-content">'
        . '<div class="modal-header"><h5 class="modal-title">' . h($title) . '</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>'
        . '<div class="modal-body"><div class="sig-confirm-preview" data-sig-preview></div><p class="mb-0 small">' . h($text) . '</p></div>'
        . '<div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Go back</button>'
        . '<button type="button" class="btn btn-primary" data-sig-final><span class="spinner-border spinner-border-sm d-none" aria-hidden="true"></span> ' . h($button) . '</button></div>'
        . '</div></div></div>';
}

/** The Signatures box on the voucher page */
function signatures_card(array $t, string $pageKey): string
{
    $id = (int)$t['id'];
    $slots = Signatures::slots($t);
    $active = Signatures::active($id);
    $requests = Signatures::requests($id);
    $pending = [];
    foreach ($requests as $r) {
        if ($r['status'] === 'pending' && !isset($pending[$r['slot']])) {
            $pending[$r['slot']] = $r;
        }
    }
    $sum = Signatures::summary($t);
    $voided = (int)$t['is_voided'] === 1;
    $canSign = !$voided && Signatures::canSign($pageKey);
    $canReq = !$voided && Signatures::canRequest($pageKey);
    $free = array_diff_key($slots, $active, $pending);
    $mineSigned = (bool)array_filter($active, fn($s) => (int)$s['signer_user_id'] === (int)Auth::id());
    $docs = Signatures::docs($id);
    $signedDocs = array_values(array_filter($docs, fn($d) => $d['kind'] === 'signed'));
    $original = array_values(array_filter($docs, fn($d) => $d['kind'] === 'original'))[0] ?? null;
    $pdfUrl = fn(int $docId, bool $dl) => Txn::url($t, 'sign_pdf') . '&doc=' . $docId . ($dl ? '&dl=1' : '');
    ob_start();
    ?>
    <div class="card mb-3 sig-card" id="signatures">
      <div class="card-header sig-card-head">
        <span class="small fw-semibold"><i class="bi bi-pen"></i> Signatures</span>
        <span class="sig-status sig-st-<?= h($sum['key']) ?>"><?= h($sum['label']) ?><span class="sig-count"><?= (int)$sum['signed'] ?> of <?= (int)$sum['total'] ?></span></span>
      </div>
      <ul class="list-group list-group-flush sig-slots">
        <?php foreach ($slots as $slot => $label): $s = $active[$slot] ?? null; $r = $pending[$slot] ?? null; ?>
        <li class="list-group-item sig-slot<?= $s ? ' is-signed' : ($r ? ' is-waiting' : '') ?>">
          <div class="sig-slot-top">
            <span class="sig-slot-label"><?= h($label) ?></span>
            <span class="sig-slot-state"><?= $s ? 'Signed' : ($r ? 'Awaiting signature' : 'Not signed') ?></span>
          </div>
          <?php if ($s): ?>
            <div class="sig-slot-ink"><?= Signatures::svg((string)$s['strokes']) ?></div>
            <div class="sig-slot-meta"><strong><?= h($s['signer_name']) ?></strong><br><?= h(fdatetime($s['signed_at'])) ?>, <?= $s['method'] === 'link' ? 'through a signature link' : 'in the system' ?></div>
          <?php elseif ($r): $link = $canReq ? Signatures::link($r) : null; ?>
            <div class="sig-slot-meta">Link sent to <strong><?= h($r['signer_name']) ?></strong><?= $r['signer_email'] ? ' (' . h($r['signer_email']) . ')' : '' ?><br>
              Expires <?= h(fdatetime($r['expires_at'])) ?>. <?= $r['first_opened_at'] ? 'Opened ' . (int)$r['open_count'] . ' time' . ((int)$r['open_count'] === 1 ? '' : 's') . ', last ' . h(fdatetime($r['last_opened_at'])) . '.' : 'Not opened yet.' ?></div>
            <?php if ($canReq): ?>
            <div class="sig-slot-tools">
              <?php if ($link): ?>
                <button type="button" class="btn btn-sm btn-outline-primary" data-copy="<?= h($link) ?>"><i class="bi bi-clipboard"></i> <span>Copy link</span></button>
                <?php if ($r['signer_email']): ?><a class="btn btn-sm btn-outline-secondary" href="<?= h(sign_mailto($t, $r['signer_email'], $r['signer_name'], $link, (string)$r['expires_at'])) ?>"><i class="bi bi-envelope"></i> Email</a><?php endif; ?>
              <?php else: ?>
                <span class="small text-muted">The link can no longer be shown here. Revoke it and send a new one if it was lost.</span>
              <?php endif; ?>
              <form method="post" action="<?= h(Txn::url($t, 'sign_revoke')) ?>" class="d-inline"><?= csrf_field() ?><input type="hidden" name="request_id" value="<?= (int)$r['id'] ?>">
                <button class="btn btn-sm btn-outline-danger" data-confirm="Revoke the link sent to <?= h($r['signer_name']) ?>? It will stop working at once."><i class="bi bi-x-circle"></i> Revoke</button></form>
            </div>
            <?php endif; ?>
          <?php else: ?>
            <div class="sig-slot-meta text-muted"><?= $voided ? 'The voucher is void.' : 'Open for signing.' ?></div>
          <?php endif; ?>
        </li>
        <?php endforeach; ?>
      </ul>
      <div class="card-body sig-card-body">
        <?php if (($canSign && $free && !$mineSigned) || ($canReq && $free)): ?>
        <div class="sig-card-actions">
          <?php if ($canSign && $free && !$mineSigned): ?><a class="btn btn-sm btn-primary" href="<?= h(Txn::url($t, 'sign')) ?>"><i class="bi bi-pen"></i> Sign Voucher</a><?php endif; ?>
          <?php if ($canReq && $free): ?><button type="button" class="btn btn-sm btn-outline-primary" data-bs-toggle="modal" data-bs-target="#sigRequestModal"><i class="bi bi-link-45deg"></i> Request Signature</button><?php endif; ?>
        </div>
        <?php endif; ?>
        <?php if ($signedDocs || $original): ?>
        <div class="sig-files">
          <?php if ($signedDocs): $d = $signedDocs[0]; ?>
          <div class="sig-file">
            <i class="bi bi-file-earmark-check sig-file-ico"></i>
            <div class="sig-file-text"><div class="sig-file-name">Signed PDF, version <?= (int)$d['version'] ?></div><div class="sig-file-sub"><?= (int)$d['signature_count'] ?> of <?= count($slots) ?> signed, <?= h(fdatetime($d['created_at'])) ?></div></div>
            <a class="btn btn-sm btn-light" href="<?= h($pdfUrl((int)$d['id'], false)) ?>" target="_blank" rel="noopener" title="Preview"><i class="bi bi-eye"></i></a>
            <a class="btn btn-sm btn-light" href="<?= h($pdfUrl((int)$d['id'], true)) ?>" title="Download"><i class="bi bi-download"></i></a>
          </div>
          <?php endif; ?>
          <?php if ($original): ?>
          <div class="sig-file">
            <i class="bi bi-file-earmark sig-file-ico"></i>
            <div class="sig-file-text"><div class="sig-file-name">Original unsigned voucher</div><div class="sig-file-sub">Kept <?= h(fdatetime($original['created_at'])) ?></div></div>
            <a class="btn btn-sm btn-light" href="<?= h($pdfUrl((int)$original['id'], false)) ?>" target="_blank" rel="noopener" title="Preview"><i class="bi bi-eye"></i></a>
            <a class="btn btn-sm btn-light" href="<?= h($pdfUrl((int)$original['id'], true)) ?>" title="Download"><i class="bi bi-download"></i></a>
          </div>
          <?php endif; ?>
          <?php if (count($signedDocs) > 1): ?>
          <details class="sig-more"><summary>Earlier signed copies (<?= count($signedDocs) - 1 ?>)</summary>
            <?php foreach (array_slice($signedDocs, 1) as $d): ?>
              <div class="sig-more-row"><span>Version <?= (int)$d['version'] ?>, <?= h(fdatetime($d['created_at'])) ?></span>
                <span class="sig-more-links"><a href="<?= h($pdfUrl((int)$d['id'], false)) ?>" target="_blank" rel="noopener">Preview</a> <a href="<?= h($pdfUrl((int)$d['id'], true)) ?>">Download</a></span></div>
            <?php endforeach; ?>
          </details>
          <?php endif; ?>
        </div>
        <?php endif; ?>
        <?php if ($active): ?>
        <div class="sig-lock"><i class="bi bi-lock"></i> Signed vouchers cannot be edited, voided or deleted.
          <?php if (Signatures::canReset($pageKey)): ?><button type="button" class="btn btn-link btn-sm p-0 align-baseline" data-bs-toggle="modal" data-bs-target="#sigResetModal">Reset signatures</button><?php endif; ?></div>
        <?php endif; ?>
        <?php $act = Signatures::activity($id, 10); if ($act): ?>
        <details class="sig-more"><summary>Signature activity</summary>
          <ol class="sig-activity">
            <?php foreach ($act as $e): ?>
              <li><span class="sig-act-when"><?= h(fdatetime($e['created_at'])) ?></span> <span class="sig-act-who"><?= h($e['username']) ?></span><div><?= h($e['reason']) ?></div></li>
            <?php endforeach; ?>
          </ol>
        </details>
        <?php endif; ?>
      </div>
    </div>
    <?php
    return (string)ob_get_clean();
}

/** The dialogs of the Signatures box: Request Signature, the new link, Reset signatures */
function signatures_modals(array $t, string $pageKey): string
{
    $id = (int)$t['id'];
    $free = sign_free_slots($t);
    $out = '';
    if ($free && (int)$t['is_voided'] === 0 && Signatures::canRequest($pageKey)) {
        $opts = '';
        foreach ($free as $slot => $label) {
            $opts .= '<option value="' . h($slot) . '"' . ($slot === 'received' && $t['txn_type'] !== 'journal' ? ' selected' : '') . '>' . h($label) . '</option>';
        }
        $days = '';
        foreach (Signatures::EXPIRY_DAYS as $d => $label) {
            $days .= '<option value="' . $d . '"' . ($d === 7 ? ' selected' : '') . '>' . h($label) . '</option>';
        }
        $out .= '<div class="modal fade" id="sigRequestModal" tabindex="-1" aria-hidden="true"><div class="modal-dialog modal-dialog-centered"><form class="modal-content" method="post" action="' . h(Txn::url($t, 'sign_request')) . '" data-busy>'
            . csrf_field()
            . '<div class="modal-header"><h5 class="modal-title">Request Signature</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>'
            . '<div class="modal-body"><p class="small text-muted">A secure link to sign ' . h(Txn::ref($t)) . ' is made for one person. They open it without logging in, review the voucher and sign the line you choose. The link works once.</p>'
            . '<div class="row g-2">'
            . '<div class="col-12"><label class="form-label" for="sigReqName">Signer\'s full name</label><input class="form-control" id="sigReqName" name="signer_name" maxlength="120" required autocomplete="off"></div>'
            . '<div class="col-sm-7"><label class="form-label" for="sigReqEmail">Email (optional)</label><input class="form-control" id="sigReqEmail" type="email" name="signer_email" maxlength="160" autocomplete="off"></div>'
            . '<div class="col-sm-5"><label class="form-label" for="sigReqSlot">Signature line</label><select class="form-select" id="sigReqSlot" name="slot" data-no-combo>' . $opts . '</select></div>'
            . '<div class="col-sm-5"><label class="form-label" for="sigReqDays">Link expires in</label><select class="form-select" id="sigReqDays" name="days" data-no-combo>' . $days . '</select></div>'
            . '<div class="col-sm-7"><label class="form-label" for="sigReqMsg">Message to the signer (optional)</label><input class="form-control" id="sigReqMsg" name="message" maxlength="255"></div>'
            . '</div></div>'
            . '<div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancel</button>'
            . '<button class="btn btn-primary"><i class="bi bi-link-45deg"></i> Generate link</button></div></form></div></div>';
    }
    $new = $_SESSION['sig_new_link'] ?? null;
    if ($new && (int)$new['txn'] === $id) {
        unset($_SESSION['sig_new_link']);
        $r = DB::row('SELECT expires_at FROM voucher_sign_requests WHERE id = :id', ['id' => $new['id']]);
        $out .= '<div class="modal fade" id="sigLinkModal" tabindex="-1" aria-hidden="true" data-show-now><div class="modal-dialog modal-dialog-centered"><div class="modal-content">'
            . '<div class="modal-header"><h5 class="modal-title">Signature link for ' . h($new['name']) . '</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>'
            . '<div class="modal-body"><p class="small text-muted mb-2">Send this link to ' . h($new['name']) . ' only. Anyone with the link can open this voucher until it is signed, revoked or expires' . ($r ? ' (' . h(fdatetime($r['expires_at'])) . ')' : '') . '.</p>'
            . '<div class="input-group"><input class="form-control sig-link-input" value="' . h($new['link']) . '" readonly data-select-all aria-label="Signature link">'
            . '<button type="button" class="btn btn-primary" data-copy="' . h($new['link']) . '"><i class="bi bi-clipboard"></i> <span>Copy Link</span></button></div>'
            . '<div class="sig-share mt-3">'
            . ($new['email'] !== '' && $r ? '<a class="btn btn-sm btn-outline-secondary" href="' . h(sign_mailto($t, $new['email'], $new['name'], $new['link'], (string)$r['expires_at'])) . '"><i class="bi bi-envelope"></i> Email the link</a>' : '')
            . '<button type="button" class="btn btn-sm btn-outline-secondary d-none" data-share="' . h($new['link']) . '" data-share-title="' . h('Please sign ' . Txn::ref($t)) . '"><i class="bi bi-share"></i> Share</button></div></div>'
            . '<div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Done</button></div></div></div></div>';
    }
    if (Signatures::canReset($pageKey) && Signatures::locked($id)) {
        $out .= reason_modal('sigResetModal', 'Reset signatures', Txn::url($t, 'sign_reset'), 'btn-danger',
            '<p class="small text-muted mt-2">Every signature is taken off the voucher so it can be corrected and signed again. The signed PDF copies and the signatures stay on record in the audit trail.</p>');
    }
    return $out;
}

/** An email to the signer with the link (opened in the user's mail program) */
function sign_mailto(array $t, string $email, string $name, string $link, string $expires): string
{
    $company = Settings::get('company_name');
    $subject = 'Please sign ' . Txn::ref($t) . ' - ' . $company;
    $body = 'Hello ' . $name . ",\n\nPlease review and sign " . Txn::ref($t) . ' dated ' . fdate($t['txn_date']) . ' for ' . money($t['total']) . ".\n\n"
        . 'Open this secure link (no account needed): ' . $link . "\n\nThe link can be used once and expires on " . fdatetime($expires) . ".\n\nThank you,\n" . (Auth::user()['full_name'] ?? '') . "\n" . $company;
    return 'mailto:' . rawurlencode($email) . '?subject=' . rawurlencode($subject) . '&body=' . rawurlencode($body);
}
