<?php
declare(strict_types=1);

/**
 * v41: the Community: chat channels, private messages, questions and inquiries, notifications and moderation, for the
 * users of the company (the users table and log-in of the system; every company has its own community).
 *
 * Rights (Page Access Configuration):
 *   comm.chat, comm.inquiries   View: read. Create: post, react, ask, respond. Edit / Delete: change or delete one's own.
 *   comm.manage                 View: moderator (sees hidden posts, the dashboard, reports and the log).
 *                               Edit: hide, pin, announce, official answers, handle reports.
 *                               Delete: delete other people's posts, mute and suspend users.
 *                               Create: channels and inquiry categories.
 * Private messages are seen only by the two people in the conversation. A moderator sees a private message only as the
 * words a participant reported (the report keeps a copy of them).
 *
 * "Real time" works by polling: the open page asks every few seconds for what is new (api.php, a=poll), which works on
 * every PHP host (no WebSocket server to run). Every post carries a key made by the browser, so a message sent twice
 * on a bad connection is kept once.
 */
final class Community
{
    public const REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '✅', '🎉'];
    public const REPORT_REASONS = ['spam' => 'Spam or advertising', 'abuse' => 'Harassment or abuse', 'offensive' => 'Offensive language',
        'private' => 'Shares private information', 'off_topic' => 'Off-topic or misleading', 'other' => 'Something else'];
    public const STATUSES = ['open' => 'Open', 'answered' => 'Answered', 'resolved' => 'Resolved'];

    private const FILE_EXT = ['jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'gif' => 'image/gif', 'webp' => 'image/webp',
        'pdf' => 'application/pdf', 'doc' => 'application/msword', 'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.ms-excel', 'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'ppt' => 'application/vnd.ms-powerpoint', 'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'csv' => 'text/csv', 'txt' => 'text/plain', 'zip' => 'application/zip'];
    private const IMAGES = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    private const CHUNK = 262144;
    private const MAX_FILE = 10485760;      // 10 MB, or less when php.ini allows less
    public const MAX_FILES = 6;             // files on one message
    public const MAX_BODY = 4000;           // characters in a chat message

    private static ?bool $ready = null;
    private static array $modCache = [];
    private static array $userCache = [];

    // ================================================================== basics

    public static function ready(): bool
    {
        if (self::$ready === null) {
            try {
                DB::value('SELECT COUNT(*) FROM community_messages WHERE 1 = 0');
                DB::value('SELECT COUNT(*) FROM community_mod_log WHERE 1 = 0');
                self::$ready = true;
            } catch (Throwable $e) {
                self::$ready = false;
            }
        }
        return self::$ready;
    }

    public static function now(): string
    {
        return date('Y-m-d H:i:s');
    }

    public static function me(): int
    {
        return (int)Auth::id();
    }

    /** The six channels and six categories of a new company (a fresh install) */
    public static function seedDefaults(): void
    {
        $now = self::now();
        foreach ([
            ['general', 'General Discussion', 'Everyday conversations and community interactions.', 'chat', 'everyone', 10],
            ['questions', 'Questions and Inquiries', 'General questions that need answers.', 'chat', 'everyone', 20],
            ['help', 'Help and Support', 'Help with the system, your account or a technical problem.', 'chat', 'everyone', 30],
            ['announcements', 'Announcements', 'Important updates from the administrators.', 'announcement', 'moderators', 40],
            ['suggestions', 'Suggestions and Feedback', 'Recommendations and requests for improvement.', 'chat', 'everyone', 50],
            ['concerns', 'Community Concerns', 'Questions and concerns that can be discussed openly.', 'chat', 'everyone', 60],
        ] as [$slug, $name, $desc, $kind, $policy, $sort]) {
            DB::run('INSERT IGNORE INTO community_channels (slug, name, description, kind, post_policy, sort_order, created_at) VALUES (:s, :n, :d, :k, :p, :o, :c)',
                ['s' => $slug, 'n' => $name, 'd' => $desc, 'k' => $kind, 'p' => $policy, 'o' => $sort, 'c' => $now]);
        }
        foreach ([['General', 10], ['Accounts and Access', 20], ['Transactions', 30], ['Reports', 40], ['Technical Issues', 50], ['Suggestions', 60]] as [$n, $o]) {
            DB::run('INSERT IGNORE INTO community_inquiry_categories (name, sort_order) VALUES (:n, :o)', ['n' => $n, 'o' => $o]);
        }
    }

    // ================================================================== rights

    public static function isMod(?int $uid = null): bool
    {
        $uid ??= self::me();
        if (!$uid) {
            return false;
        }
        return self::$modCache[$uid] ??= Access::page('comm.manage', $uid);
    }

    /** moderate: hide, pin, announce, official answers, reports */
    public static function canModerate(): bool
    {
        return Access::can('comm.manage', 'edit');
    }

    /** delete other people's posts, mute and suspend */
    public static function canSanction(): bool
    {
        return Access::can('comm.manage', 'delete');
    }

    /** channels and categories */
    public static function canConfigure(): bool
    {
        return Access::can('comm.manage', 'create');
    }

    /** The mute or suspension in force for a user, or null */
    public static function sanction(?int $uid = null): ?array
    {
        $uid ??= self::me();
        static $cache = [];
        if (!array_key_exists($uid, $cache)) {
            $cache[$uid] = DB::row(
                "SELECT * FROM community_sanctions WHERE user_id = :u AND lifted_at IS NULL AND (ends_at IS NULL OR ends_at > :n)
                  ORDER BY kind = 'suspend' DESC, id DESC LIMIT 1",
                ['u' => $uid, 'n' => self::now()]
            );
        }
        return $cache[$uid];
    }

    public static function suspended(?int $uid = null): bool
    {
        return (self::sanction($uid)['kind'] ?? '') === 'suspend';
    }

    public static function muted(?int $uid = null): bool
    {
        return self::sanction($uid) !== null;
    }

    public static function sanctionText(array $s): string
    {
        return ($s['kind'] === 'suspend' ? 'Your community access is suspended' : 'You are muted in the community')
            . ($s['ends_at'] ? ' until ' . fdatetime($s['ends_at']) : ' until a moderator lifts it') . '. Reason: ' . $s['reason'];
    }

    /** May post on a page (comm.chat or comm.inquiries)? Throws the reason when not. */
    public static function requirePost(string $page = 'comm.chat'): void
    {
        if (!Access::can($page, 'create')) {
            fail('Your role may read the community but not post. Ask your administrator if you need to.');
        }
        if ($s = self::sanction()) {
            fail(self::sanctionText($s) . '.');
        }
    }

    // ================================================================== users

    /** id => [id, name, username, initials, avatar, mod] for display */
    public static function users(array $ids): array
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        $need = array_values(array_diff($ids, array_keys(self::$userCache)));
        if ($need) {
            [$in, $p] = DB::in('u', $need);
            foreach (DB::all("SELECT u.id, u.username, u.full_name, u.status, s.avatar_file_id FROM users u
                                LEFT JOIN community_settings s ON s.user_id = u.id WHERE u.id IN $in", $p) as $u) {
                self::$userCache[(int)$u['id']] = self::userCard($u);
            }
            foreach ($need as $id) {
                self::$userCache[$id] ??= ['id' => $id, 'name' => 'Former user', 'username' => '', 'initials' => '?', 'avatar' => '', 'color' => 0, 'mod' => false];
            }
        }
        return array_intersect_key(self::$userCache, array_flip($ids));
    }

    public static function user(int $id): array
    {
        return self::users([$id])[$id];
    }

    private static function userCard(array $u): array
    {
        $name = trim((string)$u['full_name']) ?: (string)$u['username'];
        $words = array_values(array_filter(preg_split('/\s+/u', $name) ?: []));
        $ini = mb_strtoupper(mb_substr($words[0] ?? '?', 0, 1) . (count($words) > 1 ? mb_substr($words[count($words) - 1], 0, 1) : ''));
        return [
            'id' => (int)$u['id'], 'name' => $name, 'username' => (string)$u['username'], 'initials' => $ini ?: '?',
            'avatar' => !empty($u['avatar_file_id']) ? url('comm.file', ['id' => (int)$u['avatar_file_id']]) : '',
            'color' => crc32((string)$u['username']) % 6, 'mod' => self::isMod((int)$u['id']),
        ];
    }

    /** The picture or the initials of a user, as HTML */
    public static function avatar(array $u, string $size = ''): string
    {
        $cls = 'cm-av cm-av-c' . (int)$u['color'] . ($size ? ' cm-av-' . $size : '');
        return $u['avatar'] !== ''
            ? '<span class="' . $cls . '"><img src="' . h($u['avatar']) . '" alt="" loading="lazy"></span>'
            : '<span class="' . $cls . '" aria-hidden="true">' . h($u['initials']) . '</span>';
    }

    public static function settings(?int $uid = null): array
    {
        $uid ??= self::me();
        $s = DB::row('SELECT * FROM community_settings WHERE user_id = :u', ['u' => $uid]);
        return $s ?: ['user_id' => $uid, 'dm_policy' => 'everyone', 'avatar_file_id' => null, 'notify_mentions' => 1, 'notify_dm' => 1,
            'notify_announcements' => 1, 'notify_inquiries' => 1, 'last_seen_at' => null];
    }

    public static function saveSettings(array $v): void
    {
        $uid = self::me();
        $row = ['dm_policy' => in_array($v['dm_policy'] ?? '', ['everyone', 'moderators', 'nobody'], true) ? $v['dm_policy'] : 'everyone',
            'notify_mentions' => !empty($v['notify_mentions']) ? 1 : 0, 'notify_dm' => !empty($v['notify_dm']) ? 1 : 0,
            'notify_announcements' => !empty($v['notify_announcements']) ? 1 : 0, 'notify_inquiries' => !empty($v['notify_inquiries']) ? 1 : 0,
            'updated_at' => self::now()];
        if (array_key_exists('avatar_file_id', $v)) {
            $row['avatar_file_id'] = $v['avatar_file_id'];
        }
        $cols = array_keys($row);
        DB::run('INSERT INTO community_settings (user_id, ' . implode(', ', $cols) . ') VALUES (:user_id, :' . implode(', :', $cols) . ')
                 ON DUPLICATE KEY UPDATE ' . implode(', ', array_map(fn($c) => "$c = VALUES($c)", $cols)), $row + ['user_id' => $uid]);
        unset(self::$userCache[$uid]);
    }

    /** Marks the user as seen now (written at most once a minute) */
    public static function touch(): void
    {
        DB::run('INSERT INTO community_settings (user_id, last_seen_at) VALUES (:u, :n)
                 ON DUPLICATE KEY UPDATE last_seen_at = IF(last_seen_at IS NULL OR last_seen_at < :o, VALUES(last_seen_at), last_seen_at)',
            ['u' => self::me(), 'n' => self::now(), 'o' => date('Y-m-d H:i:s', time() - 60)]);
    }

    /**
     * v41.1: called on every page of the system (index.php), so "Active now" lists everyone who has the system open,
     * whatever page they are on (a cashier at the POS Register too), not only those on the Community Chat. Written at
     * most once a minute per user.
     */
    public static function seen(): void
    {
        try {
            if (session_status() !== PHP_SESSION_ACTIVE || !self::me() || (int)($_SESSION['comm_seen_at'] ?? 0) > time() - 60 || !self::ready()) {
                return;
            }
            $_SESSION['comm_seen_at'] = time();
            self::touch();
        } catch (Throwable $e) {
            // presence is a convenience: never stop a page for it
        }
    }

    /** Logging out: no longer shown under "Active now" */
    public static function away(int $uid): void
    {
        try {
            if (self::ready()) {
                DB::run('UPDATE community_settings SET last_seen_at = NULL WHERE user_id = :u', ['u' => $uid]);
            }
        } catch (Throwable $e) {
        }
    }

    /** The users who had a page of the system open in the last five minutes and may use the Community Chat */
    public static function online(int $limit = 30): array
    {
        $ids = array_map('intval', DB::column('SELECT s.user_id FROM community_settings s JOIN users u ON u.id = s.user_id AND u.status = \'active\' AND u.is_platform = 0
                                                 WHERE s.last_seen_at >= :t ORDER BY s.last_seen_at DESC LIMIT 100',
            ['t' => date('Y-m-d H:i:s', time() - 300)]));
        $ids = array_values(array_filter($ids, fn($id) => Access::page('comm.chat', $id) && !self::suspended($id)));
        return array_values(self::users(array_slice($ids, 0, $limit)));
    }

    /** Users whose name or username starts with / contains the text, who may use the community (for @mentions and new messages) */
    public static function findUsers(string $q, int $limit = 8): array
    {
        $q = trim($q);
        $rows = DB::all(
            "SELECT id FROM users WHERE status = 'active' AND approval_status = 'approved' AND is_platform = 0
                AND (username LIKE :a OR full_name LIKE :b) ORDER BY (username LIKE :c) DESC, full_name LIMIT 40",
            ['a' => $q . '%', 'b' => '%' . $q . '%', 'c' => $q . '%']
        );
        $out = [];
        foreach (self::users(array_column($rows, 'id')) as $u) {
            if (Access::page('comm.chat', $u['id']) && !self::suspended($u['id'])) {
                $out[] = $u;
            }
            if (count($out) >= $limit) {
                break;
            }
        }
        return $out;
    }

    // ================================================================== text

    /** The text of a post as safe HTML: escaped, links made clickable, @mentions marked, line breaks kept */
    public static function render(?string $body): string
    {
        $h = h((string)$body);
        $h = preg_replace_callback('~\bhttps?://[^\s<>"\']+~i', function ($m) {
            $url = $m[0];
            $tail = '';
            while ($url !== '' && strpbrk(substr($url, -1), '.,;:!?)') !== false) {
                $tail = substr($url, -1) . $tail;
                $url = substr($url, 0, -1);
            }
            return '<a href="' . $url . '" target="_blank" rel="noopener noreferrer nofollow">' . $url . '</a>' . $tail;
        }, $h) ?? $h;
        $names = self::mentionedUsernames((string)$body);
        if ($names) {
            [$in, $p] = DB::in('n', $names);
            $known = array_map('strtolower', DB::column("SELECT username FROM users WHERE username IN $in", $p));
            $h = preg_replace_callback('/(^|[\s(>])@([A-Za-z0-9._-]{2,50})/u', function ($m) use ($known) {
                return in_array(strtolower($m[2]), $known, true) ? $m[1] . '<span class="cm-mention">@' . $m[2] . '</span>' : $m[0];
            }, $h) ?? $h;
        }
        return nl2br($h, false);
    }

    /** @return string[] the usernames written as @username in a text */
    public static function mentionedUsernames(string $body): array
    {
        preg_match_all('/(?:^|[\s(])@([A-Za-z0-9._-]{2,50})/u', $body, $m);
        return array_values(array_unique(array_map(fn($x) => rtrim($x, '.-'), $m[1] ?? [])));
    }

    /** user ids of the @mentions in a text */
    public static function mentionedIds(string $body): array
    {
        $names = self::mentionedUsernames($body);
        if (!$names) {
            return [];
        }
        [$in, $p] = DB::in('n', $names);
        return array_map('intval', DB::column("SELECT id FROM users WHERE username IN $in AND status = 'active'", $p));
    }

    public static function excerpt(?string $body, int $len = 90): string
    {
        $t = trim(preg_replace('/\s+/u', ' ', (string)$body) ?? '');
        return mb_strlen($t) > $len ? mb_substr($t, 0, $len - 1) . '…' : $t;
    }

    public static function clean(string $body, int $max = self::MAX_BODY): string
    {
        $body = str_replace(["\r\n", "\r"], "\n", $body);
        $body = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $body) ?? '';
        $body = preg_replace("/\n{4,}/", "\n\n\n", $body) ?? $body;
        $body = trim($body);
        if (mb_strlen($body) > $max) {
            fail('The message is too long (' . number_format(mb_strlen($body)) . ' characters; at most ' . number_format($max) . ').');
        }
        return $body;
    }

    public static function clientKey($v): ?string
    {
        $v = (string)$v;
        return preg_match('/^[A-Za-z0-9_-]{8,40}$/', $v) ? $v : null;
    }

    // ================================================================== anti-spam

    /** Refuses a post sent too fast, or the same text again and again */
    public static function rateCheck(string $table, string $userCol, string $body = ''): void
    {
        $uid = self::me();
        $t10 = date('Y-m-d H:i:s', time() - 10);
        $t60 = date('Y-m-d H:i:s', time() - 60);
        $r = DB::row("SELECT SUM(created_at >= :a) AS s10, COUNT(*) AS s60 FROM $table WHERE $userCol = :u AND created_at >= :b", ['u' => $uid, 'a' => $t10, 'b' => $t60]);
        if ((int)($r['s10'] ?? 0) >= 6 || (int)($r['s60'] ?? 0) >= 30) {
            fail('You are sending messages too quickly. Wait a moment and try again.');
        }
        if ($body !== '' && mb_strlen($body) > 3) {
            $same = (int)DB::value("SELECT COUNT(*) FROM $table WHERE $userCol = :u AND created_at >= :t AND body = :b",
                ['u' => $uid, 't' => date('Y-m-d H:i:s', time() - 120), 'b' => $body]);
            if ($same >= 2) {
                fail('You already sent this message. Repeating it is treated as spam.');
            }
        }
    }

    // ================================================================== channels

    /** The channels this user may see, in order (archived ones only for moderators, when asked) */
    public static function channels(bool $withArchived = false): array
    {
        $uid = self::me();
        $mod = self::isMod();
        return DB::all(
            'SELECT c.* FROM community_channels c
              WHERE (c.is_archived = 0 OR :arch = 1)
                AND (c.is_restricted = 0 OR :mod = 1 OR EXISTS (SELECT 1 FROM community_channel_roles cr JOIN user_roles ur ON ur.role_id = cr.role_id AND ur.user_id = :u WHERE cr.channel_id = c.id))
              ORDER BY c.sort_order, c.id',
            ['arch' => $withArchived && $mod ? 1 : 0, 'mod' => $mod ? 1 : 0, 'u' => $uid]
        );
    }

    public static function channel(int $id): ?array
    {
        return DB::row('SELECT * FROM community_channels WHERE id = :id', ['id' => $id]);
    }

    public static function channelBySlug(string $slug): ?array
    {
        return DB::row('SELECT * FROM community_channels WHERE slug = :s', ['s' => $slug]);
    }

    public static function canSeeChannel(array $c, ?int $uid = null): bool
    {
        $uid ??= self::me();
        if (!Access::page('comm.chat', $uid) || self::suspended($uid)) {
            return false;
        }
        if ((int)$c['is_archived'] === 1 && !self::isMod($uid)) {
            return false;
        }
        if ((int)$c['is_restricted'] === 0 || self::isMod($uid)) {
            return true;
        }
        return (bool)DB::value('SELECT 1 FROM community_channel_roles cr JOIN user_roles ur ON ur.role_id = cr.role_id AND ur.user_id = :u WHERE cr.channel_id = :c LIMIT 1',
            ['u' => $uid, 'c' => (int)$c['id']]);
    }

    public static function canPostIn(array $c): bool
    {
        if ((int)$c['is_archived'] === 1 || !Access::can('comm.chat', 'create') || self::muted()) {
            return false;
        }
        return $c['post_policy'] !== 'moderators' || self::canModerate();
    }

    /** Joins the user to the channels they see (a channel opened for the first time starts as read) */
    public static function join(array $channels): void
    {
        $uid = self::me();
        $have = array_map('intval', DB::column('SELECT channel_id FROM community_members WHERE user_id = :u', ['u' => $uid]));
        foreach ($channels as $c) {
            if (!in_array((int)$c['id'], $have, true)) {
                $last = (int)DB::value('SELECT COALESCE(MAX(id), 0) FROM community_messages WHERE channel_id = :c', ['c' => (int)$c['id']]);
                DB::run('INSERT IGNORE INTO community_members (channel_id, user_id, last_read_id, joined_at) VALUES (:c, :u, :l, :n)',
                    ['c' => (int)$c['id'], 'u' => $uid, 'l' => max(0, $last - 20), 'n' => self::now()]);
            }
        }
    }

    /** channel id => unread messages (not the user's own) */
    public static function unreadChannels(): array
    {
        $rows = DB::all(
            'SELECT mb.channel_id, COUNT(m.id) AS n
               FROM community_members mb
               JOIN community_messages m ON m.channel_id = mb.channel_id AND m.id > mb.last_read_id AND m.user_id <> mb.user_id
                AND m.deleted_at IS NULL AND m.is_hidden = 0
              WHERE mb.user_id = :u GROUP BY mb.channel_id',
            ['u' => self::me()]
        );
        $out = [];
        foreach ($rows as $r) {
            $out[(int)$r['channel_id']] = (int)$r['n'];
        }
        return $out;
    }

    public static function markChannelRead(int $channelId, int $lastId): void
    {
        DB::run('UPDATE community_members SET last_read_id = GREATEST(last_read_id, :l) WHERE channel_id = :c AND user_id = :u',
            ['l' => $lastId, 'c' => $channelId, 'u' => self::me()]);
    }

    // ================================================================== chat messages

    private const MSG_COLS = 'm.id, m.channel_id, m.user_id, m.body, m.reply_to_id, m.client_key, m.is_official, m.is_pinned, m.is_hidden, m.hidden_reason, m.edited_at, m.deleted_at, m.created_at, m.updated_at';

    public static function message(int $id): ?array
    {
        return DB::row('SELECT ' . self::MSG_COLS . ' FROM community_messages m WHERE m.id = :id', ['id' => $id]);
    }

    /** Messages of a channel: the newest $limit (before $before), or those after $after, oldest first */
    public static function messages(int $channelId, ?int $after = null, ?int $before = null, int $limit = 40): array
    {
        $p = ['c' => $channelId];
        $w = 'm.channel_id = :c';
        if ($after !== null) {
            $w .= ' AND m.id > :a';
            $p['a'] = $after;
            $rows = DB::all('SELECT ' . self::MSG_COLS . " FROM community_messages m WHERE $w ORDER BY m.id LIMIT " . (int)$limit, $p);
        } else {
            if ($before) {
                $w .= ' AND m.id < :b';
                $p['b'] = $before;
            }
            $rows = array_reverse(DB::all('SELECT ' . self::MSG_COLS . " FROM community_messages m WHERE $w ORDER BY m.id DESC LIMIT " . (int)$limit, $p));
        }
        return self::shape($rows, 'message');
    }

    /** Messages of a channel changed since a time (edited, deleted, hidden, pinned, reacted to) */
    public static function changed(int $channelId, string $since, int $upTo): array
    {
        $rows = DB::all('SELECT ' . self::MSG_COLS . ' FROM community_messages m WHERE m.channel_id = :c AND m.updated_at >= :s AND m.id <= :u ORDER BY m.id LIMIT 200',
            ['c' => $channelId, 's' => $since, 'u' => $upTo]);
        return self::shape($rows, 'message');
    }

    public static function pinned(int $channelId): array
    {
        $rows = DB::all('SELECT ' . self::MSG_COLS . ' FROM community_messages m WHERE m.channel_id = :c AND m.is_pinned = 1 AND m.deleted_at IS NULL ORDER BY m.pinned_at DESC LIMIT 20',
            ['c' => $channelId]);
        return self::shape($rows, 'message');
    }

    /**
     * Rows of messages (chat or private) made ready for the page: the author, the text as safe HTML, the message it
     * replies to, files, reactions and what the user may do with each.
     */
    public static function shape(array $rows, string $kind): array
    {
        if (!$rows) {
            return [];
        }
        $uid = self::me();
        $mod = $kind === 'message' && self::isMod();
        $ids = array_map(fn($r) => (int)$r['id'], $rows);
        $authorCol = $kind === 'message' ? 'user_id' : 'sender_id';
        $replyIds = array_values(array_filter(array_map(fn($r) => (int)($r['reply_to_id'] ?? 0), $rows)));
        $replies = [];
        if ($replyIds) {
            [$in, $p] = DB::in('r', $replyIds);
            $tbl = $kind === 'message' ? 'community_messages' : 'community_dm_messages';
            foreach (DB::all("SELECT id, $authorCol AS uid, body, deleted_at" . ($kind === 'message' ? ', is_hidden' : ', 0 AS is_hidden') . " FROM $tbl WHERE id IN $in", $p) as $r) {
                $replies[(int)$r['id']] = $r;
            }
        }
        $users = self::users(array_merge(array_map(fn($r) => (int)$r[$authorCol], $rows), array_map(fn($r) => (int)$r['uid'], $replies)));
        [$in, $p] = DB::in('i', $ids);
        $files = [];
        foreach (DB::all("SELECT id, owner_id, file_name, file_size, is_image FROM community_files WHERE owner_type = :t AND owner_id IN $in ORDER BY id", $p + ['t' => $kind === 'message' ? 'message' : 'dm']) as $f) {
            $files[(int)$f['owner_id']][] = ['id' => (int)$f['id'], 'name' => $f['file_name'], 'size' => self::size((int)$f['file_size']),
                'image' => (int)$f['is_image'] === 1, 'url' => url('comm.file', ['id' => (int)$f['id']]), 'view' => url('comm.file', ['id' => (int)$f['id'], 'view' => 1])];
        }
        $reacts = [];
        if ($kind === 'message') {
            foreach (DB::all("SELECT message_id, emoji, COUNT(*) AS n, SUM(user_id = :me) AS mine, GROUP_CONCAT(user_id ORDER BY created_at SEPARATOR ',') AS who
                                FROM community_reactions WHERE message_id IN $in GROUP BY message_id, emoji ORDER BY MIN(created_at)", $p + ['me' => $uid]) as $r) {
                $who = array_slice(array_map('intval', explode(',', (string)$r['who'])), 0, 8);
                $reacts[(int)$r['message_id']][] = ['e' => $r['emoji'], 'n' => (int)$r['n'], 'mine' => (int)$r['mine'] > 0,
                    'who' => implode(', ', array_map(fn($x) => self::user($x)['name'], $who)) . ((int)$r['n'] > 8 ? ' and others' : '')];
            }
        }
        $canEditOwn = Access::can('comm.chat', 'edit') && !self::muted();
        $canDelOwn = Access::can('comm.chat', 'delete');
        $canPost = Access::can('comm.chat', 'create') && !self::muted();
        $out = [];
        foreach ($rows as $r) {
            $id = (int)$r['id'];
            $author = (int)$r[$authorCol];
            $deleted = !empty($r['deleted_at']);
            $hidden = (int)($r['is_hidden'] ?? 0) === 1;
            $own = $author === $uid;
            $showBody = !$deleted && (!$hidden || $mod || $own);
            $m = [
                'id' => $id, 'user' => $users[$author], 'own' => $own, 'key' => $own ? (string)($r['client_key'] ?? '') : '',
                'html' => $showBody ? self::render($r['body']) : '',
                'raw' => $own && $showBody ? (string)$r['body'] : '',
                'deleted' => $deleted, 'hidden' => $hidden, 'hidden_reason' => $hidden && ($mod || $own) ? (string)($r['hidden_reason'] ?? '') : '',
                'edited' => !empty($r['edited_at']), 'official' => (int)($r['is_official'] ?? 0) === 1, 'pinned' => (int)($r['is_pinned'] ?? 0) === 1,
                'at' => $r['created_at'], 'time' => date('g:i A', strtotime($r['created_at'])), 'day' => date('Y-m-d', strtotime($r['created_at'])),
                'full' => fdatetime($r['created_at']),
                'files' => $showBody ? ($files[$id] ?? []) : [], 'reactions' => $deleted ? [] : ($reacts[$id] ?? []),
                'reply' => null,
                'can' => [
                    'reply' => !$deleted && $canPost, 'react' => $kind === 'message' && !$deleted && !$hidden && $canPost,
                    'edit' => $own && !$deleted && !$hidden && ($kind === 'dm' || $canEditOwn),
                    'delete' => !$deleted && (($own && ($kind === 'dm' || $canDelOwn)) || ($kind === 'message' && self::canSanction())),
                    'hide' => $kind === 'message' && !$deleted && self::canModerate(),
                    'pin' => $kind === 'message' && !$deleted && !$hidden && self::canModerate(),
                    'report' => !$own && !$deleted,
                ],
            ];
            if (!empty($r['reply_to_id']) && isset($replies[(int)$r['reply_to_id']])) {
                $rp = $replies[(int)$r['reply_to_id']];
                $gone = !empty($rp['deleted_at']) || ((int)$rp['is_hidden'] === 1 && !$mod);
                $m['reply'] = ['id' => (int)$rp['id'], 'name' => $users[(int)$rp['uid']]['name'], 'text' => $gone ? 'Message removed' : self::excerpt($rp['body'], 120)];
            }
            $out[] = $m;
        }
        return $out;
    }

    /** Posts a chat message; returns its id (the same id again for a message sent twice) */
    public static function post(array $c, string $body, ?int $replyTo, ?string $key, array $fileIds): int
    {
        self::requirePost('comm.chat');
        if (!self::canSeeChannel($c)) {
            fail('You cannot post in this channel.');
        }
        if (!self::canPostIn($c)) {
            fail((int)$c['is_archived'] === 1 ? 'This channel is archived.' : 'Only moderators post in ' . $c['name'] . '.');
        }
        $uid = self::me();
        if ($key && ($old = DB::value('SELECT id FROM community_messages WHERE user_id = :u AND client_key = :k', ['u' => $uid, 'k' => $key]))) {
            return (int)$old;
        }
        $body = self::clean($body);
        $fileIds = self::ownPending($fileIds);
        if ($body === '' && !$fileIds) {
            fail('Type a message or attach a file.');
        }
        self::rateCheck('community_messages', 'user_id', $body);
        if ($replyTo) {
            $rt = self::message($replyTo);
            if (!$rt || (int)$rt['channel_id'] !== (int)$c['id']) {
                $replyTo = null;
            }
        }
        $now = self::now();
        $official = $c['kind'] === 'announcement' && self::canModerate() ? 1 : 0;
        $id = DB::tx(function () use ($c, $uid, $body, $replyTo, $key, $now, $official, $fileIds) {
            $id = (int)DB::insert('community_messages', ['channel_id' => (int)$c['id'], 'user_id' => $uid, 'body' => $body, 'reply_to_id' => $replyTo,
                'client_key' => $key, 'is_official' => $official, 'created_at' => $now, 'updated_at' => $now]);
            self::claimFiles($fileIds, 'message', $id);
            return $id;
        });
        self::markChannelRead((int)$c['id'], $id);
        $link = url('comm.chat', ['ch' => $c['slug'], 'm' => $id]);
        $me = self::user($uid)['name'];
        // mentions and the person replied to
        $notified = [];
        foreach (self::mentionedIds($body) as $m) {
            if ($m !== $uid && self::canSeeChannel($c, $m) && (int)self::settings($m)['notify_mentions'] === 1) {
                self::notify($m, 'mention', $me . ' mentioned you in ' . $c['name'] . ': ' . self::excerpt($body, 80), $link, 'mention:' . $id, $uid);
                $notified[] = $m;
            }
        }
        if ($replyTo && ($rt = self::message($replyTo)) && (int)$rt['user_id'] !== $uid && !in_array((int)$rt['user_id'], $notified, true)) {
            self::notify((int)$rt['user_id'], 'reply', $me . ' replied to your message in ' . $c['name'] . ': ' . self::excerpt($body, 80), $link, 'reply:' . $id, $uid);
        }
        if ($official) {
            self::announce($c, $id, $body);
        }
        return $id;
    }

    /** Notifies everyone who reads the community of an announcement */
    private static function announce(array $c, int $msgId, string $body): void
    {
        $uid = self::me();
        $text = mb_substr('Announcement: ' . self::excerpt($body, 120), 0, 250);
        $link = url('comm.chat', ['ch' => $c['slug'], 'm' => $msgId]);
        $ids = array_map('intval', DB::column(
            "SELECT u.id FROM users u LEFT JOIN community_settings s ON s.user_id = u.id
              WHERE u.status = 'active' AND u.approval_status = 'approved' AND u.id <> :me AND COALESCE(s.notify_announcements, 1) = 1",
            ['me' => $uid]
        ));
        foreach ($ids as $u) {
            if (self::canSeeChannel($c, $u)) {
                self::notify($u, 'announcement', $text, $link, 'ann:' . $msgId, $uid);
            }
        }
    }

    public static function edit(int $id, string $body): void
    {
        $m = self::message($id);
        if (!$m || (int)$m['user_id'] !== self::me() || $m['deleted_at'] || (int)$m['is_hidden'] === 1) {
            fail('You can edit only your own messages.');
        }
        if (!Access::can('comm.chat', 'edit')) {
            fail('Your role may not edit messages.');
        }
        if (self::muted()) {
            fail(self::sanctionText(self::sanction()) . '.');
        }
        $body = self::clean($body);
        if ($body === '') {
            fail('A message cannot be empty. Delete it instead.');
        }
        DB::update('community_messages', ['body' => $body, 'edited_at' => self::now(), 'updated_at' => self::now()], 'id = :id', ['id' => $id]);
    }

    public static function delete(int $id, string $reason = ''): void
    {
        $m = self::message($id);
        if (!$m || $m['deleted_at']) {
            fail('The message was not found.');
        }
        $own = (int)$m['user_id'] === self::me();
        if (!($own && Access::can('comm.chat', 'delete')) && !self::canSanction()) {
            fail('You may delete only your own messages.');
        }
        $c = self::channel((int)$m['channel_id']);
        if (!$own) {
            self::log('delete_message', 'message', $id, (int)$m['user_id'], $reason ?: 'Removed by a moderator', 'In ' . ($c['name'] ?? '?') . ': ' . (string)$m['body']);
        }
        DB::tx(function () use ($id) {
            DB::update('community_messages', ['body' => null, 'deleted_at' => self::now(), 'deleted_by' => self::me(), 'is_pinned' => 0, 'updated_at' => self::now()], 'id = :id', ['id' => $id]);
            DB::run("DELETE FROM community_files WHERE owner_type = 'message' AND owner_id = :id", ['id' => $id]);
            DB::run('DELETE FROM community_reactions WHERE message_id = :id', ['id' => $id]);
        });
    }

    public static function react(int $id, string $emoji): void
    {
        if (!in_array($emoji, self::REACTIONS, true)) {
            fail('That reaction is not available.');
        }
        $m = self::message($id);
        $c = $m ? self::channel((int)$m['channel_id']) : null;
        if (!$m || !$c || !self::canSeeChannel($c) || $m['deleted_at'] || (int)$m['is_hidden'] === 1) {
            fail('The message was not found.');
        }
        self::requirePost('comm.chat');
        $k = ['m' => $id, 'u' => self::me(), 'e' => $emoji];
        if (DB::value('SELECT 1 FROM community_reactions WHERE message_id = :m AND user_id = :u AND emoji = :e', $k)) {
            DB::run('DELETE FROM community_reactions WHERE message_id = :m AND user_id = :u AND emoji = :e', $k);
        } else {
            DB::run('INSERT IGNORE INTO community_reactions (message_id, user_id, emoji, created_at) VALUES (:m, :u, :e, :n)', $k + ['n' => self::now()]);
        }
        DB::update('community_messages', ['updated_at' => self::now()], 'id = :id', ['id' => $id]);
    }

    public static function setPinned(int $id, bool $on): void
    {
        if (!self::canModerate()) {
            fail('Only moderators pin messages.');
        }
        $m = self::message($id);
        if (!$m || $m['deleted_at']) {
            fail('The message was not found.');
        }
        DB::update('community_messages', ['is_pinned' => $on ? 1 : 0, 'pinned_by' => $on ? self::me() : null, 'pinned_at' => $on ? self::now() : null, 'updated_at' => self::now()], 'id = :id', ['id' => $id]);
        self::log($on ? 'pin' : 'unpin', 'message', $id, (int)$m['user_id'], '', self::excerpt($m['body'], 200));
    }

    /** Hides or shows again a message, inquiry or response (moderators) */
    public static function setHidden(string $type, int $id, bool $on, string $reason): void
    {
        if (!self::canModerate()) {
            fail('Only moderators hide posts.');
        }
        $tables = ['message' => ['community_messages', 'user_id', 'body'], 'inquiry' => ['community_inquiries', 'user_id', 'title'], 'response' => ['community_inquiry_responses', 'user_id', 'body']];
        if (!isset($tables[$type])) {
            fail('That cannot be hidden.');
        }
        [$tbl, $ucol, $tcol] = $tables[$type];
        $row = DB::row("SELECT * FROM $tbl WHERE id = :id", ['id' => $id]);
        if (!$row) {
            fail('Not found.');
        }
        if ($on && trim($reason) === '') {
            fail('Give the reason for hiding it.');
        }
        $set = ['is_hidden' => $on ? 1 : 0, 'hidden_by' => $on ? self::me() : null, 'hidden_reason' => $on ? mb_substr(trim($reason), 0, 255) : null];
        if ($type === 'message') {
            $set['updated_at'] = self::now();
            $set['is_pinned'] = $on ? 0 : (int)$row['is_pinned'];
        }
        DB::update($tbl, $set, 'id = :id', ['id' => $id]);
        self::log($on ? 'hide' : 'unhide', $type, $id, (int)$row[$ucol], $reason, self::excerpt((string)$row[$tcol], 300));
    }

    // ================================================================== search

    /** Messages of a channel matching a text, a person, files or pins (newest first) */
    public static function search(int $channelId, string $q, int $fromUser = 0, string $has = '', int $limit = 50): array
    {
        $w = ['m.channel_id = :c', 'm.deleted_at IS NULL'];
        $p = ['c' => $channelId];
        if (!self::isMod()) {
            $w[] = 'm.is_hidden = 0';
        }
        if (trim($q) !== '') {
            $w[] = 'm.body LIKE :q';
            $p['q'] = '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim($q)) . '%';
        }
        if ($fromUser) {
            $w[] = 'm.user_id = :f';
            $p['f'] = $fromUser;
        }
        if ($has === 'files') {
            $w[] = "EXISTS (SELECT 1 FROM community_files f WHERE f.owner_type = 'message' AND f.owner_id = m.id)";
        } elseif ($has === 'pinned') {
            $w[] = 'm.is_pinned = 1';
        } elseif ($has === 'mentions') {
            $w[] = 'm.body LIKE :me';
            $p['me'] = '%@' . self::user(self::me())['username'] . '%';
        }
        $rows = DB::all('SELECT ' . self::MSG_COLS . ' FROM community_messages m WHERE ' . implode(' AND ', $w) . ' ORDER BY m.id DESC LIMIT ' . (int)$limit, $p);
        return self::shape($rows, 'message');
    }

    // ================================================================== private messages

    public static function conversation(int $id): ?array
    {
        $c = DB::row('SELECT * FROM community_conversations WHERE id = :id', ['id' => $id]);
        $me = self::me();
        if (!$c || ((int)$c['user_a'] !== $me && (int)$c['user_b'] !== $me)) {
            return null;    // never someone else's conversation, moderators included
        }
        $c['other'] = (int)$c['user_a'] === $me ? (int)$c['user_b'] : (int)$c['user_a'];
        $c['mine_read'] = (int)$c['user_a'] === $me ? (int)$c['a_last_read'] : (int)$c['b_last_read'];
        $c['their_read'] = (int)$c['user_a'] === $me ? (int)$c['b_last_read'] : (int)$c['a_last_read'];
        return $c;
    }

    public static function blocked(int $a, int $b): bool
    {
        return (bool)DB::value('SELECT 1 FROM community_blocks WHERE (user_id = :a AND blocked_id = :b) OR (user_id = :c AND blocked_id = :d) LIMIT 1',
            ['a' => $a, 'b' => $b, 'c' => $b, 'd' => $a]);
    }

    public static function iBlocked(int $other): bool
    {
        return (bool)DB::value('SELECT 1 FROM community_blocks WHERE user_id = :a AND blocked_id = :b', ['a' => self::me(), 'b' => $other]);
    }

    /** Why the user may not message $to ('' = may) */
    public static function dmRefusal(int $to): string
    {
        $me = self::me();
        if ($to === $me) {
            return 'You cannot message yourself.';
        }
        $u = DB::row('SELECT id, status FROM users WHERE id = :id', ['id' => $to]);
        if (!$u || $u['status'] !== 'active' || !Access::page('comm.chat', $to) || self::suspended($to)) {
            return 'This person cannot receive messages.';
        }
        if (!Access::can('comm.chat', 'create')) {
            return 'Your role may read the community but not send messages.';
        }
        if (($s = self::sanction()) && ($s['kind'] === 'suspend' || !self::isMod($to))) {
            return self::sanctionText($s) . '. You may still message a moderator.';
        }
        if (self::blocked($me, $to)) {
            return self::iBlocked($to) ? 'You blocked this person. Unblock them to send a message.' : 'This person is not taking messages from you.';
        }
        $policy = self::settings($to)['dm_policy'];
        if ($policy === 'nobody' && !self::canModerate()) {
            return 'This person does not take private messages.';
        }
        if ($policy === 'moderators' && !self::isMod()) {
            return 'This person takes private messages from moderators only.';
        }
        return '';
    }

    /** The conversation with another user, made when needed */
    public static function conversationWith(int $other): array
    {
        if ($why = self::dmRefusal($other)) {
            fail($why);
        }
        $me = self::me();
        [$a, $b] = $me < $other ? [$me, $other] : [$other, $me];
        DB::run('INSERT IGNORE INTO community_conversations (user_a, user_b, created_at) VALUES (:a, :b, :n)', ['a' => $a, 'b' => $b, 'n' => self::now()]);
        $id = (int)DB::value('SELECT id FROM community_conversations WHERE user_a = :a AND user_b = :b', ['a' => $a, 'b' => $b]);
        return self::conversation($id);
    }

    /** The user's conversations with messages, newest first: id, other user, last text, unread */
    public static function conversations(): array
    {
        $me = self::me();
        $rows = DB::all(
            'SELECT c.*, (SELECT COUNT(*) FROM community_dm_messages d WHERE d.conversation_id = c.id AND d.sender_id <> :m1 AND d.deleted_at IS NULL
                           AND d.id > IF(c.user_a = :m2, c.a_last_read, c.b_last_read)) AS unread,
                    (SELECT body FROM community_dm_messages d2 WHERE d2.id = c.last_message_id) AS last_body,
                    (SELECT deleted_at FROM community_dm_messages d3 WHERE d3.id = c.last_message_id) AS last_deleted
               FROM community_conversations c
              WHERE (c.user_a = :m3 OR c.user_b = :m4) AND c.last_message_id > 0
              ORDER BY c.last_message_at DESC LIMIT 100',
            ['m1' => $me, 'm2' => $me, 'm3' => $me, 'm4' => $me]
        );
        $others = array_map(fn($r) => (int)$r['user_a'] === $me ? (int)$r['user_b'] : (int)$r['user_a'], $rows);
        $users = self::users($others);
        $out = [];
        foreach ($rows as $i => $r) {
            $out[] = ['id' => (int)$r['id'], 'user' => $users[$others[$i]], 'unread' => (int)$r['unread'],
                'last' => $r['last_deleted'] ? 'Message deleted' : self::excerpt($r['last_body'], 60), 'at' => $r['last_message_at']];
        }
        return $out;
    }

    public static function dmMessages(int $convId, ?int $after = null, ?int $before = null, int $limit = 40): array
    {
        $cols = 'id, conversation_id, sender_id, body, reply_to_id, client_key, edited_at, deleted_at, created_at, updated_at';
        if ($after !== null) {
            $rows = DB::all("SELECT $cols FROM community_dm_messages WHERE conversation_id = :c AND id > :a ORDER BY id LIMIT " . (int)$limit, ['c' => $convId, 'a' => $after]);
        } else {
            $p = ['c' => $convId];
            $w = 'conversation_id = :c';
            if ($before) {
                $w .= ' AND id < :b';
                $p['b'] = $before;
            }
            $rows = array_reverse(DB::all("SELECT $cols FROM community_dm_messages WHERE $w ORDER BY id DESC LIMIT " . (int)$limit, $p));
        }
        return self::shape($rows, 'dm');
    }

    public static function dmChanged(int $convId, string $since, int $upTo): array
    {
        $rows = DB::all('SELECT id, conversation_id, sender_id, body, reply_to_id, client_key, edited_at, deleted_at, created_at, updated_at FROM community_dm_messages
                          WHERE conversation_id = :c AND updated_at >= :s AND id <= :u ORDER BY id LIMIT 200', ['c' => $convId, 's' => $since, 'u' => $upTo]);
        return self::shape($rows, 'dm');
    }

    public static function sendDm(array $conv, string $body, ?int $replyTo, ?string $key, array $fileIds): int
    {
        $me = self::me();
        if ($key && ($old = DB::value('SELECT id FROM community_dm_messages WHERE sender_id = :u AND client_key = :k', ['u' => $me, 'k' => $key]))) {
            return (int)$old;
        }
        if ($why = self::dmRefusal((int)$conv['other'])) {
            fail($why);
        }
        $body = self::clean($body);
        $fileIds = self::ownPending($fileIds);
        if ($body === '' && !$fileIds) {
            fail('Type a message or attach a file.');
        }
        self::rateCheck('community_dm_messages', 'sender_id', $body);
        if ($replyTo && !DB::value('SELECT 1 FROM community_dm_messages WHERE id = :r AND conversation_id = :c', ['r' => $replyTo, 'c' => (int)$conv['id']])) {
            $replyTo = null;
        }
        $now = self::now();
        $id = DB::tx(function () use ($conv, $me, $body, $replyTo, $key, $now, $fileIds) {
            $id = (int)DB::insert('community_dm_messages', ['conversation_id' => (int)$conv['id'], 'sender_id' => $me, 'body' => $body, 'reply_to_id' => $replyTo,
                'client_key' => $key, 'created_at' => $now, 'updated_at' => $now]);
            self::claimFiles($fileIds, 'dm', $id);
            $mine = (int)$conv['user_a'] === $me ? 'a_last_read' : 'b_last_read';
            DB::run("UPDATE community_conversations SET last_message_id = :i, last_message_at = :n, $mine = :i2 WHERE id = :c",
                ['i' => $id, 'i2' => $id, 'n' => $now, 'c' => (int)$conv['id']]);
            return $id;
        });
        if ((int)self::settings((int)$conv['other'])['notify_dm'] === 1) {
            self::notify((int)$conv['other'], 'dm', 'New private message from ' . self::user($me)['name'] . ': ' . self::excerpt($body ?: '(file)', 80),
                url('comm.chat', ['dm' => (int)$conv['id']]), 'dm:' . (int)$conv['id'], $me);
        }
        return $id;
    }

    public static function dmMessage(int $id): ?array
    {
        return DB::row('SELECT * FROM community_dm_messages WHERE id = :id', ['id' => $id]);
    }

    public static function editDm(int $id, string $body): void
    {
        $m = self::dmMessage($id);
        if (!$m || (int)$m['sender_id'] !== self::me() || $m['deleted_at'] || !self::conversation((int)$m['conversation_id'])) {
            fail('You can edit only your own messages.');
        }
        $body = self::clean($body);
        if ($body === '') {
            fail('A message cannot be empty. Delete it instead.');
        }
        DB::update('community_dm_messages', ['body' => $body, 'edited_at' => self::now(), 'updated_at' => self::now()], 'id = :id', ['id' => $id]);
    }

    public static function deleteDm(int $id): void
    {
        $m = self::dmMessage($id);
        if (!$m || (int)$m['sender_id'] !== self::me() || $m['deleted_at'] || !self::conversation((int)$m['conversation_id'])) {
            fail('You can delete only your own messages.');
        }
        DB::tx(function () use ($id) {
            DB::update('community_dm_messages', ['body' => null, 'deleted_at' => self::now(), 'updated_at' => self::now()], 'id = :id', ['id' => $id]);
            DB::run("DELETE FROM community_files WHERE owner_type = 'dm' AND owner_id = :id", ['id' => $id]);
        });
    }

    public static function markDmRead(array $conv, int $lastId): void
    {
        $col = (int)$conv['user_a'] === self::me() ? 'a_last_read' : 'b_last_read';
        DB::run("UPDATE community_conversations SET $col = GREATEST($col, :l) WHERE id = :c", ['l' => $lastId, 'c' => (int)$conv['id']]);
        DB::run('UPDATE community_notifications SET is_read = 1 WHERE user_id = :u AND dedupe_key = :k', ['u' => self::me(), 'k' => 'dm:' . (int)$conv['id']]);
    }

    public static function setBlocked(int $other, bool $on): void
    {
        if ($other === self::me()) {
            fail('You cannot block yourself.');
        }
        if ($on) {
            DB::run('INSERT IGNORE INTO community_blocks (user_id, blocked_id, created_at) VALUES (:a, :b, :n)', ['a' => self::me(), 'b' => $other, 'n' => self::now()]);
        } else {
            DB::run('DELETE FROM community_blocks WHERE user_id = :a AND blocked_id = :b', ['a' => self::me(), 'b' => $other]);
        }
    }

    public static function blockedList(): array
    {
        return array_values(self::users(DB::column('SELECT blocked_id FROM community_blocks WHERE user_id = :u ORDER BY created_at DESC', ['u' => self::me()])));
    }

    // ================================================================== notifications

    /**
     * One notification per thing ($dedupe): a second one for the same thing (a new private message in the same
     * conversation, another answer to the same question) refreshes it and makes it unread again, never a duplicate.
     */
    public static function notify(int $uid, string $kind, string $text, string $link, string $dedupe, ?int $actor = null): void
    {
        if ($uid <= 0 || $uid === (int)$actor) {
            return;
        }
        DB::run('INSERT INTO community_notifications (user_id, kind, actor_id, text, url, dedupe_key, is_read, created_at)
                 VALUES (:u, :k, :a, :t, :l, :d, 0, :n)
                 ON DUPLICATE KEY UPDATE kind = VALUES(kind), actor_id = VALUES(actor_id), text = VALUES(text), url = VALUES(url), is_read = 0, created_at = VALUES(created_at)',
            ['u' => $uid, 'k' => $kind, 'a' => $actor, 't' => mb_substr($text, 0, 250), 'l' => mb_substr($link, 0, 250), 'd' => mb_substr($dedupe, 0, 80), 'n' => self::now()]);
    }

    public static function unreadNotifications(): int
    {
        return (int)DB::value('SELECT COUNT(*) FROM community_notifications WHERE user_id = :u AND is_read = 0', ['u' => self::me()]);
    }

    public static function notifications(int $limit = 20): array
    {
        $rows = DB::all('SELECT * FROM community_notifications WHERE user_id = :u ORDER BY is_read, created_at DESC, id DESC LIMIT ' . (int)$limit, ['u' => self::me()]);
        $users = self::users(array_column($rows, 'actor_id'));
        return array_map(fn($r) => ['id' => (int)$r['id'], 'kind' => $r['kind'], 'text' => $r['text'], 'url' => url('comm.api', ['a' => 'go', 'n' => (int)$r['id']]),
            'read' => (int)$r['is_read'] === 1, 'ago' => self::ago($r['created_at']), 'user' => $r['actor_id'] ? ($users[(int)$r['actor_id']] ?? null) : null], $rows);
    }

    public static function readNotification(?int $id): ?string
    {
        if ($id === null) {
            DB::run('UPDATE community_notifications SET is_read = 1 WHERE user_id = :u AND is_read = 0', ['u' => self::me()]);
            return null;
        }
        $n = DB::row('SELECT * FROM community_notifications WHERE id = :id AND user_id = :u', ['id' => $id, 'u' => self::me()]);
        if (!$n) {
            return null;
        }
        DB::run('UPDATE community_notifications SET is_read = 1 WHERE id = :id', ['id' => $id]);
        return (string)$n['url'];
    }

    public static function ago(string $at): string
    {
        $s = max(0, time() - strtotime($at));
        if ($s < 60) {
            return 'just now';
        }
        if ($s < 3600) {
            return floor($s / 60) . ' min ago';
        }
        if ($s < 86400) {
            $hrs = (int)floor($s / 3600);
            return $hrs . ' hour' . ($hrs === 1 ? '' : 's') . ' ago';
        }
        if ($s < 604800) {
            $d = (int)floor($s / 86400);
            return $d === 1 ? 'yesterday' : $d . ' days ago';
        }
        return fdate($at);
    }

    // ================================================================== files

    public static function maxFile(): int
    {
        return max(1, min(self::MAX_FILE, Attachments::iniBytes('upload_max_filesize') ?: self::MAX_FILE, Attachments::iniBytes('post_max_size') ?: self::MAX_FILE));
    }

    public static function size(int $b): string
    {
        return Attachments::size($b);
    }

    public static function allowedExt(): array
    {
        return array_keys(self::FILE_EXT);
    }

    /** Keeps an uploaded file as 'pending' (not yet on a message) and returns its id */
    public static function storeUpload(string $tmp, string $name, string $ownerType = 'pending'): int
    {
        $name = Attachments::cleanName($name);
        $ext = Attachments::ext($name);
        if (!isset(self::FILE_EXT[$ext])) {
            fail('"' . $name . '" cannot be attached here. Allowed: pictures (' . implode(', ', self::IMAGES) . '), PDF, Word, Excel, PowerPoint, CSV, text and ZIP files.');
        }
        $size = (int)@filesize($tmp);
        if ($size <= 0) {
            fail('"' . $name . '" is empty.');
        }
        if ($size > self::maxFile()) {
            fail('"' . $name . '" is larger than ' . self::size(self::maxFile()) . '.');
        }
        $isImage = in_array($ext, self::IMAGES, true);
        if ($isImage && !@getimagesize($tmp)) {
            fail('"' . $name . '" is not a picture that can be shown.');
        }
        if (!$isImage && $ext === 'pdf' && file_get_contents($tmp, false, null, 0, 5) !== '%PDF-') {
            fail('"' . $name . '" is not a PDF file.');
        }
        if ($ownerType === 'pending' && (int)DB::value("SELECT COUNT(*) FROM community_files WHERE user_id = :u AND owner_type = 'pending' AND created_at >= :t",
                ['u' => self::me(), 't' => date('Y-m-d H:i:s', time() - 600)]) >= 30) {
            fail('Too many files uploaded in a short time. Send what you have first.');
        }
        $fh = fopen($tmp, 'rb');
        return DB::tx(function () use ($fh, $name, $ext, $size, $isImage, $ownerType) {
            $id = (int)DB::insert('community_files', ['owner_type' => $ownerType, 'owner_id' => null, 'user_id' => self::me(), 'file_name' => $name,
                'mime_type' => self::FILE_EXT[$ext], 'file_size' => $size, 'is_image' => $isImage ? 1 : 0, 'created_at' => self::now()]);
            $seq = 0;
            while (!feof($fh)) {
                $data = fread($fh, self::CHUNK);
                if ($data === false || $data === '') {
                    break;
                }
                DB::run('INSERT INTO community_file_chunks (file_id, seq, data) VALUES (:f, :s, UNHEX(:d))', ['f' => $id, 's' => $seq++, 'd' => bin2hex($data)]);
            }
            fclose($fh);
            DB::update('community_files', ['chunks' => $seq], 'id = :id', ['id' => $id]);
            return $id;
        });
    }

    /** The uploaded files of the request (field "files[]"), stored as pending: [ids, problems] */
    public static function takeUploads(string $field = 'files'): array
    {
        $ids = [];
        $problems = [];
        $f = $_FILES[$field] ?? null;
        if (!is_array($f) || !isset($f['name'])) {
            return [$ids, $problems];
        }
        foreach ((array)$f['name'] as $i => $name) {
            $err = (int)((array)$f['error'])[$i];
            if ($err === UPLOAD_ERR_NO_FILE || (string)$name === '') {
                continue;
            }
            if ($err !== UPLOAD_ERR_OK) {
                $problems[] = '"' . $name . '" ' . ($err === UPLOAD_ERR_INI_SIZE || $err === UPLOAD_ERR_FORM_SIZE ? 'is larger than ' . self::size(self::maxFile()) . '.' : 'did not arrive in full.');
                continue;
            }
            $tmp = (string)((array)$f['tmp_name'])[$i];
            if (!is_uploaded_file($tmp)) {
                continue;
            }
            try {
                $ids[] = self::storeUpload($tmp, (string)$name);
            } catch (UserError $e) {
                $problems[] = $e->getMessage();
            }
        }
        return [$ids, $problems];
    }

    /** The ids that are this user's pending files (at most MAX_FILES) */
    public static function ownPending(array $ids): array
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        if (!$ids) {
            return [];
        }
        if (count($ids) > self::MAX_FILES) {
            fail('Attach at most ' . self::MAX_FILES . ' files to one message.');
        }
        [$in, $p] = DB::in('f', $ids);
        return array_map('intval', DB::column("SELECT id FROM community_files WHERE id IN $in AND user_id = :u AND owner_type = 'pending'", $p + ['u' => self::me()]));
    }

    public static function claimFiles(array $ids, string $type, int $ownerId): void
    {
        if (!$ids) {
            return;
        }
        [$in, $p] = DB::in('f', $ids);
        DB::run("UPDATE community_files SET owner_type = :t, owner_id = :o WHERE id IN $in AND user_id = :u AND owner_type = 'pending'", $p + ['t' => $type, 'o' => $ownerId, 'u' => self::me()]);
        if (random_int(1, 20) === 1) {
            DB::run("DELETE FROM community_files WHERE owner_type = 'pending' AND created_at < :t", ['t' => date('Y-m-d H:i:s', time() - 86400)]);
        }
    }

    public static function files(string $type, array $ownerIds): array
    {
        $ownerIds = array_values(array_filter(array_map('intval', $ownerIds)));
        if (!$ownerIds) {
            return [];
        }
        [$in, $p] = DB::in('o', $ownerIds);
        $out = [];
        foreach (DB::all("SELECT id, owner_id, file_name, file_size, is_image FROM community_files WHERE owner_type = :t AND owner_id IN $in ORDER BY id", $p + ['t' => $type]) as $f) {
            $out[(int)$f['owner_id']][] = $f;
        }
        return $out;
    }

    /** Whether the user may open a file */
    public static function canOpenFile(array $f): bool
    {
        $me = self::me();
        switch ($f['owner_type']) {
            case 'pending':
                return (int)$f['user_id'] === $me;
            case 'avatar':
                return Access::page('comm.chat') || Access::page('comm.inquiries');
            case 'message':
                $m = self::message((int)$f['owner_id']);
                $c = $m ? self::channel((int)$m['channel_id']) : null;
                return $m && $c && !$m['deleted_at'] && self::canSeeChannel($c) && ((int)$m['is_hidden'] === 0 || self::isMod() || (int)$m['user_id'] === $me);
            case 'dm':
                $m = self::dmMessage((int)$f['owner_id']);
                return $m && !$m['deleted_at'] && self::conversation((int)$m['conversation_id']) !== null;
            case 'inquiry':
                $q = Inquiries::find((int)$f['owner_id']);
                return $q && Inquiries::canSee($q);
            case 'response':
                $r = DB::row('SELECT * FROM community_inquiry_responses WHERE id = :id', ['id' => (int)$f['owner_id']]);
                $q = $r ? Inquiries::find((int)$r['inquiry_id']) : null;
                return $r && $q && !$r['deleted_at'] && Inquiries::canSee($q) && ((int)$r['is_hidden'] === 0 || self::isMod() || (int)$r['user_id'] === $me);
        }
        return false;
    }

    public static function sendFile(array $f, bool $inline): never
    {
        @set_time_limit(0);
        $inline = $inline && ((int)$f['is_image'] === 1 || $f['mime_type'] === 'application/pdf');
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        $name = (string)$f['file_name'];
        $ascii = preg_replace('/[^A-Za-z0-9._ -]+/', '_', $name) ?: 'file';
        header('Content-Type: ' . ($f['mime_type'] ?: 'application/octet-stream'));
        header('Content-Disposition: ' . ($inline || $f['owner_type'] === 'avatar' ? 'inline' : 'attachment') . '; filename="' . str_replace('"', '', $ascii) . '"; filename*=UTF-8\'\'' . rawurlencode($name));
        header('Content-Length: ' . (int)$f['file_size']);
        header('X-Content-Type-Options: nosniff');
        header("Content-Security-Policy: default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; sandbox");
        header('Cache-Control: private, max-age=' . ($f['owner_type'] === 'avatar' ? '86400' : '3600'));
        for ($i = 0; $i < (int)$f['chunks']; $i++) {
            echo (string)DB::value('SELECT data FROM community_file_chunks WHERE file_id = :f AND seq = :s', ['f' => (int)$f['id'], 's' => $i]);
            flush();
        }
        exit;
    }

    // ================================================================== reports, sanctions, the log

    public static function report(string $type, int $id, string $reason, string $details): void
    {
        if (!isset(self::REPORT_REASONS[$reason])) {
            fail('Choose a reason for the report.');
        }
        $me = self::me();
        if ((int)DB::value('SELECT COUNT(*) FROM community_reports WHERE reporter_id = :u AND created_at >= :t', ['u' => $me, 't' => date('Y-m-d H:i:s', time() - 86400)]) >= 20) {
            fail('You have sent many reports today. A moderator will look at them; try again tomorrow.');
        }
        $snapshot = '';
        $target = null;
        switch ($type) {
            case 'message':
                $m = self::message($id);
                $c = $m ? self::channel((int)$m['channel_id']) : null;
                if (!$m || !$c || !self::canSeeChannel($c) || $m['deleted_at']) {
                    fail('The message was not found.');
                }
                $target = (int)$m['user_id'];
                $snapshot = 'In ' . $c['name'] . ', ' . fdatetime($m['created_at']) . ":\n" . $m['body'];
                break;
            case 'dm':
                $m = self::dmMessage($id);
                $conv = $m ? self::conversation((int)$m['conversation_id']) : null;
                if (!$m || !$conv || (int)$m['sender_id'] === $me || $m['deleted_at']) {
                    fail('The message was not found.');
                }
                $target = (int)$m['sender_id'];
                $snapshot = 'Private message to ' . self::user($me)['name'] . ', ' . fdatetime($m['created_at']) . ":\n" . $m['body'];
                break;
            case 'inquiry':
                $q = Inquiries::find($id);
                if (!$q || !Inquiries::canSee($q)) {
                    fail('The inquiry was not found.');
                }
                $target = (int)$q['user_id'];
                $snapshot = 'Inquiry "' . $q['title'] . '":' . "\n" . $q['body'];
                break;
            case 'response':
                $r = DB::row('SELECT * FROM community_inquiry_responses WHERE id = :id', ['id' => $id]);
                $q = $r ? Inquiries::find((int)$r['inquiry_id']) : null;
                if (!$r || !$q || !Inquiries::canSee($q) || $r['deleted_at']) {
                    fail('The response was not found.');
                }
                $target = (int)$r['user_id'];
                $snapshot = 'Response to "' . $q['title'] . '":' . "\n" . $r['body'];
                break;
            case 'user':
                if (!DB::value('SELECT 1 FROM users WHERE id = :id', ['id' => $id])) {
                    fail('The user was not found.');
                }
                $target = $id;
                $snapshot = 'Report about ' . self::user($id)['name'];
                break;
            default:
                fail('That cannot be reported.');
        }
        if ($target === $me) {
            fail('You cannot report yourself.');
        }
        if (DB::value("SELECT 1 FROM community_reports WHERE reporter_id = :u AND target_type = :t AND target_id = :i AND status = 'open'", ['u' => $me, 't' => $type, 'i' => $id])) {
            fail('You have already reported this. A moderator will look at it.');
        }
        DB::insert('community_reports', ['reporter_id' => $me, 'target_type' => $type, 'target_id' => $id, 'target_user_id' => $target,
            'reason' => $reason, 'details' => mb_substr(trim($details), 0, 500) ?: null, 'snapshot' => mb_substr($snapshot, 0, 5000), 'created_at' => self::now()]);
    }

    public static function handleReport(int $id, string $status, string $note): array
    {
        if (!self::canModerate()) {
            fail('Only moderators handle reports.');
        }
        $r = DB::row('SELECT * FROM community_reports WHERE id = :id', ['id' => $id]);
        if (!$r) {
            fail('The report was not found.');
        }
        DB::update('community_reports', ['status' => $status, 'handled_by' => self::me(), 'handled_at' => self::now(), 'resolution' => mb_substr($note, 0, 255) ?: null],
            'id = :id', ['id' => $id]);
        self::log('report_' . $status, 'report', $id, (int)$r['target_user_id'], $note, self::REPORT_REASONS[$r['reason']] ?? $r['reason']);
        return $r;
    }

    public static function sanctionUser(int $uid, string $kind, string $reason, ?string $until): void
    {
        if (!self::canSanction()) {
            fail('Only moderators with the Delete right on Community Management mute or suspend users.');
        }
        if (!in_array($kind, ['mute', 'suspend'], true)) {
            fail('Choose mute or suspend.');
        }
        if (trim($reason) === '') {
            fail('Give the reason; the user sees it.');
        }
        if ($uid === self::me()) {
            fail('You cannot mute or suspend yourself.');
        }
        if (Access::isAdmin($uid) || Tenant::hasAuthority($uid)) {
            fail('Administrators and the Company Owner cannot be muted or suspended.');
        }
        DB::insert('community_sanctions', ['user_id' => $uid, 'kind' => $kind, 'reason' => mb_substr(trim($reason), 0, 255), 'ends_at' => $until,
            'created_by' => self::me(), 'created_at' => self::now()]);
        self::log($kind, 'user', $uid, $uid, $reason, $until ? 'Until ' . $until : 'Until lifted');
    }

    public static function liftSanction(int $id): void
    {
        if (!self::canSanction()) {
            fail('Only moderators with the Delete right lift mutes and suspensions.');
        }
        $s = DB::row('SELECT * FROM community_sanctions WHERE id = :id AND lifted_at IS NULL', ['id' => $id]);
        if (!$s) {
            fail('Nothing to lift.');
        }
        DB::update('community_sanctions', ['lifted_by' => self::me(), 'lifted_at' => self::now()], 'id = :id', ['id' => $id]);
        self::log('lift_' . $s['kind'], 'user', (int)$s['user_id'], (int)$s['user_id'], '', $s['reason']);
    }

    /** The moderation log, and the system's audit trail */
    public static function log(string $action, string $type, ?int $id, ?int $targetUser, string $reason = '', string $detail = ''): void
    {
        DB::insert('community_mod_log', ['moderator_id' => self::me(), 'action' => $action, 'target_type' => $type, 'target_id' => $id,
            'target_user_id' => $targetUser, 'reason' => mb_substr($reason, 0, 255) ?: null, 'detail' => $detail !== '' ? mb_substr($detail, 0, 5000) : null, 'created_at' => self::now()]);
        Audit::log('community_' . substr($action, 0, 20), 'comm', $type, $id, ucfirst($type) . ($id ? ' #' . $id : '') . ($targetUser ? ' of ' . self::user($targetUser)['name'] : ''),
            ['page_key' => 'comm.manage', 'reason' => mb_substr(trim($reason . ($detail !== '' ? ' | ' . $detail : '')), 0, 255) ?: null]);
    }

    public static function logActions(): array
    {
        return ['hide' => 'Hid a post', 'unhide' => 'Showed a post again', 'delete_message' => 'Deleted a message', 'delete_response' => 'Deleted a response',
            'delete_inquiry' => 'Deleted an inquiry', 'pin' => 'Pinned a message', 'unpin' => 'Unpinned a message', 'mute' => 'Muted a user', 'suspend' => 'Suspended a user',
            'lift_mute' => 'Lifted a mute', 'lift_suspend' => 'Lifted a suspension', 'report_actioned' => 'Closed a report (action taken)',
            'report_dismissed' => 'Dismissed a report', 'channel_create' => 'Created a channel', 'channel_edit' => 'Changed a channel',
            'channel_archive' => 'Archived a channel', 'channel_restore' => 'Restored a channel', 'category_create' => 'Added a category',
            'category_edit' => 'Changed a category', 'announce' => 'Published an announcement', 'inquiry_status' => 'Changed an inquiry\'s status',
            'accept' => 'Accepted an answer'];
    }
}
