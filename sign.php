<?php
declare(strict_types=1);

/**
 * v42: the page of a signature link (Request Signature on a voucher). For the person asked to sign: no account,
 * no log-in.
 *
 *   sign.php?t=<secret>            one company
 *   sign.php?c=<company>&t=<secret>  several companies: the company says which database to look in
 *
 * The secret is checked by its SHA-256 fingerprint; it leads to one signature line of one voucher and nothing else.
 * The person reviews the voucher (as a page or the PDF), draws a signature, ticks that they reviewed it, confirms,
 * and submits. The link then stops working (one use); an expired or revoked link, or one already used, says so.
 * The page is never cached, kept out of search engines, and sends no address to other sites.
 */

require __DIR__ . '/app/bootstrap.php';
require __DIR__ . '/views/layout.php';
require_once APP_ROOT . '/modules/txn/_common.php';

header('Cache-Control: no-store, private');
header('X-Robots-Tag: noindex, nofollow');
header('Referrer-Policy: no-referrer');
header('X-Frame-Options: SAMEORIGIN');
header('X-Content-Type-Options: nosniff');

$app = app_name();
$token = (string)g('t');
$state = 'invalid';       // invalid, expired, revoked, signed, open, done, cancelled, unavailable
$req = null;
$t = null;
$error = '';
$companyName = '';

/** Opens the database of the link's company; false when there is none */
$openCompany = function (): bool {
    if (!Master::enabled()) {
        return true;
    }
    $c = Master::company((int)g('c'));
    if (!$c || (string)$c['db_name'] === '' || $c['status'] !== 'active') {
        return false;
    }
    Tenant::use($c);
    return true;
};

try {
    if ($token === '' || !$openCompany()) {
        $state = 'invalid';
    } elseif (!Signatures::ready()) {
        $state = 'unavailable';
    } else {
        $req = Signatures::findByToken($token);
        if (!$req) {
            usleep(400000);   // unknown links answer slowly, so they cannot be tried quickly
        } else {
            $t = Txn::load((int)$req['transaction_id']);
            $companyName = (string)Settings::get('company_name');
            $doneHere = (int)($_SESSION['sig_done'][$req['id']] ?? 0);
            if (!$t || !Signatures::supports((string)$t['txn_type'])) {
                $state = 'invalid';
            } elseif ($req['status'] === 'signed') {
                $state = $doneHere && $doneHere > time() - 3600 ? 'done' : 'signed';
            } elseif ($req['status'] === 'revoked') {
                $state = 'revoked';
            } elseif ($req['status'] === 'expired') {
                $state = 'expired';
            } elseif ((int)$t['is_voided'] === 1) {
                $state = 'revoked';
            } else {
                $state = 'open';
            }
        }
    }

    // the company logo on the voucher (the program's own logo address needs a log-in)
    if ($req && $t && $state === 'open' && g('logo') === '1') {
        $file = Logo::path();
        if ($file) {
            $mime = ['png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'gif' => 'image/gif', 'webp' => 'image/webp'][strtolower(pathinfo($file, PATHINFO_EXTENSION))] ?? 'application/octet-stream';
            header('Content-Type: ' . $mime);
            header('Content-Length: ' . filesize($file));
            readfile($file);
            exit;
        }
        http_response_code(404);
        exit;
    }

    // the PDF of the voucher, for the signer: as it is now while the link is open; the signed copy right after signing
    if ($req && $t && g('pdf') === '1') {
        if ($state === 'open') {
            Signatures::send(VoucherPdf::build($t, Signatures::active((int)$t['id']), ['kind' => 'preview']), Signatures::fileName($t, 'review'), g('dl') === '1');
        }
        if ($state === 'done' && ($d = Signatures::latestSigned((int)$t['id']))) {
            Signatures::send(Signatures::content($d), (string)$d['file_name'], g('dl') === '1');
        }
        http_response_code(404);
        exit('This document is no longer available through this link.');
    }

    if ($state === 'open' && is_post()) {
        verify_csrf();
        if (p('cancel') === '1') {
            $state = 'cancelled';
        } else {
            try {
                if (p('consent') !== '1') {
                    fail('Tick the box to confirm that you reviewed the voucher and agree to sign it.');
                }
                $drawing = Signatures::parseStrokes((string)p('strokes'));
                Signatures::sign($t, (string)$req['slot'], ['name' => (string)$req['signer_name'], 'user_id' => null, 'request' => $req], $drawing, (string)p('doc_hash'));
                $_SESSION['sig_done'][$req['id']] = time();
                redirect(base_url() . '/sign.php?' . http_build_query(array_filter(['c' => g('c'), 't' => $token])));
            } catch (UserError $e) {
                $error = $e->getMessage();
                // it may have been used or revoked meanwhile
                $req = Signatures::findByToken($token) ?? $req;
                if ($req['status'] !== 'pending') {
                    $state = $req['status'] === 'signed' ? 'signed' : ($req['status'] === 'expired' ? 'expired' : 'revoked');
                }
            }
        }
    }
    if ($state === 'open' && !is_post()) {
        Signatures::opened($req);
    }
} catch (Throwable $e) {
    error_log('sign.php: ' . $e->getMessage());
    $state = 'unavailable';
}

$self = base_url() . '/sign.php?' . http_build_query(array_filter(['c' => g('c'), 't' => $token]));
$slotLabel = $req ? (Signatures::SLOTS[$req['slot']] ?? $req['slot']) : '';
$requester = $req && $req['created_by'] ? (string)DB::value('SELECT full_name FROM users WHERE id = :id', ['id' => $req['created_by']]) : '';
$title = $t ? 'Sign ' . Txn::ref($t) : 'Signature request';
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="no-referrer">
<title><?= h($title) ?> - <?= h($app) ?></title>
<link rel="stylesheet" href="<?= h(vendor_asset('bootstrap.css')) ?>">
<link rel="stylesheet" href="<?= h(vendor_asset('icons.css')) ?>">
<link rel="stylesheet" href="<?= h(asset('css/app.css')) ?>">
</head>
<body class="sig-public">
<header class="sig-top">
  <div class="sig-top-inner">
    <span class="sig-top-brand"><span class="brand-tile"><i class="bi bi-pen"></i></span>
      <span><span class="sig-top-co"><?= h($companyName !== '' ? $companyName : $app) ?></span><span class="sig-top-sub">Secure voucher signing</span></span></span>
    <span class="sig-top-lock"><i class="bi bi-shield-lock"></i> Private link</span>
  </div>
</header>
<main class="sig-main">
<?php if ($state === 'open'): ?>
  <div class="sig-intro">
    <h1 class="sig-h1"><?= h($title) ?></h1>
    <p class="sig-lead"><?= $requester !== '' ? h($requester) . ' of ' . h($companyName) . ' asks' : h($companyName) . ' asks' ?> <strong><?= h($req['signer_name']) ?></strong> to sign this <?= h(strtolower(Txn::label($t['txn_type']))) ?> as <strong><?= h($slotLabel) ?></strong>.
      Please review the document before signing. The link expires <?= h(fdatetime($req['expires_at'])) ?>.</p>
    <?php if ($req['message']): ?><div class="sig-note"><i class="bi bi-chat-left-text"></i> <?= h($req['message']) ?></div><?php endif; ?>
  </div>
  <?php if ($error !== ''): ?><div class="alert alert-danger"><?= h($error) ?></div><?php endif; ?>
  <div class="row g-3 sig-layout">
    <div class="col-lg-7 col-xl-8">
      <?= sign_document_viewer($t, $self . '&pdf=1', 'Review the voucher', $self . '&logo=1') ?>
    </div>
    <div class="col-lg-5 col-xl-4">
      <form method="post" action="<?= h($self) ?>" class="card sig-panel" data-sig-form data-sig-confirm="#sigConfirmModal">
        <?= csrf_field() ?>
        <input type="hidden" name="doc_hash" value="<?= h(VoucherPdf::hash($t)) ?>">
        <div class="card-body">
          <h2 class="sig-panel-title">Your signature</h2>
          <dl class="sig-facts">
            <dt>Signer</dt><dd><?= h($req['signer_name']) ?></dd>
            <dt>Signs as</dt><dd><?= h($slotLabel) ?></dd>
            <dt>Document</dt><dd><?= h(Txn::ref($t)) ?>, <?= h(fdate($t['txn_date'])) ?></dd>
            <dt>Amount</dt><dd><?= money($t['total']) ?></dd>
          </dl>
          <?= sign_pad_html() ?>
          <div class="form-check sig-consent mt-3">
            <input class="form-check-input" type="checkbox" name="consent" value="1" id="sigConsent" data-sig-consent>
            <label class="form-check-label" for="sigConsent">I, <?= h($req['signer_name']) ?>, reviewed <?= h(Txn::ref($t)) ?> and agree to sign it electronically as <?= h($slotLabel) ?>.</label>
          </div>
          <div class="d-grid gap-2 mt-3">
            <button type="submit" class="btn btn-primary" data-sig-submit disabled><i class="bi bi-send-check"></i> Submit Signature</button>
            <button type="button" class="btn btn-outline-secondary" data-bs-toggle="modal" data-bs-target="#sigCancelModal">Cancel</button>
          </div>
        </div>
      </form>
    </div>
  </div>
  <?= sign_confirm_modal('Submit your signature?', 'Your signature will be added to ' . Txn::ref($t) . ' as ' . $slotLabel . ' and a signed PDF will be saved. You cannot change it after submitting, and this link will stop working.', 'Submit Signature') ?>
  <div class="modal fade" id="sigCancelModal" tabindex="-1" aria-hidden="true"><div class="modal-dialog modal-dialog-centered"><form class="modal-content" method="post" action="<?= h($self) ?>">
    <?= csrf_field() ?><input type="hidden" name="cancel" value="1">
    <div class="modal-header"><h5 class="modal-title">Cancel signing?</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
    <div class="modal-body small">Nothing is signed. You can open the link again until <?= h(fdatetime($req['expires_at'])) ?> if you change your mind.</div>
    <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Keep signing</button><button class="btn btn-danger">Cancel signing</button></div>
  </form></div></div>
<?php else: ?>
  <div class="sig-result">
    <?php
    $icons = ['done' => 'check2-circle', 'signed' => 'patch-check', 'expired' => 'hourglass-bottom', 'revoked' => 'x-octagon', 'cancelled' => 'arrow-counterclockwise', 'unavailable' => 'tools', 'invalid' => 'link-45deg'];
    $heads = [
        'done'        => 'Thank you. Your signature was added.',
        'signed'      => 'This signature request was already completed.',
        'expired'     => 'This signature link has expired.',
        'revoked'     => 'This signature link is no longer valid.',
        'cancelled'   => 'Signing cancelled. Nothing was signed.',
        'unavailable' => 'Signing is not available at the moment.',
        'invalid'     => 'This signature link is not valid.',
    ];
    ?>
    <div class="sig-result-ico sig-r-<?= h($state) ?>"><i class="bi bi-<?= h($icons[$state] ?? 'info-circle') ?>"></i></div>
    <h1 class="sig-h1"><?= h($heads[$state] ?? 'Signature request') ?></h1>
    <?php if ($state === 'done' && $t): $s = DB::row('SELECT signed_at FROM voucher_signatures WHERE id = :id', ['id' => $req['signature_id']]); ?>
      <p class="sig-lead">You signed <strong><?= h(Txn::ref($t)) ?></strong> as <?= h($slotLabel) ?><?= $s ? ' on ' . h(fdatetime($s['signed_at'])) : '' ?>. <?= h($companyName) ?> has the signed copy.</p>
      <div class="sig-result-actions">
        <a class="btn btn-primary" href="<?= h($self . '&pdf=1&dl=1') ?>"><i class="bi bi-download"></i> Download signed copy</a>
        <a class="btn btn-outline-secondary" href="<?= h($self . '&pdf=1') ?>" target="_blank" rel="noopener"><i class="bi bi-eye"></i> View</a>
      </div>
      <p class="small text-muted mt-3">The copy can be downloaded from this page for one hour. You can close this page.</p>
    <?php elseif ($state === 'signed'): ?>
      <p class="sig-lead">The link was used<?= $req['signed_at'] ? ' on ' . h(fdatetime($req['signed_at'])) : '' ?>. A signature can be submitted only once. If you need a copy, ask <?= h($companyName) ?>.</p>
    <?php elseif ($state === 'expired'): ?>
      <p class="sig-lead">Links can be used only until their expiry date. Ask <?= h($companyName) ?> to send you a new one.</p>
    <?php elseif ($state === 'revoked'): ?>
      <p class="sig-lead">The sender revoked this link or the document was cancelled. Ask <?= h($companyName) ?> if you still need to sign.</p>
    <?php elseif ($state === 'cancelled'): ?>
      <p class="sig-lead">You can open the link again until <?= h(fdatetime($req['expires_at'])) ?>.</p>
      <div class="sig-result-actions"><a class="btn btn-outline-primary" href="<?= h($self) ?>">Back to the document</a></div>
    <?php elseif ($state === 'unavailable'): ?>
      <p class="sig-lead">Please try again later, or contact the person who sent you the link.</p>
    <?php else: ?>
      <p class="sig-lead">Check that you opened the whole link exactly as it was sent to you. If it still does not work, ask the sender for a new link.</p>
    <?php endif; ?>
  </div>
<?php endif; ?>
</main>
<footer class="sig-foot"><?= h($app) ?>. Your signature, the date and time, and your internet address are recorded with the document.</footer>
<script src="<?= h(vendor_asset('bootstrap.js')) ?>"></script>
<script src="<?= h(asset('js/signature.js')) ?>"></script>
</body>
</html>
