<?php
declare(strict_types=1);

/**
 * v41: Community > Questions & Inquiries: a question with its category and status (Open, Answered, Resolved), the
 * responses of other users and of the moderators (an official response carries the label "Official"), comments on a
 * response, and the accepted answer chosen by the author or a moderator. See Community for the rights.
 */
final class Inquiries
{
    public const MAX_BODY = 10000;

    public static function find(int $id): ?array
    {
        return DB::row('SELECT * FROM community_inquiries WHERE id = :id', ['id' => $id]);
    }

    public static function canSee(array $q): bool
    {
        if (!Access::page('comm.inquiries') || Community::suspended()) {
            return false;
        }
        return (int)$q['is_hidden'] === 0 || Community::isMod() || (int)$q['user_id'] === Community::me();
    }

    /** The author or a moderator */
    public static function canManage(array $q): bool
    {
        return (int)$q['user_id'] === Community::me() || Community::canModerate();
    }

    public static function categories(bool $activeOnly = true): array
    {
        return DB::all('SELECT * FROM community_inquiry_categories' . ($activeOnly ? ' WHERE is_active = 1' : '') . ' ORDER BY sort_order, name');
    }

    /** A page of inquiries: [rows, total] */
    public static function search(array $f, int $page = 1, int $per = 20): array
    {
        $w = ['1 = 1'];
        $p = [];
        if (!Community::isMod()) {
            $w[] = '(q.is_hidden = 0 OR q.user_id = :me)';
            $p['me'] = Community::me();
        }
        if (!empty($f['status']) && isset(Community::STATUSES[$f['status']])) {
            $w[] = 'q.status = :st';
            $p['st'] = $f['status'];
        }
        if (!empty($f['category'])) {
            $w[] = 'q.category_id = :cat';
            $p['cat'] = (int)$f['category'];
        }
        if (!empty($f['mine'])) {
            $w[] = 'q.user_id = :mine';
            $p['mine'] = Community::me();
        }
        if (!empty($f['unanswered'])) {
            $w[] = 'q.response_count = 0';
        }
        if (trim((string)($f['q'] ?? '')) !== '') {
            $like = '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim((string)$f['q'])) . '%';
            $w[] = '(q.title LIKE :q1 OR q.body LIKE :q2 OR EXISTS (SELECT 1 FROM community_inquiry_responses r WHERE r.inquiry_id = q.id AND r.deleted_at IS NULL AND r.is_hidden = 0 AND r.body LIKE :q3))';
            $p += ['q1' => $like, 'q2' => $like, 'q3' => $like];
        }
        $where = implode(' AND ', $w);
        $total = (int)DB::value("SELECT COUNT(*) FROM community_inquiries q WHERE $where", $p);
        $order = match ($f['sort'] ?? '') {
            'new' => 'q.created_at DESC',
            'unanswered' => 'q.response_count, q.created_at DESC',
            default => 'q.last_activity_at DESC',
        };
        $rows = DB::all("SELECT q.*, c.name AS category_name FROM community_inquiries q LEFT JOIN community_inquiry_categories c ON c.id = q.category_id
                          WHERE $where ORDER BY $order, q.id DESC LIMIT " . max(1, $per) . ' OFFSET ' . max(0, ($page - 1) * $per), $p);
        return [$rows, $total];
    }

    /** Questions like a title being typed (to find an answer before asking) */
    public static function similar(string $text, int $limit = 5): array
    {
        $words = array_values(array_filter(preg_split('/[^\p{L}\p{N}]+/u', mb_strtolower($text)) ?: [], fn($w) => mb_strlen($w) >= 4));
        if (!$words) {
            return [];
        }
        $words = array_slice(array_unique($words), 0, 6);
        $score = [];
        $p = [];
        foreach ($words as $i => $w) {
            $score[] = "(q.title LIKE :w$i)";
            $p["w$i"] = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $w) . '%';
        }
        $s = implode(' + ', $score);
        return DB::all("SELECT q.id, q.title, q.status, q.response_count FROM community_inquiries q WHERE q.is_hidden = 0 AND ($s) > 0
                         ORDER BY ($s) DESC, q.status = 'resolved' DESC, q.last_activity_at DESC LIMIT " . (int)$limit, $p);
    }

    public static function ask(int $category, string $title, string $body, ?string $key, array $fileIds): int
    {
        Community::requirePost('comm.inquiries');
        $me = Community::me();
        if ($key && ($old = DB::value('SELECT id FROM community_inquiries WHERE user_id = :u AND client_key = :k', ['u' => $me, 'k' => $key]))) {
            return (int)$old;
        }
        $title = trim(preg_replace('/\s+/u', ' ', $title) ?? '');
        if (mb_strlen($title) < 5) {
            fail('Give the inquiry a title of at least 5 characters.');
        }
        if (mb_strlen($title) > 200) {
            fail('The title is too long (at most 200 characters).');
        }
        $body = Community::clean($body, self::MAX_BODY);
        if (mb_strlen($body) < 10) {
            fail('Describe the question in a few more words (at least 10 characters).');
        }
        if (!DB::value('SELECT 1 FROM community_inquiry_categories WHERE id = :c AND is_active = 1', ['c' => $category])) {
            fail('Choose a category.');
        }
        if ((int)DB::value('SELECT COUNT(*) FROM community_inquiries WHERE user_id = :u AND created_at >= :t', ['u' => $me, 't' => date('Y-m-d H:i:s', time() - 3600)]) >= 5) {
            fail('You have asked 5 questions in the last hour. Wait a little before asking another.');
        }
        $fileIds = Community::ownPending($fileIds);
        $now = Community::now();
        return DB::tx(function () use ($category, $title, $body, $key, $now, $me, $fileIds) {
            $id = (int)DB::insert('community_inquiries', ['category_id' => $category, 'user_id' => $me, 'title' => $title, 'body' => $body, 'client_key' => $key,
                'last_activity_at' => $now, 'created_at' => $now]);
            Community::claimFiles($fileIds, 'inquiry', $id);
            return $id;
        });
    }

    public static function edit(array $q, int $category, string $title, string $body): void
    {
        if ((int)$q['user_id'] !== Community::me() || !Access::can('comm.inquiries', 'edit') || Community::muted()) {
            fail('You can edit only your own inquiries.');
        }
        $title = trim(preg_replace('/\s+/u', ' ', $title) ?? '');
        $body = Community::clean($body, self::MAX_BODY);
        if (mb_strlen($title) < 5 || mb_strlen($title) > 200 || mb_strlen($body) < 10) {
            fail('The title needs 5 to 200 characters and the question at least 10.');
        }
        if (!DB::value('SELECT 1 FROM community_inquiry_categories WHERE id = :c', ['c' => $category])) {
            fail('Choose a category.');
        }
        DB::update('community_inquiries', ['category_id' => $category, 'title' => $title, 'body' => $body, 'edited_at' => Community::now()], 'id = :id', ['id' => (int)$q['id']]);
    }

    public static function delete(array $q, string $reason = ''): void
    {
        $own = (int)$q['user_id'] === Community::me();
        if ($own && Access::can('comm.inquiries', 'delete') && (int)$q['response_count'] === 0) {
            // the author's own question with no responses yet
        } elseif (Community::canSanction()) {
            Community::log('delete_inquiry', 'inquiry', (int)$q['id'], (int)$q['user_id'], $reason ?: 'Removed by a moderator', $q['title'] . "\n" . $q['body']);
        } else {
            fail($own ? 'An inquiry that has responses cannot be deleted; mark it as resolved instead.' : 'You may delete only your own inquiries.');
        }
        DB::tx(function () use ($q) {
            $rids = DB::column('SELECT id FROM community_inquiry_responses WHERE inquiry_id = :i', ['i' => (int)$q['id']]);
            if ($rids) {
                [$in, $p] = DB::in('r', $rids);
                DB::run("DELETE FROM community_files WHERE owner_type = 'response' AND owner_id IN $in", $p);
            }
            DB::run("DELETE FROM community_files WHERE owner_type = 'inquiry' AND owner_id = :i", ['i' => (int)$q['id']]);
            DB::run('DELETE FROM community_inquiries WHERE id = :i', ['i' => (int)$q['id']]);
        });
    }

    /** Responses (and their comments) in order: [response + 'comments' => [...]] */
    public static function responses(array $q): array
    {
        $mod = Community::isMod();
        $me = Community::me();
        $rows = DB::all('SELECT * FROM community_inquiry_responses WHERE inquiry_id = :i ORDER BY id', ['i' => (int)$q['id']]);
        $files = Community::files('response', array_column($rows, 'id'));
        $users = Community::users(array_column($rows, 'user_id'));
        $top = [];
        $comments = [];
        foreach ($rows as $r) {
            $r['user'] = $users[(int)$r['user_id']];
            $r['files'] = $files[(int)$r['id']] ?? [];
            $r['visible'] = !$r['deleted_at'] && ((int)$r['is_hidden'] === 0 || $mod || (int)$r['user_id'] === $me);
            if ($r['parent_id']) {
                $comments[(int)$r['parent_id']][] = $r;
            } else {
                $top[] = $r;
            }
        }
        foreach ($top as &$t) {
            $t['comments'] = $comments[(int)$t['id']] ?? [];
        }
        unset($t);
        // the accepted answer first, then the official ones, then the others in order
        $acc = (int)$q['accepted_response_id'];
        usort($top, fn($a, $b) => [(int)$a['id'] !== $acc, (int)$a['is_official'] === 0, (int)$a['id']] <=> [(int)$b['id'] !== $acc, (int)$b['is_official'] === 0, (int)$b['id']]);
        return $top;
    }

    public static function respond(array $q, string $body, ?int $parent, bool $official, ?string $key, array $fileIds): int
    {
        Community::requirePost('comm.inquiries');
        if (!self::canSee($q) || (int)$q['is_hidden'] === 1) {
            fail('This inquiry is not open for responses.');
        }
        $me = Community::me();
        if ($key && ($old = DB::value('SELECT id FROM community_inquiry_responses WHERE user_id = :u AND client_key = :k', ['u' => $me, 'k' => $key]))) {
            return (int)$old;
        }
        $body = Community::clean($body, self::MAX_BODY);
        if ($body === '') {
            fail('Type your response.');
        }
        if ($parent) {
            $pr = DB::row('SELECT * FROM community_inquiry_responses WHERE id = :p AND inquiry_id = :i AND parent_id IS NULL AND deleted_at IS NULL', ['p' => $parent, 'i' => (int)$q['id']]);
            if (!$pr) {
                fail('The response you comment on was not found.');
            }
        }
        if ((int)DB::value('SELECT COUNT(*) FROM community_inquiry_responses WHERE user_id = :u AND created_at >= :t', ['u' => $me, 't' => date('Y-m-d H:i:s', time() - 600)]) >= 20) {
            fail('You are posting responses very quickly. Wait a few minutes.');
        }
        $official = $official && Community::canModerate() && !$parent;
        $fileIds = $parent ? [] : Community::ownPending($fileIds);
        $now = Community::now();
        $id = DB::tx(function () use ($q, $me, $parent, $body, $official, $key, $now, $fileIds) {
            $id = (int)DB::insert('community_inquiry_responses', ['inquiry_id' => (int)$q['id'], 'user_id' => $me, 'parent_id' => $parent, 'body' => $body,
                'is_official' => $official ? 1 : 0, 'client_key' => $key, 'created_at' => $now]);
            Community::claimFiles($fileIds, 'response', $id);
            DB::run('UPDATE community_inquiries SET response_count = (SELECT COUNT(*) FROM community_inquiry_responses r WHERE r.inquiry_id = :i AND r.parent_id IS NULL AND r.deleted_at IS NULL),
                     last_activity_at = :n WHERE id = :i2', ['i' => (int)$q['id'], 'i2' => (int)$q['id'], 'n' => $now]);
            return $id;
        });
        $link = url('comm.inquiries', ['id' => (int)$q['id']]) . '#r' . $id;
        $name = Community::user($me)['name'];
        $author = (int)$q['user_id'];
        $done = [$me];
        if ($author !== $me && (int)Community::settings($author)['notify_inquiries'] === 1) {
            if ($official) {
                Community::notify($author, 'official', 'Official response to your inquiry "' . Community::excerpt($q['title'], 60) . '"', $link, 'inqoff:' . $id, $me);
            } else {
                Community::notify($author, 'response', $name . ($parent ? ' commented on' : ' responded to') . ' your inquiry "' . Community::excerpt($q['title'], 60) . '"', $link, 'inqresp:' . (int)$q['id'], $me);
            }
            $done[] = $author;
        }
        if ($parent && ($pu = (int)DB::value('SELECT user_id FROM community_inquiry_responses WHERE id = :p', ['p' => $parent])) && !in_array($pu, $done, true)) {
            Community::notify($pu, 'reply', $name . ' commented on your response to "' . Community::excerpt($q['title'], 60) . '"', $link, 'inqcom:' . $id, $me);
            $done[] = $pu;
        }
        foreach (Community::mentionedIds($body) as $m) {
            if (!in_array($m, $done, true) && Access::page('comm.inquiries', $m) && (int)Community::settings($m)['notify_mentions'] === 1) {
                Community::notify($m, 'mention', $name . ' mentioned you in "' . Community::excerpt($q['title'], 60) . '"', $link, 'inqmen:' . $id, $me);
            }
        }
        return $id;
    }

    public static function response(int $id): ?array
    {
        return DB::row('SELECT * FROM community_inquiry_responses WHERE id = :id', ['id' => $id]);
    }

    public static function editResponse(array $r, string $body): void
    {
        if ((int)$r['user_id'] !== Community::me() || $r['deleted_at'] || !Access::can('comm.inquiries', 'edit') || Community::muted()) {
            fail('You can edit only your own responses.');
        }
        $body = Community::clean($body, self::MAX_BODY);
        if ($body === '') {
            fail('A response cannot be empty. Delete it instead.');
        }
        DB::update('community_inquiry_responses', ['body' => $body, 'edited_at' => Community::now()], 'id = :id', ['id' => (int)$r['id']]);
    }

    public static function deleteResponse(array $r, string $reason = ''): void
    {
        $own = (int)$r['user_id'] === Community::me();
        if (!($own && Access::can('comm.inquiries', 'delete')) && !Community::canSanction()) {
            fail('You may delete only your own responses.');
        }
        if (!$own) {
            Community::log('delete_response', 'response', (int)$r['id'], (int)$r['user_id'], $reason ?: 'Removed by a moderator', (string)$r['body']);
        }
        DB::tx(function () use ($r) {
            DB::update('community_inquiry_responses', ['body' => '', 'deleted_at' => Community::now()], 'id = :id', ['id' => (int)$r['id']]);
            DB::run("DELETE FROM community_files WHERE owner_type = 'response' AND owner_id = :id", ['id' => (int)$r['id']]);
            $q = self::find((int)$r['inquiry_id']);
            $set = 'response_count = (SELECT COUNT(*) FROM community_inquiry_responses x WHERE x.inquiry_id = :i AND x.parent_id IS NULL AND x.deleted_at IS NULL)';
            if ($q && (int)$q['accepted_response_id'] === (int)$r['id']) {
                $set .= ", accepted_response_id = NULL, status = IF(status = 'answered', 'open', status)";
            }
            DB::run("UPDATE community_inquiries SET $set WHERE id = :i2", ['i' => (int)$r['inquiry_id'], 'i2' => (int)$r['inquiry_id']]);
        });
    }

    /** The author or a moderator chooses the accepted answer (or clears it): the inquiry becomes Answered */
    public static function accept(array $q, ?int $responseId): void
    {
        if (!self::canManage($q)) {
            fail('Only the author of the inquiry or a moderator chooses the accepted answer.');
        }
        if ($responseId) {
            $r = self::response($responseId);
            if (!$r || (int)$r['inquiry_id'] !== (int)$q['id'] || $r['parent_id'] || $r['deleted_at'] || (int)$r['is_hidden'] === 1) {
                fail('That response cannot be accepted.');
            }
        }
        $status = $responseId ? ($q['status'] === 'resolved' ? 'resolved' : 'answered') : ($q['status'] === 'answered' ? 'open' : $q['status']);
        DB::update('community_inquiries', ['accepted_response_id' => $responseId, 'status' => $status, 'last_activity_at' => Community::now()], 'id = :id', ['id' => (int)$q['id']]);
        if ((int)$q['user_id'] !== Community::me()) {
            Community::log('accept', 'inquiry', (int)$q['id'], (int)$q['user_id'], '', $responseId ? 'Response #' . $responseId : 'Cleared');
        }
        if ($responseId && isset($r) && (int)$r['user_id'] !== Community::me()) {
            Community::notify((int)$r['user_id'], 'accepted', 'Your response to "' . Community::excerpt($q['title'], 60) . '" was accepted as the answer',
                url('comm.inquiries', ['id' => (int)$q['id']]) . '#r' . $responseId, 'inqacc:' . $responseId, Community::me());
        }
    }

    public static function setStatus(array $q, string $status): void
    {
        if (!self::canManage($q)) {
            fail('Only the author of the inquiry or a moderator changes its status.');
        }
        if (!isset(Community::STATUSES[$status])) {
            fail('Unknown status.');
        }
        if ($status === 'answered' && !$q['accepted_response_id']) {
            fail('Accept a response first: the inquiry is then Answered.');
        }
        $resolved = $status === 'resolved';
        DB::update('community_inquiries', ['status' => $status, 'resolved_by' => $resolved ? Community::me() : null, 'resolved_at' => $resolved ? Community::now() : null,
            'last_activity_at' => Community::now()], 'id = :id', ['id' => (int)$q['id']]);
        if ((int)$q['user_id'] !== Community::me()) {
            Community::log('inquiry_status', 'inquiry', (int)$q['id'], (int)$q['user_id'], '', 'Status: ' . Community::STATUSES[$status]);
            if ($resolved) {
                Community::notify((int)$q['user_id'], 'resolved', 'Your inquiry "' . Community::excerpt($q['title'], 60) . '" was marked as resolved',
                    url('comm.inquiries', ['id' => (int)$q['id']]), 'inqres:' . (int)$q['id'], Community::me());
            }
        }
    }

    public static function viewed(array $q): void
    {
        $k = 'inq_seen';
        $seen = $_SESSION[$k] ?? [];
        if (!in_array((int)$q['id'], $seen, true)) {
            DB::run('UPDATE community_inquiries SET views = views + 1 WHERE id = :id', ['id' => (int)$q['id']]);
            $seen[] = (int)$q['id'];
            $_SESSION[$k] = array_slice($seen, -200);
        }
        DB::run('UPDATE community_notifications SET is_read = 1 WHERE user_id = :u AND dedupe_key IN (:a, :b)',
            ['u' => Community::me(), 'a' => 'inqresp:' . (int)$q['id'], 'b' => 'inqres:' . (int)$q['id']]);
    }
}
