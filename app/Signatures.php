<?php
declare(strict_types=1);

/**
 * v42: Digital voucher signatures, for the Check Voucher (Write Checks), the Cash Voucher and the Journal Entry.
 *
 *  Two ways to sign, one result:
 *   - in the system: a user with the right opens the voucher, Sign Voucher, reviews it, draws on the pad, confirms;
 *   - through a link: Request Signature makes a secret link for one named person and one signature line; that person
 *     opens it without an account (sign.php), reviews the voucher, draws, confirms and submits.
 *  Either way the signature is kept as ink strokes, drawn on its line of the voucher PDF (VoucherPdf), and a new
 *  signed PDF copy is saved. The original unsigned voucher is kept as a PDF when it is first signed.
 *
 *  Rules
 *   - one signature per line; a user signs one line of a voucher; a link is for one line and is used once;
 *   - a link expires (1 to 30 days), can be revoked, and only a SHA-256 fingerprint of its secret is used to find
 *     it: the link holds no voucher number, so changing the address cannot open another voucher;
 *   - the signer signs what they saw: the fingerprint of the voucher content is checked when the signature is
 *     submitted, and kept with it;
 *   - a signed voucher cannot be edited, voided or deleted until its signatures are reset (Delete/Void right,
 *     with a reason; the reset signatures stay on record);
 *   - every step is written to the audit trail.
 */
final class Signatures
{
    public const TYPES = ['check', 'cash_voucher', 'journal'];
    public const SLOTS = ['prepared' => 'Prepared by', 'checked' => 'Checked by', 'approved' => 'Approved by', 'received' => 'Received by'];
    public const STATUS = ['unsigned' => 'Unsigned', 'awaiting' => 'Awaiting signature', 'partial' => 'Partially signed', 'full' => 'Fully signed'];
    public const EXPIRY_DAYS = [1 => '1 day', 3 => '3 days', 7 => '7 days', 14 => '14 days', 30 => '30 days'];
    private const CHUNK = 240000;
    private const MAX_POINTS = 8000;
    private const MAX_STROKES = 300;

    /** database name => the tables are there */
    private static array $ready = [];

    // ------------------------------------------------------------------ what can be signed

    /** The tables are there (the 2027_02_11 migration was run) */
    public static function ready(): bool
    {
        $db = DB::databaseName();
        if (!isset(self::$ready[$db])) {
            try {
                DB::value('SELECT (SELECT COUNT(*) FROM voucher_signatures WHERE 1 = 0) + (SELECT COUNT(*) FROM voucher_sign_requests WHERE 1 = 0) + (SELECT COUNT(*) FROM voucher_document_chunks WHERE 1 = 0)');
                self::$ready[$db] = true;
            } catch (Throwable $e) {
                self::$ready[$db] = false;
            }
        }
        return self::$ready[$db];
    }

    public static function supports(string $type): bool
    {
        return in_array($type, self::TYPES, true);
    }

    /** Signing is offered on this voucher */
    public static function on(array $t): bool
    {
        return self::supports((string)$t['txn_type']) && self::ready();
    }

    /** The signature lines of the voucher, as printed: Received by on the check and the cash voucher */
    public static function slots(array $t): array
    {
        $s = self::SLOTS;
        if (!in_array($t['txn_type'], ['check', Posting::CASH_VOUCHER], true)) {
            unset($s['received']);
        }
        return $s;
    }

    // ------------------------------------------------------------------ state

    /** slot => the signature on that line */
    public static function active(int $txnId): array
    {
        $out = [];
        foreach (DB::all('SELECT * FROM voucher_signatures WHERE transaction_id = :t AND is_active = 1 ORDER BY signed_at, id', ['t' => $txnId]) as $r) {
            $out[$r['slot']] = $r;
        }
        return $out;
    }

    /** Signature links of a voucher, newest first (links past their date are marked expired first) */
    public static function requests(int $txnId): array
    {
        self::expire($txnId);
        return DB::all('SELECT r.*, u.full_name AS created_by_name FROM voucher_sign_requests r LEFT JOIN users u ON u.id = r.created_by
                         WHERE r.transaction_id = :t ORDER BY r.id DESC', ['t' => $txnId]);
    }

    /** slot => the pending link of that line */
    public static function pending(int $txnId): array
    {
        $out = [];
        foreach (self::requests($txnId) as $r) {
            if ($r['status'] === 'pending' && !isset($out[$r['slot']])) {
                $out[$r['slot']] = $r;
            }
        }
        return $out;
    }

    public static function expire(?int $txnId = null): void
    {
        DB::run("UPDATE voucher_sign_requests SET status = 'expired' WHERE status = 'pending' AND expires_at < :now" . ($txnId ? ' AND transaction_id = :t' : ''),
            $txnId ? ['now' => date('Y-m-d H:i:s'), 't' => $txnId] : ['now' => date('Y-m-d H:i:s')]);
    }

    /**
     * Where the voucher stands: unsigned, awaiting (links sent, nothing signed yet), partial, full.
     * Returns ['key', 'label', 'signed', 'total', 'pending']
     */
    public static function summary(array $t): array
    {
        $slots = self::slots($t);
        $signed = count(array_intersect_key(self::active((int)$t['id']), $slots));
        $pending = count(self::pending((int)$t['id']));
        $total = count($slots);
        $key = $signed >= $total ? 'full' : ($signed > 0 ? 'partial' : ($pending > 0 ? 'awaiting' : 'unsigned'));
        return ['key' => $key, 'label' => self::STATUS[$key], 'signed' => $signed, 'total' => $total, 'pending' => $pending];
    }

    /** A voucher with any signature is locked: no edit, void or delete until the signatures are reset */
    public static function locked(int $txnId): bool
    {
        if (!self::ready()) {
            return false;
        }
        return (int)DB::value('SELECT COUNT(*) FROM voucher_signatures WHERE transaction_id = :t AND is_active = 1', ['t' => $txnId]) > 0;
    }

    /** Fails when the voucher is signed (called by Txn::save, void and delete) */
    public static function assertUnlocked(array $t, string $doing): void
    {
        if (self::supports((string)$t['txn_type']) && self::locked((int)$t['id'])) {
            fail(Txn::ref($t) . ' is signed and cannot be ' . $doing . '. Reset its signatures first (Signatures box on the voucher, Delete/Void right).');
        }
    }

    // ------------------------------------------------------------------ rights (the voucher's own page)

    /** Sign in the system: the Edit or Approve right on the voucher's page */
    public static function canSign(string $pageKey): bool
    {
        return Access::can($pageKey, 'edit') || Access::can($pageKey, 'approve');
    }

    /** Send and revoke links: the same */
    public static function canRequest(string $pageKey): bool
    {
        return self::canSign($pageKey);
    }

    /** Reset the signatures (unlocks the voucher): the Delete/Void right */
    public static function canReset(string $pageKey): bool
    {
        return Access::can($pageKey, 'delete');
    }

    /** See the signed and original PDF copies: anyone who can open the voucher */
    public static function canView(string $pageKey): bool
    {
        return Access::page($pageKey);
    }

    // ------------------------------------------------------------------ the drawing

    /**
     * The signature drawn on the pad, checked: {"w":W,"h":H,"s":[[x,y,x,y,...],...]}, coordinates inside the pad,
     * enough ink to be a signature, not too much to store. Returns the cleaned drawing.
     */
    public static function parseStrokes(string $json): array
    {
        $d = json_decode($json, true);
        if (!is_array($d) || !isset($d['w'], $d['h'], $d['s']) || !is_array($d['s'])) {
            fail('Draw your signature on the pad first.');
        }
        $w = (float)$d['w'];
        $h = (float)$d['h'];
        if ($w < 50 || $w > 4000 || $h < 20 || $h > 2000) {
            fail('The signature pad sent an unexpected size. Clear the pad and sign again.');
        }
        if (count($d['s']) > self::MAX_STROKES) {
            fail('The signature has too many strokes. Clear the pad and sign again.');
        }
        $out = [];
        $points = 0;
        $length = 0.0;
        $minX = $minY = INF;
        $maxX = $maxY = -INF;
        foreach ($d['s'] as $s) {
            if (!is_array($s) || count($s) < 2 || count($s) % 2 !== 0) {
                continue;
            }
            $clean = [];
            for ($i = 0, $n = count($s); $i < $n; $i += 2) {
                if (!is_numeric($s[$i]) || !is_numeric($s[$i + 1])) {
                    fail('The signature could not be read. Clear the pad and sign again.');
                }
                $x = round(max(0, min($w, (float)$s[$i])), 1);
                $y = round(max(0, min($h, (float)$s[$i + 1])), 1);
                if ($clean) {
                    $length += hypot($x - $clean[count($clean) - 2], $y - $clean[count($clean) - 1]);
                }
                $clean[] = $x;
                $clean[] = $y;
                $minX = min($minX, $x);
                $maxX = max($maxX, $x);
                $minY = min($minY, $y);
                $maxY = max($maxY, $y);
            }
            $points += count($clean) / 2;
            $out[] = $clean;
        }
        if ($points > self::MAX_POINTS) {
            fail('The signature is too detailed to keep. Clear the pad and sign again.');
        }
        // a dot or a tiny tick is not a signature
        if (!$out || $length < $w * 0.12 || ($maxX - $minX) < $w * 0.06) {
            fail('Your signature is too short. Please sign on the pad as you would on paper.');
        }
        return ['w' => round($w), 'h' => round($h), 's' => $out];
    }

    /** The signature as an SVG picture (transparent, for the voucher page and the printed voucher) */
    public static function svg(string $strokesJson, string $class = 'sig-ink'): string
    {
        $d = json_decode($strokesJson, true);
        if (!is_array($d) || empty($d['s'])) {
            return '';
        }
        $minX = $minY = INF;
        $maxX = $maxY = -INF;
        foreach ($d['s'] as $s) {
            for ($i = 0, $n = count($s) - 1; $i < $n; $i += 2) {
                $minX = min($minX, (float)$s[$i]);
                $maxX = max($maxX, (float)$s[$i]);
                $minY = min($minY, (float)$s[$i + 1]);
                $maxY = max($maxY, (float)$s[$i + 1]);
            }
        }
        $pad = 6;
        $vb = sprintf('%.1F %.1F %.1F %.1F', $minX - $pad, $minY - $pad, max(1, $maxX - $minX + 2 * $pad), max(1, $maxY - $minY + 2 * $pad));
        $path = '';
        foreach ($d['s'] as $s) {
            $pts = [];
            for ($i = 0, $n = count($s) - 1; $i < $n; $i += 2) {
                $pts[] = [(float)$s[$i], (float)$s[$i + 1]];
            }
            if (!$pts) {
                continue;
            }
            $path .= sprintf('M%.1F %.1F', $pts[0][0], $pts[0][1]);
            $c = count($pts);
            if ($c === 1) {
                $path .= sprintf('l0.1 0');
                continue;
            }
            for ($i = 1; $i < $c - 1; $i++) {
                $path .= sprintf('Q%.1F %.1F %.1F %.1F', $pts[$i][0], $pts[$i][1], ($pts[$i][0] + $pts[$i + 1][0]) / 2, ($pts[$i][1] + $pts[$i + 1][1]) / 2);
            }
            $path .= sprintf('L%.1F %.1F', $pts[$c - 1][0], $pts[$c - 1][1]);
        }
        return '<svg class="' . h($class) . '" viewBox="' . $vb . '" preserveAspectRatio="xMidYMax meet" role="img" aria-label="Signature" xmlns="http://www.w3.org/2000/svg">'
            . '<path d="' . $path . '" fill="none" stroke="#172a6b" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/></svg>';
    }

    // ------------------------------------------------------------------ signing

    /**
     * Puts a signature on a line of the voucher and saves the new signed PDF. Used by both ways of signing.
     * $by: ['name' => .., 'user_id' => int|null, 'request' => request row|null]
     * $seenHash: the fingerprint of the voucher the signer reviewed (from the signing page)
     * Returns the signature id.
     */
    public static function sign(array $t, string $slot, array $by, array $drawing, string $seenHash): int
    {
        $txnId = (int)$t['id'];
        return DB::tx(function () use ($txnId, $slot, $by, $drawing, $seenHash) {
            // one signer at a time on a voucher
            DB::value('SELECT id FROM transactions WHERE id = :id FOR UPDATE', ['id' => $txnId]);
            $t = Txn::load($txnId);
            if (!$t || !self::supports((string)$t['txn_type'])) {
                fail('This voucher can no longer be signed.');
            }
            if ((int)$t['is_voided'] === 1) {
                fail('This voucher was voided and cannot be signed.');
            }
            $slots = self::slots($t);
            if (!isset($slots[$slot])) {
                fail('Choose the signature line to sign.');
            }
            $active = self::active($txnId);
            if (isset($active[$slot])) {
                fail('The ' . $slots[$slot] . ' line was already signed by ' . $active[$slot]['signer_name'] . ' on ' . fdatetime($active[$slot]['signed_at']) . '.');
            }
            $request = $by['request'] ?? null;
            if ($request) {
                $request = DB::row('SELECT * FROM voucher_sign_requests WHERE id = :id FOR UPDATE', ['id' => $request['id']]);
                if (!$request || (int)$request['transaction_id'] !== $txnId || $request['slot'] !== $slot) {
                    fail('This signature request is not valid.');
                }
                if ($request['status'] !== 'pending') {
                    fail('This signature request was already ' . ($request['status'] === 'signed' ? 'completed' : $request['status']) . '.');
                }
                if ($request['expires_at'] < date('Y-m-d H:i:s')) {
                    DB::update('voucher_sign_requests', ['status' => 'expired'], 'id = :id', ['id' => $request['id']]);
                    fail('This signature request has expired.');
                }
            } else {
                $userId = (int)($by['user_id'] ?? 0);
                foreach ($active as $a) {
                    if ($userId && (int)$a['signer_user_id'] === $userId) {
                        fail('You already signed this voucher (' . $slots[$a['slot']] . '). Each person signs one line.');
                    }
                }
                $p = self::pending($txnId);
                if (isset($p[$slot])) {
                    fail('A signature link for the ' . $slots[$slot] . ' line was sent to ' . $p[$slot]['signer_name'] . '. Revoke it first to sign that line yourself.');
                }
            }
            $model = VoucherPdf::model($t);
            $hash = VoucherPdf::hash($t, $model);
            if (!hash_equals($hash, $seenHash)) {
                fail('The voucher was changed while you were reviewing it. Please review it again and sign.');
            }
            // the original unsigned voucher, kept once
            if (!DB::value("SELECT id FROM voucher_documents WHERE transaction_id = :t AND kind = 'original' LIMIT 1", ['t' => $txnId])) {
                $now = date('Y-m-d H:i:s');
                self::storeDoc($t, 'original', 1, VoucherPdf::build($t, [], ['kind' => 'original', 'saved_at' => $now, 'model' => $model]), $hash, 0, $by['user_id'] ?? null,
                    'Kept before the first signature');
            }
            $sigId = DB::insert('voucher_signatures', [
                'transaction_id' => $txnId,
                'slot'           => $slot,
                'signer_name'    => mb_substr(trim((string)$by['name']), 0, 120),
                'signer_user_id' => $request ? null : ($by['user_id'] ?? null),
                'request_id'     => $request['id'] ?? null,
                'method'         => $request ? 'link' : 'internal',
                'strokes'        => json_encode($drawing),
                'doc_hash'       => $hash,
                'ip_address'     => client_ip(),
                'user_agent'     => mb_substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255),
                'signed_at'      => date('Y-m-d H:i:s'),
                'is_active'      => 1,
            ]);
            if ($request) {
                DB::update('voucher_sign_requests', ['status' => 'signed', 'signed_at' => date('Y-m-d H:i:s'), 'signature_id' => $sigId], 'id = :id', ['id' => $request['id']]);
            }
            $doc = self::saveSigned($t, $model, $hash, $by['user_id'] ?? null, $slots[$slot] . ' signed by ' . $by['name']);
            self::audit('sign', $t, $by['name'] . ' signed the ' . $slots[$slot] . ' line' . ($request ? ' through a signature link' : '') . '. Signed PDF version ' . $doc['version'] . ' saved.', $request ? $by['name'] : null);
            return $sigId;
        });
    }

    /** A new signed PDF copy with every signature now on the voucher */
    private static function saveSigned(array $t, array $model, string $hash, ?int $userId, string $note): array
    {
        $txnId = (int)$t['id'];
        $version = 1 + (int)DB::value("SELECT COALESCE(MAX(version), 0) FROM voucher_documents WHERE transaction_id = :t AND kind = 'signed'", ['t' => $txnId]);
        $sigs = self::active($txnId);
        $now = date('Y-m-d H:i:s');
        $pdf = VoucherPdf::build($t, $sigs, ['kind' => 'signed', 'version' => $version, 'saved_at' => $now, 'model' => $model, 'doc_hash' => $hash]);
        $id = self::storeDoc($t, 'signed', $version, $pdf, $hash, count($sigs), $userId, $note);
        return ['id' => $id, 'version' => $version];
    }

    // ------------------------------------------------------------------ links

    /**
     * Makes a signature link for one person and one line. Returns ['id' => .., 'link' => full address].
     */
    public static function request(array $t, string $slot, string $name, string $email, string $message, int $days): array
    {
        $txnId = (int)$t['id'];
        $name = trim(preg_replace('/\s+/u', ' ', $name));
        $email = trim($email);
        if ($name === '' || mb_strlen($name) < 2) {
            fail('Enter the name of the person who will sign.');
        }
        if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            fail('Enter a valid email address, or leave it empty.');
        }
        if (!isset(self::EXPIRY_DAYS[$days])) {
            $days = 7;
        }
        return DB::tx(function () use ($txnId, $slot, $name, $email, $message, $days) {
            DB::value('SELECT id FROM transactions WHERE id = :id FOR UPDATE', ['id' => $txnId]);
            $t = Txn::load($txnId);
            if (!$t || (int)$t['is_voided'] === 1) {
                fail('A voided voucher cannot be signed.');
            }
            $slots = self::slots($t);
            if (!isset($slots[$slot])) {
                fail('Choose the signature line the person will sign.');
            }
            if (isset(self::active($txnId)[$slot])) {
                fail('The ' . $slots[$slot] . ' line is already signed.');
            }
            if (isset(self::pending($txnId)[$slot])) {
                fail('A link for the ' . $slots[$slot] . ' line is already waiting. Copy that link, or revoke it to send a new one.');
            }
            $token = self::b64url(random_bytes(32));
            $id = DB::insert('voucher_sign_requests', [
                'transaction_id' => $txnId,
                'slot'           => $slot,
                'signer_name'    => mb_substr($name, 0, 120),
                'signer_email'   => $email !== '' ? mb_substr($email, 0, 160) : null,
                'message'        => trim($message) !== '' ? mb_substr(trim($message), 0, 255) : null,
                'token_hash'     => hash('sha256', $token),
                'token_enc'      => self::seal($token),
                'status'         => 'pending',
                'expires_at'     => date('Y-m-d H:i:s', time() + $days * 86400),
                'created_by'     => Auth::id(),
                'created_at'     => date('Y-m-d H:i:s'),
            ]);
            self::audit('sign_request', $t, 'Signature link for the ' . $slots[$slot] . ' line sent to ' . $name . ($email !== '' ? ' (' . $email . ')' : '') . ', valid ' . self::EXPIRY_DAYS[$days] . '.');
            return ['id' => $id, 'link' => self::linkFor($token)];
        });
    }

    /** The link of a waiting request, to copy again (null when it can no longer be read) */
    public static function link(array $request): ?string
    {
        if ($request['status'] !== 'pending' || empty($request['token_enc'])) {
            return null;
        }
        $token = self::unseal((string)$request['token_enc']);
        return $token !== null && hash_equals((string)$request['token_hash'], hash('sha256', $token)) ? self::linkFor($token) : null;
    }

    public static function revoke(array $t, int $requestId, string $reason): void
    {
        DB::tx(function () use ($t, $requestId, $reason) {
            $r = DB::row('SELECT * FROM voucher_sign_requests WHERE id = :id AND transaction_id = :t FOR UPDATE', ['id' => $requestId, 't' => $t['id']]);
            if (!$r) {
                fail('Signature request not found.');
            }
            if ($r['status'] !== 'pending') {
                fail('This link is already ' . ($r['status'] === 'signed' ? 'used' : $r['status']) . '.');
            }
            DB::update('voucher_sign_requests', ['status' => 'revoked', 'revoked_by' => Auth::id(), 'revoked_at' => date('Y-m-d H:i:s'),
                'revoke_reason' => trim($reason) !== '' ? mb_substr(trim($reason), 0, 255) : null, 'token_enc' => null], 'id = :id', ['id' => $requestId]);
            self::audit('sign_revoke', $t, 'Signature link for the ' . (self::SLOTS[$r['slot']] ?? $r['slot']) . ' line (' . $r['signer_name'] . ') revoked' . (trim($reason) !== '' ? ': ' . trim($reason) : '.'));
        });
    }

    /** Takes every signature off the voucher (kept on record) so it can be corrected; the voucher is unlocked */
    public static function reset(array $t, string $reason): int
    {
        if (trim($reason) === '') {
            fail('Enter the reason for resetting the signatures.');
        }
        return DB::tx(function () use ($t, $reason) {
            DB::value('SELECT id FROM transactions WHERE id = :id FOR UPDATE', ['id' => $t['id']]);
            $n = DB::run('UPDATE voucher_signatures SET is_active = NULL, cleared_by = :u, cleared_at = :at, clear_reason = :r WHERE transaction_id = :t AND is_active = 1',
                ['u' => Auth::id(), 'at' => date('Y-m-d H:i:s'), 'r' => mb_substr(trim($reason), 0, 255), 't' => $t['id']])->rowCount();
            if (!$n) {
                fail('This voucher has no signatures to reset.');
            }
            self::audit('sign_reset', $t, $n . ' signature(s) reset: ' . trim($reason));
            return $n;
        });
    }

    /**
     * The request of a link (by the secret in it), with its voucher. Null when the link is unknown.
     * Expired links are marked so.
     */
    public static function findByToken(string $token): ?array
    {
        if (!preg_match('/^[A-Za-z0-9_-]{40,64}$/', $token)) {
            return null;
        }
        $r = DB::row('SELECT * FROM voucher_sign_requests WHERE token_hash = :h', ['h' => hash('sha256', $token)]);
        if (!$r) {
            return null;
        }
        if ($r['status'] === 'pending' && $r['expires_at'] < date('Y-m-d H:i:s')) {
            DB::update('voucher_sign_requests', ['status' => 'expired'], 'id = :id', ['id' => $r['id']]);
            $r['status'] = 'expired';
        }
        return $r;
    }

    /** Counts a visit of the link (first and last time it was opened) */
    public static function opened(array $r): void
    {
        $now = date('Y-m-d H:i:s');
        DB::run('UPDATE voucher_sign_requests SET open_count = open_count + 1, last_opened_at = :n, first_opened_at = COALESCE(first_opened_at, :n2) WHERE id = :id',
            ['n' => $now, 'n2' => $now, 'id' => $r['id']]);
        if (!$r['first_opened_at']) {
            $t = Txn::load((int)$r['transaction_id']);
            if ($t) {
                self::audit('sign_link_open', $t, $r['signer_name'] . ' opened the signature link for the ' . (self::SLOTS[$r['slot']] ?? $r['slot']) . ' line.', $r['signer_name']);
            }
        }
    }

    // ------------------------------------------------------------------ PDF copies

    /** The PDF copies of a voucher, newest first */
    public static function docs(int $txnId): array
    {
        return DB::all('SELECT d.id, d.kind, d.version, d.file_name, d.file_size, d.signature_count, d.created_note, d.created_at, u.full_name AS created_by_name
                          FROM voucher_documents d LEFT JOIN users u ON u.id = d.created_by
                         WHERE d.transaction_id = :t ORDER BY d.kind = \'original\', d.version DESC, d.id DESC', ['t' => $txnId]);
    }

    /** The latest signed copy (or null) */
    public static function latestSigned(int $txnId): ?array
    {
        return DB::row("SELECT * FROM voucher_documents WHERE transaction_id = :t AND kind = 'signed' ORDER BY version DESC, id DESC LIMIT 1", ['t' => $txnId]) ?: null;
    }

    public static function doc(int $txnId, int $docId): ?array
    {
        return DB::row('SELECT * FROM voucher_documents WHERE id = :id AND transaction_id = :t', ['id' => $docId, 't' => $txnId]) ?: null;
    }

    /** The bytes of a stored PDF, checked against its fingerprint */
    public static function content(array $doc): string
    {
        $data = '';
        foreach (DB::column('SELECT data FROM voucher_document_chunks WHERE document_id = :d ORDER BY seq', ['d' => $doc['id']]) as $c) {
            $data .= $c;
        }
        if (!hash_equals((string)$doc['sha256'], hash('sha256', $data))) {
            fail('The stored PDF does not match its fingerprint. It may have been changed outside the program.');
        }
        return $data;
    }

    /** Sends a PDF: inline to preview, or as a file to download */
    public static function send(string $pdf, string $fileName, bool $download): never
    {
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        header('Content-Type: application/pdf');
        header('Content-Disposition: ' . ($download ? 'attachment' : 'inline') . '; filename="' . preg_replace('/[^A-Za-z0-9._-]+/', '_', $fileName) . '"');
        header('Content-Length: ' . strlen($pdf));
        header('Cache-Control: private, no-store');
        header('X-Content-Type-Options: nosniff');
        echo $pdf;
        exit;
    }

    /** The file name of a voucher PDF: CV-0001_signed_v2.pdf */
    public static function fileName(array $t, string $suffix): string
    {
        $ref = preg_replace('/[^A-Za-z0-9._-]+/', '_', (string)($t['txn_no'] ?: Txn::label($t['txn_type']) . '_' . $t['id']));
        return $ref . ($suffix !== '' ? '_' . $suffix : '') . '.pdf';
    }

    private static function storeDoc(array $t, string $kind, int $version, string $pdf, string $hash, int $sigCount, ?int $userId, string $note): int
    {
        $parts = str_split($pdf, self::CHUNK) ?: [''];
        $id = DB::insert('voucher_documents', [
            'transaction_id'  => $t['id'],
            'kind'            => $kind,
            'version'         => $version,
            'file_name'       => self::fileName($t, $kind === 'original' ? 'original' : 'signed_v' . $version),
            'file_size'       => strlen($pdf),
            'sha256'          => hash('sha256', $pdf),
            'doc_hash'        => $hash,
            'signature_count' => $sigCount,
            'chunks'          => count($parts),
            'created_by'      => $userId,
            'created_note'    => mb_substr($note, 0, 160),
            'created_at'      => date('Y-m-d H:i:s'),
        ]);
        foreach ($parts as $i => $part) {
            // as hexadecimal text: safe on every MySQL 5.5 connection, whatever its character set
            DB::run('INSERT INTO voucher_document_chunks (document_id, seq, data) VALUES (:d, :s, UNHEX(:x))', ['d' => $id, 's' => $i, 'x' => bin2hex($part)]);
        }
        return $id;
    }

    // ------------------------------------------------------------------ audit trail

    /** Signature activity in the audit trail; an outside signer is written as "Signer: name" */
    public static function audit(string $action, array $t, string $what, ?string $outsider = null): void
    {
        $opts = ['page_key' => Txn::page($t['txn_type']), 'reason' => $what, 'amount' => $t['total']];
        if ($outsider !== null) {
            // not a user of the system: written as is, whoever may be logged in in the same browser
            DB::insert('audit_trail', [
                'user_id' => null, 'username' => mb_substr('Signer: ' . $outsider, 0, 50), 'user_roles' => 'Signature link',
                'ip_address' => client_ip(), 'workstation' => substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 250),
                'module' => Txn::module($t['txn_type']), 'page_key' => $opts['page_key'], 'action' => $action,
                'record_type' => 'transaction', 'record_id' => $t['id'], 'record_ref' => mb_substr(Txn::ref($t), 0, 160),
                'amount' => r2($t['total']), 'reason' => mb_substr($what, 0, 255),
            ]);
            return;
        }
        Audit::log($action, Txn::module($t['txn_type']), 'transaction', $t['id'], Txn::ref($t), $opts);
    }

    /** The signature activity of a voucher, newest first */
    public static function activity(int $txnId, int $limit = 12): array
    {
        return DB::all("SELECT action, username, reason, ip_address, created_at FROM audit_trail
                         WHERE record_type = 'transaction' AND record_id = :t AND action IN ('sign', 'sign_request', 'sign_revoke', 'sign_reset', 'sign_link_open', 'sign_pdf')
                         ORDER BY id DESC LIMIT " . max(1, $limit), ['t' => $txnId]);
    }

    // ------------------------------------------------------------------ helpers

    /** The full address of a signature link */
    private static function linkFor(string $token): string
    {
        $q = Tenant::isMulti() && Tenant::id() ? 'c=' . Tenant::id() . '&t=' . $token : 't=' . $token;
        return self::publicBase() . '/sign.php?' . $q;
    }

    /** https://host/folder of the program (config app.public_url when set, else the address in use) */
    public static function publicBase(): string
    {
        $set = (string)($GLOBALS['CONFIG']['app']['public_url'] ?? '');
        if ($set !== '') {
            return rtrim($set, '/');
        }
        $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            || strtolower((string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
        $host = preg_replace('/[^A-Za-z0-9.:\[\]-]/', '', (string)($_SERVER['HTTP_HOST'] ?? 'localhost'));
        return ($https ? 'https' : 'http') . '://' . $host . base_url();
    }

    private static function b64url(string $bin): string
    {
        return rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');
    }

    /**
     * The key that keeps the links readable for copying again: a random key in the company's storage folder (not in
     * the database, so a copy of the database alone cannot rebuild the links). Without a writable folder, a key made
     * from the database settings of config.php.
     */
    private static function key(): string
    {
        static $keys = [];
        $id = (string)(Tenant::id() ?? 0);
        if (isset($keys[$id])) {
            return $keys[$id];
        }
        $dir = Tenant::storage('keys');
        Master::protectDir($dir);
        $file = $dir . '/signature_links.key';
        $key = is_file($file) ? (string)@file_get_contents($file) : '';
        if (strlen($key) !== 64) {
            $new = bin2hex(random_bytes(32));
            if (@file_put_contents($file, $new, LOCK_EX) !== false) {
                $key = $new;
            }
        }
        if (strlen($key) !== 64) {
            $db = $GLOBALS['CONFIG']['db'] ?? [];
            $key = hash('sha256', 'gsmart-sign|' . ($db['pass'] ?? '') . '|' . ($db['user'] ?? '') . '|' . DB::databaseName());
        }
        return $keys[$id] = hash('sha256', $key, true);
    }

    private static function seal(string $plain): ?string
    {
        if (!function_exists('openssl_encrypt')) {
            return null;
        }
        $iv = random_bytes(12);
        $tag = '';
        $c = openssl_encrypt($plain, 'aes-256-gcm', self::key(), OPENSSL_RAW_DATA, $iv, $tag);
        return $c === false ? null : base64_encode($iv . $tag . $c);
    }

    private static function unseal(string $sealed): ?string
    {
        $b = base64_decode($sealed, true);
        if ($b === false || strlen($b) < 29 || !function_exists('openssl_decrypt')) {
            return null;
        }
        $p = openssl_decrypt(substr($b, 28), 'aes-256-gcm', self::key(), OPENSSL_RAW_DATA, substr($b, 0, 12), substr($b, 12, 16));
        return $p === false ? null : $p;
    }
}
