<?php
declare(strict_types=1);

/**
 * v42: the PDF of a voucher that can be signed (Check Voucher of Write Checks, Cash Voucher, Journal Entry), with the
 * signatures drawn on its signature lines.
 *
 * The content is the same as the printed voucher (modules/txn/_common.php: check_voucher_print_body and
 * journal_print_body): company, title, number and date, payee and amount in words, the ledger lines with their
 * totals, then Prepared by / Checked by / Approved by (/ Received by). Because the PDF is drawn
 * here, each signature is placed exactly in the space above its line, whatever the number of ledger lines.
 *
 * One builder serves both ways of signing (in the system and through a link), the original unsigned copy and every
 * signed copy, so they always look the same.
 */
final class VoucherPdf
{
    private const MARGIN = 42.0;
    private const INK = [0.09, 0.16, 0.42];
    private const ACCENT = [0.12, 0.23, 0.40];

    /** The content of the voucher as printed (no signatures) */
    public static function model(array $t): array
    {
        require_once APP_ROOT . '/modules/txn/_common.php';
        $type = $t['txn_type'];
        $s = Settings::all();
        $m = [
            'company' => ['name' => (string)$s['company_name'], 'address' => (string)$s['company_address'],
                'tin' => (string)$s['company_tin'], 'phone' => (string)($s['company_phone'] ?? '')],
            'title'  => is_journal_style($type) ? strtoupper(Txn::label($type)) : voucher_title($t),
            'no'     => (string)$t['txn_no'],
            'date'   => fdate($t['txn_date']),
            'void'   => (int)$t['is_voided'] === 1,
            'left'   => [],
            'right'  => [],
            'cols'   => [],
            'rows'   => [],
            'totals' => [0.0, 0.0],
            'slots'  => Signatures::slots($t),
            'names'  => [],
        ];
        $payee = entity_name($t);
        $amount = fn() => ['Amount', money($t['total']) . ' (' . amount_in_words((float)$t['total']) . ')', true];
        $site = print_site_name($t);
        $class = !empty($t['class_id']) && Classes::ready() ? (string)Classes::name($t['class_id']) : '';

        if (is_journal_style($type)) {
            $isVoucher = $type === Posting::CASH_VOUCHER;
            if ($isVoucher) {
                $m['left'][] = ['Paid to', $payee, true];
                $m['left'][] = ['Cash account', account_label((int)$t['account_id']), false];
                $m['left'][] = $amount();
            } elseif ($payee !== '') {
                $m['left'][] = ['Name', $payee, true];
            }
            if ($t['memo']) {
                $m['left'][] = [$isVoucher ? 'Particulars' : 'Memo', (string)$t['memo'], false];
            }
            $rows = [];
            foreach (Txn::lines((int)$t['id']) as $l) {
                $rows[] = [trim($l['account_code'] . ' - ' . $l['account_name'], ' -'), (string)$l['description'], line_name($l), (string)($l['class_name'] ?? ''), (float)$l['amount']];
            }
            if ($isVoucher && $t['account_id']) {
                $rows[] = [account_label((int)$t['account_id']), (string)($t['memo'] ?: 'Cash paid out'), $payee, '', -(float)$t['total']];
            }
            $showClass = Classes::ready();
            $m['cols'] = $showClass
                ? [['Account', 3.2, 'L'], ['Description', 2.8, 'L'], ['Name', 2.0, 'L'], ['Class', 1.3, 'L'], ['Debit', 1.45, 'R'], ['Credit', 1.45, 'R']]
                : [['Account', 3.6, 'L'], ['Description', 3.2, 'L'], ['Name', 2.3, 'L'], ['Debit', 1.5, 'R'], ['Credit', 1.5, 'R']];
            foreach ($rows as $r) {
                $amt = $r[4];
                $m['totals'][0] += max(0, $amt);
                $m['totals'][1] += max(0, -$amt);
                $cells = [$r[0], $r[1], $r[2]];
                if ($showClass) {
                    $cells[] = $r[3] !== '' ? $r[3] : $class;
                }
                $cells[] = $amt > 0 ? money($amt) : '';
                $cells[] = $amt < 0 ? money(-$amt) : '';
                $m['rows'][] = $cells;
            }
        } else {
            // the check voucher (Write Checks)
            $party = $t['vendor_id'] ? DB::row('SELECT address, tin FROM vendors WHERE id = :id', ['id' => $t['vendor_id']])
                : ($t['customer_id'] ? DB::row('SELECT billing_address AS address, tin FROM customers WHERE id = :id', ['id' => $t['customer_id']]) : null);
            $m['left'][] = ['Pay to', $payee, true];
            if ($party && trim((string)$party['address']) !== '') {
                $m['left'][] = ['', trim((string)$party['address']), false];
            }
            if ($party && $party['tin']) {
                $m['left'][] = ['TIN', (string)$party['tin'], false];
            }
            $m['left'][] = $amount();
            if ($t['account_id']) {
                $m['right'][] = ['Paid from', account_label((int)$t['account_id'])];
            }
            if ($t['memo']) {
                $m['left'][] = ['Memo', (string)$t['memo'], false];
            }
            $useClass = Classes::ready();
            $gl = DB::all('SELECT j.debit, j.credit, j.memo, a.code, a.name' . ($useClass ? ', c.name AS class_name' : ", '' AS class_name") . '
                             FROM journal_lines j JOIN accounts a ON a.id = j.account_id' . ($useClass ? ' LEFT JOIN classes c ON c.id = j.class_id' : '') . '
                            WHERE j.txn_id = :id ORDER BY j.credit > 0, j.id', ['id' => $t['id']]);
            $m['cols'] = $useClass
                ? [['Account', 3.6, 'L'], ['Memo', 3.4, 'L'], ['Class', 1.5, 'L'], ['Debit', 1.5, 'R'], ['Credit', 1.5, 'R']]
                : [['Account', 4.2, 'L'], ['Memo', 4.0, 'L'], ['Debit', 1.6, 'R'], ['Credit', 1.6, 'R']];
            foreach ($gl as $g) {
                $m['totals'][0] += (float)$g['debit'];
                $m['totals'][1] += (float)$g['credit'];
                $cells = [$g['code'] . ' - ' . $g['name'], (string)$g['memo']];
                if ($useClass) {
                    $cells[] = (string)$g['class_name'];
                }
                $cells[] = (float)$g['debit'] != 0.0 ? money($g['debit']) : '';
                $cells[] = (float)$g['credit'] != 0.0 ? money($g['credit']) : '';
                $m['rows'][] = $cells;
            }
        }
        if ($t['ref_no']) {
            $m['right'][] = ['Reference', (string)$t['ref_no']];
        }
        if ($site !== '') {
            $m['right'][] = ['Location / site', $site];
        }
        if ($class !== '') {
            $m['right'][] = ['Class', $class];
        }
        $m['totals'] = [money($m['totals'][0]), money($m['totals'][1])];
        // the names printed on the lines before anyone signs (as on the printed voucher)
        $name = fn($id) => $id ? (string)DB::value('SELECT full_name FROM users WHERE id = :id', ['id' => $id]) : '';
        $m['names'] = ['prepared' => $name($t['created_by'] ?? null), 'approved' => $name($t['approved_by'] ?? null)];
        return $m;
    }

    /**
     * The fingerprint of what a signer sees and signs: everything on the voucher except the company letterhead and
     * the names printed under the lines. Any change to the voucher (amount, payee, account, line, date, number)
     * changes it.
     */
    public static function hash(array $t, ?array $model = null): string
    {
        $m = $model ?? self::model($t);
        unset($m['company'], $m['names'], $m['slots']);
        return hash('sha256', json_encode([(int)$t['id'], $t['txn_type'], $m], JSON_UNESCAPED_UNICODE));
    }

    /**
     * The PDF file.
     * $sigs: slot => signature row (with 'strokes' JSON) drawn on its line; empty for the unsigned voucher.
     * $opt: 'kind' => 'original' | 'signed' | 'preview', 'version' => n, 'saved_at' => 'Y-m-d H:i:s', 'model' => model
     */
    public static function build(array $t, array $sigs = [], array $opt = []): string
    {
        $m = $opt['model'] ?? self::model($t);
        $kind = $opt['kind'] ?? 'preview';
        $pdf = new SimplePdf(612, 792, $m['title'] . ' ' . $m['no']);
        $L = self::MARGIN;
        $R = 612 - self::MARGIN;
        $W = $R - $L;
        $bottom = 792 - 52;

        // ---- letterhead and title
        $y = 54.0;
        $pdf->textRgb($L, $y, $pdf->fit($m['company']['name'], 300, 13.5, true), 13.5, true, 'L', self::ACCENT);
        $ly = $y + 13;
        foreach ($pdf->wrap($m['company']['address'], 300, 8) as $ln) {
            $pdf->text($L, $ly, $ln, 8, false, 'L', 0.25);
            $ly += 10;
        }
        $tin = 'TIN ' . $m['company']['tin'] . ($m['company']['phone'] !== '' ? ', ' . $m['company']['phone'] : '');
        $pdf->text($L, $ly, $pdf->fit($tin, 300, 8), 8, false, 'L', 0.25);
        $ly += 10;

        $pdf->textRgb($R, $y, $m['title'], 15, true, 'R', self::ACCENT);
        $ry = $y + 15;
        $pdf->text($R - $pdf->textWidth($m['no'], 9.5, true), $ry, 'No. ', 9.5, false, 'R');
        $pdf->text($R, $ry, $m['no'], 9.5, true, 'R');
        $ry += 12;
        $pdf->text($R, $ry, 'Date: ' . $m['date'], 9.5, false, 'R');
        $ry += 12;
        if ($m['void']) {
            $pdf->textRgb($R, $ry, 'VOID', 11, true, 'R', [0.75, 0.1, 0.1]);
            $ry += 12;
        }
        $y = max($ly, $ry) + 4;
        $pdf->fillRgb($L, $y, $W, 1.6, self::ACCENT);
        $y += 16;

        // ---- payee, amount, accounts
        $leftW = $W * 0.6;
        $rightW = $W * 0.38;
        $yl = $y;
        foreach ($m['left'] as [$label, $value, $bold]) {
            $x = $L;
            if ($label !== '') {
                $pdf->text($x, $yl, $label . ':', 8.5, false, 'L', 0.3);
                $x += $pdf->textWidth($label . ': ', 8.5);
            }
            foreach ($pdf->wrap($value, $L + $leftW - $x, 8.5, $bold) as $i => $ln) {
                $pdf->text($x, $yl, $ln, 8.5, $bold);
                $yl += 11;
            }
        }
        $yr = $y;
        foreach ($m['right'] as [$label, $value]) {
            foreach ($pdf->wrap($label . ': ' . $value, $rightW, 8.5) as $ln) {
                $pdf->text($R, $yr, $ln, 8.5, false, 'R');
                $yr += 11;
            }
        }
        $y = max($yl, $yr) + 8;

        // ---- tables
        $empty = $m['rows'] ? null : 'No ledger entries (' . ($m['void'] ? 'voided' : 'not posted') . ').';
        $y = self::table($pdf, $m['cols'], $m['rows'], $m['totals'], $y, $bottom, $m, $empty);

        // ---- signature lines
        $slots = $m['slots'];
        $y += 26;
        $y = self::room($pdf, $y, 92, $bottom, $m);
        $gap = 18.0;
        $n = max(1, count($slots));
        $cw = ($W - $gap * ($n - 1)) / $n;
        $i = 0;
        foreach ($slots as $slot => $label) {
            $x = $L + $i * ($cw + $gap);
            $pdf->text($x, $y, $label . ':', 8, false, 'L', 0.35);
            $sig = $sigs[$slot] ?? null;
            if ($sig) {
                $d = json_decode((string)$sig['strokes'], true) ?: [];
                $pdf->strokes($d['s'] ?? [], (float)($d['w'] ?? 600), (float)($d['h'] ?? 200), $x + 4, $y + 4, $cw - 8, 44, 1.15, self::INK);
            }
            $pdf->line($x, $y + 52, $x + $cw, $y + 52, 0.7, 0.15);
            $name = $sig ? (string)$sig['signer_name'] : (string)($m['names'][$slot] ?? '');
            if ($name !== '') {
                $pdf->text($x + $cw / 2, $y + 63, $pdf->fit($name, $cw, 8.5, true), 8.5, true, 'C');
            }
            if ($sig) {
                $when = 'Signed ' . date('d M Y g:i A', strtotime((string)$sig['signed_at']));
                $pdf->text($x + $cw / 2, $y + 73, $pdf->fit($when, $cw, 6.8), 6.8, false, 'C', 0.4);
            }
            $i++;
        }
        $y += 84;

        // ---- signature record (signed copies)
        if ($kind === 'signed' && $sigs) {
            $y += 14;
            $y = self::room($pdf, $y, 60, $bottom, $m);
            $pdf->textRgb($L, $y, 'Signature record', 10, true, 'L', self::ACCENT);
            $y += 8;
            $rows = [];
            foreach ($slots as $slot => $label) {
                if ($s = $sigs[$slot] ?? null) {
                    $rows[] = [$label, (string)$s['signer_name'], $s['method'] === 'link' ? 'Signature request link' : 'Signed in the system',
                        date('d M Y g:i:s A', strtotime((string)$s['signed_at'])), (string)($s['ip_address'] ?? '')];
                }
            }
            $y = self::table($pdf, [['Line', 1.5, 'L'], ['Signer', 2.4, 'L'], ['Method', 2.3, 'L'], ['Date and time', 2.2, 'L'], ['IP address', 1.6, 'L']], $rows, null, $y, $bottom, $m);
            $y += 4;
            $hash = $opt['doc_hash'] ?? self::hash($t, $m);
            foreach ($pdf->wrap('Content fingerprint (SHA-256) of the voucher as signed: ' . $hash, $W, 7.5) as $ln) {
                $y = self::room($pdf, $y, 10, $bottom, $m);
                $pdf->text($L, $y + 8, $ln, 7.5, false, 'L', 0.35);
                $y += 10;
            }
        }

        // ---- footer on every page
        $saved = isset($opt['saved_at']) ? date('d M Y g:i A', strtotime((string)$opt['saved_at'])) : date('d M Y g:i A');
        $note = match ($kind) {
            'signed'   => 'Electronically signed copy, version ' . (int)($opt['version'] ?? 1) . ', saved ' . $saved . '. ' . count($sigs) . ' of ' . count($slots) . ' lines signed.',
            'original' => 'Original unsigned copy, kept ' . $saved . '.',
            default    => 'Voucher copy for review, printed ' . $saved . '.',
        };
        $ref = $m['title'] . ' ' . $m['no'];
        $pdf->forEachPage(function (int $p, int $total) use ($pdf, $L, $R, $note, $ref) {
            $pdf->line($L, 792 - 34, $R, 792 - 34, 0.4, 0.7);
            $pdf->text($L, 792 - 24, $pdf->fit($ref . '. ' . $note, 430, 7), 7, false, 'L', 0.45);
            $pdf->text($R, 792 - 24, 'Page ' . $p . ' of ' . $total, 7, false, 'R', 0.45);
        });
        return $pdf->output();
    }

    /** A new page when $need points do not fit below $y; returns where to write */
    private static function room(SimplePdf $pdf, float $y, float $need, float $bottom, array $m): float
    {
        if ($y + $need <= $bottom) {
            return $y;
        }
        $pdf->addPage();
        $pdf->textRgb(self::MARGIN, 50, $m['title'] . ' ' . $m['no'] . ' (continued)', 10, true, 'L', self::ACCENT);
        return 72.0;
    }

    /** A table with a shaded heading; long texts wrap (up to 3 lines); the heading repeats on a new page */
    private static function table(SimplePdf $pdf, array $cols, array $rows, ?array $totals, float $y, float $bottom, array $m, ?string $empty = null): float
    {
        $L = self::MARGIN;
        $W = 612 - 2 * self::MARGIN;
        $sum = array_sum(array_column($cols, 1));
        $xs = [];
        $ws = [];
        $x = $L;
        foreach ($cols as $c) {
            $w = $W * $c[1] / $sum;
            $xs[] = $x;
            $ws[] = $w;
            $x += $w;
        }
        $pad = 4.0;
        $head = function (float $y) use ($pdf, $cols, $xs, $ws, $L, $W, $pad): float {
            $pdf->fill($L, $y, $W, 15, 0.92);
            foreach ($cols as $i => $c) {
                $pdf->text($c[2] === 'R' ? $xs[$i] + $ws[$i] - $pad : $xs[$i] + $pad, $y + 10.5, $c[0], 8, true, $c[2], 0.15);
            }
            return $y + 15;
        };
        $y = self::room($pdf, $y, 34, $bottom, $m);
        $y = $head($y);
        if (!$rows && $empty !== null) {
            $pdf->text($L + $pad, $y + 11, $empty, 8.5, false, 'L', 0.45);
            $y += 15;
        }
        foreach ($rows as $r) {
            $cells = [];
            $lines = 1;
            foreach ($cols as $i => $c) {
                $txt = (string)($r[$i] ?? '');
                $cells[$i] = $c[2] === 'R' ? [$pdf->fit($txt, $ws[$i] - 2 * $pad, 8.5)] : array_slice($pdf->wrap($txt, $ws[$i] - 2 * $pad, 8.5), 0, 3);
                $lines = max($lines, count($cells[$i]));
            }
            $h = 6 + $lines * 10.5;
            if ($y + $h > $bottom) {
                $y = $head(self::room($pdf, $y, $bottom, $bottom, $m));
            }
            foreach ($cols as $i => $c) {
                foreach ($cells[$i] as $k => $ln) {
                    $pdf->text($c[2] === 'R' ? $xs[$i] + $ws[$i] - $pad : $xs[$i] + $pad, $y + 11 + $k * 10.5, $ln, 8.5, false, $c[2]);
                }
            }
            $y += $h;
            $pdf->line($L, $y, $L + $W, $y, 0.3, 0.8);
        }
        if ($totals !== null) {
            $n = count($cols);
            $pdf->line($L, $y, $L + $W, $y, 0.9, 0.2);
            $pdf->text($xs[$n - 2] - $pad, $y + 12, 'Total', 8.5, true, 'R');
            $pdf->text($xs[$n - 2] + $ws[$n - 2] - $pad, $y + 12, $totals[0], 8.5, true, 'R');
            $pdf->text($xs[$n - 1] + $ws[$n - 1] - $pad, $y + 12, $totals[1], 8.5, true, 'R');
            $y += 17;
            $pdf->line($L, $y, $L + $W, $y, 0.9, 0.2);
            $pdf->line($L, $y + 2, $L + $W, $y + 2, 0.5, 0.2);
            $y += 2;
        }
        return $y;
    }
}
