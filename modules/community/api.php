<?php
declare(strict_types=1);

/**
 * v41: the Community's requests from the page (JSON), index.php?p=comm.api&a=...
 * Every action checks the user's rights itself. Polling requests carry the header X-Background: 1, so they do not
 * keep an idle session alive (the session time-out still logs out a user who has walked away).
 *
 *   GET  boot         channels, conversations, the first messages of the channel or conversation opened
 *   GET  poll         what is new since the last poll: messages, changes, unread counts, notifications
 *   GET  older        earlier messages
 *   GET  pinned       the pinned messages of a channel
 *   GET  search       messages of a channel matching text / person / files / pins / mentions
 *   GET  users        people for @mentions and for a new private message
 *   GET  badge        the unread notifications (the top bar)
 *   GET  notifications, go (open a notification), similar (inquiries like a title)
 *   POST send, edit, delete, react, pin, hide, upload, read, report, dm_start, block, notif_read, settings
 */
if (!Community::ready()) {
    json_out(['ok' => false, 'error' => 'Run database/migrations/2027_02_04_community.sql first.'], 503);
}
$a = (string)g('a');
$me = Community::me();
$canChat = Access::page('comm.chat');
$canInq = Access::page('comm.inquiries');

// "go": open a notification (a link, not JSON)
if ($a === 'go') {
    $to = Community::readNotification((int)g('n'));
    redirect($to ?: url($canChat ? 'comm.chat' : 'home.dashboard'));
}

// nothing here needs the session after this point: let other requests of the same user run at the same time
session_write_close();

if (!$canChat && !$canInq) {
    json_out(['ok' => false, 'error' => 'You do not have access to the Community.'], 403);
}
if (Community::suspended()) {
    json_out(['ok' => false, 'error' => Community::sanctionText(Community::sanction()) . '.', 'suspended' => true], 403);
}

/** the channel of the request, checked */
$channelOf = function (int $id): array {
    $c = $id ? Community::channel($id) : null;
    if (!$c || !Community::canSeeChannel($c)) {
        json_out(['ok' => false, 'error' => 'This channel is not available to you.'], 403);
    }
    return $c;
};
/** the conversation of the request, checked: only one of its two people */
$convOf = function (int $id): array {
    $c = $id ? Community::conversation($id) : null;
    if (!$c) {
        json_out(['ok' => false, 'error' => 'Conversation not found.'], 404);
    }
    return $c;
};
$channelInfo = function (array $c, array $unread): array {
    return ['id' => (int)$c['id'], 'slug' => $c['slug'], 'name' => $c['name'], 'description' => (string)$c['description'], 'kind' => $c['kind'],
        'archived' => (int)$c['is_archived'] === 1, 'restricted' => (int)$c['is_restricted'] === 1, 'unread' => $unread[(int)$c['id']] ?? 0,
        'can_post' => Community::canPostIn($c), 'mods_only' => $c['post_policy'] === 'moderators'];
};

try {
    if (in_array($a, ['boot', 'poll', 'older', 'pinned', 'search', 'send', 'edit', 'delete', 'react', 'pin', 'hide', 'read', 'dm_start', 'block'], true) && !$canChat) {
        json_out(['ok' => false, 'error' => 'You do not have access to Community Chat.'], 403);
    }
    if (in_array($a, ['send', 'edit', 'delete', 'react', 'pin', 'hide', 'upload', 'read', 'report', 'dm_start', 'block', 'notif_read', 'settings'], true) && !is_post()) {
        json_out(['ok' => false, 'error' => 'Send this as a form.'], 405);
    }

    switch ($a) {
        case 'boot': {
            Community::touch();
            $chs = Community::channels(true);
            Community::join(array_filter($chs, fn($c) => (int)$c['is_archived'] === 0));
            $unread = Community::unreadChannels();
            $out = ['ok' => true, 'now' => Community::now(), 'me' => Community::user($me) + ['mod' => Community::isMod()],
                'rights' => ['post' => Access::can('comm.chat', 'create') && !Community::muted(), 'moderate' => Community::canModerate(), 'sanction' => Community::canSanction()],
                'sanction' => ($s = Community::sanction()) ? Community::sanctionText($s) : '',
                'channels' => array_map(fn($c) => $channelInfo($c, $unread), $chs), 'dms' => Community::conversations(),
                'notif' => Community::unreadNotifications(), 'online' => Community::online(), 'reactions' => Community::REACTIONS,
                'reasons' => Community::REPORT_REASONS, 'max_file' => Community::maxFile(), 'max_files' => Community::MAX_FILES, 'exts' => Community::allowedExt(),
                'settings' => Community::settings(), 'blocked' => Community::blockedList()];
            if ($dm = (int)g('dm')) {
                $conv = $convOf($dm);
                $msgs = Community::dmMessages($dm);
                $out['view'] = ['type' => 'dm', 'id' => $dm, 'user' => Community::user((int)$conv['other']), 'messages' => $msgs, 'their_read' => (int)$conv['their_read'],
                    'refusal' => Community::dmRefusal((int)$conv['other']), 'blocked' => Community::iBlocked((int)$conv['other']), 'more' => count($msgs) >= 40];
            } else {
                $c = null;
                if (($slug = (string)g('ch')) !== '') {
                    $c = Community::channelBySlug($slug);
                }
                if (!$c || !Community::canSeeChannel($c)) {
                    $c = null;
                    foreach ($chs as $x) {
                        if ((int)$x['is_archived'] === 0) {
                            $c = $x;
                            break;
                        }
                    }
                }
                if ($c) {
                    $focus = (int)g('m');
                    $msgs = Community::messages((int)$c['id']);
                    if ($focus && !in_array($focus, array_column($msgs, 'id'), true)) {
                        // a linked message older than the last 40: open from it
                        $msgs = array_merge(Community::messages((int)$c['id'], null, $focus + 1, 10), Community::messages((int)$c['id'], $focus, null, 30));
                    }
                    $out['view'] = ['type' => 'channel', 'id' => (int)$c['id'], 'channel' => $channelInfo($c, $unread), 'messages' => $msgs,
                        'pinned' => Community::pinned((int)$c['id']), 'more' => count($msgs) >= 40 || $focus > 0, 'focus' => $focus];
                }
            }
            json_out($out);
        }

        case 'poll': {
            Community::touch();
            $since = preg_match('/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/', (string)g('since')) ? (string)g('since') : Community::now();
            $after = (int)g('after');
            $out = ['ok' => true, 'now' => Community::now(), 'notif' => Community::unreadNotifications(), 'counts' => (object)Community::unreadChannels(), 'dms' => Community::conversations()];
            if ($ch = (int)g('ch')) {
                $c = $channelOf($ch);
                $out['messages'] = Community::messages((int)$c['id'], $after, null, 100);
                $out['changed'] = $after ? Community::changed((int)$c['id'], $since, $after) : [];
                $out['channel'] = $channelInfo($c, []);
                if (array_filter($out['changed'], fn($m) => true)) {
                    $out['pinned'] = Community::pinned((int)$c['id']);
                }
            } elseif ($dm = (int)g('dm')) {
                $conv = $convOf($dm);
                $out['messages'] = Community::dmMessages($dm, $after, null, 100);
                $out['changed'] = $after ? Community::dmChanged($dm, $since, $after) : [];
                $out['their_read'] = (int)$conv['their_read'];
            }
            if (g('online') === '1') {
                $out['online'] = Community::online();
            }
            json_out($out);
        }

        case 'older': {
            $before = (int)g('before');
            if ($dm = (int)g('dm')) {
                $convOf($dm);
                $msgs = Community::dmMessages($dm, null, $before);
            } else {
                $c = $channelOf((int)g('ch'));
                $msgs = Community::messages((int)$c['id'], null, $before);
            }
            json_out(['ok' => true, 'messages' => $msgs, 'more' => count($msgs) >= 40]);
        }

        case 'pinned': {
            $c = $channelOf((int)g('ch'));
            json_out(['ok' => true, 'pinned' => Community::pinned((int)$c['id'])]);
        }

        case 'search': {
            $c = $channelOf((int)g('ch'));
            json_out(['ok' => true, 'messages' => Community::search((int)$c['id'], (string)g('q'), (int)g('from'), (string)g('has'))]);
        }

        case 'users': {
            $users = Community::findUsers((string)g('q'));
            if (g('for') === 'dm') {
                $users = array_map(fn($u) => $u + ['refusal' => Community::dmRefusal($u['id'])], array_values(array_filter($users, fn($u) => $u['id'] !== $me)));
            }
            json_out(['ok' => true, 'users' => $users]);
        }

        case 'send': {
            $files = array_map('intval', (array)($_POST['files'] ?? []));
            $key = Community::clientKey(p('key'));
            $reply = (int)p('reply') ?: null;
            if ($dm = (int)p('dm')) {
                $conv = $convOf($dm);
                $id = Community::sendDm($conv, (string)p('body'), $reply, $key, $files);
                $row = DB::row('SELECT * FROM community_dm_messages WHERE id = :id', ['id' => $id]);
                json_out(['ok' => true, 'message' => Community::shape([$row], 'dm')[0]]);
            }
            $c = $channelOf((int)p('ch'));
            $id = Community::post($c, (string)p('body'), $reply, $key, $files);
            json_out(['ok' => true, 'message' => Community::messages((int)$c['id'], $id - 1, null, 1)[0] ?? null]);
        }

        case 'edit': {
            $id = (int)p('id');
            if (p('scope') === 'dm') {
                Community::editDm($id, (string)p('body'));
                $row = Community::dmMessage($id);
                json_out(['ok' => true, 'message' => Community::shape([$row], 'dm')[0]]);
            }
            $m = Community::message($id);
            $m && $channelOf((int)$m['channel_id']);
            Community::edit($id, (string)p('body'));
            json_out(['ok' => true, 'message' => Community::shape([Community::message($id)], 'message')[0]]);
        }

        case 'delete': {
            $id = (int)p('id');
            if (p('scope') === 'dm') {
                Community::deleteDm($id);
                json_out(['ok' => true, 'message' => Community::shape([Community::dmMessage($id)], 'dm')[0]]);
            }
            $m = Community::message($id);
            $m && $channelOf((int)$m['channel_id']);
            Community::delete($id, (string)p('reason'));
            json_out(['ok' => true, 'message' => Community::shape([Community::message($id)], 'message')[0]]);
        }

        case 'react': {
            $id = (int)p('id');
            Community::react($id, (string)p('emoji'));
            json_out(['ok' => true, 'message' => Community::shape([Community::message($id)], 'message')[0]]);
        }

        case 'pin': {
            $id = (int)p('id');
            $m = Community::message($id);
            $m && $channelOf((int)$m['channel_id']);
            Community::setPinned($id, p('on') === '1');
            json_out(['ok' => true, 'message' => Community::shape([Community::message($id)], 'message')[0], 'pinned' => $m ? Community::pinned((int)$m['channel_id']) : []]);
        }

        case 'hide': {
            $id = (int)p('id');
            $m = Community::message($id);
            $m && $channelOf((int)$m['channel_id']);
            Community::setHidden('message', $id, p('on') === '1', (string)p('reason'));
            json_out(['ok' => true, 'message' => Community::shape([Community::message($id)], 'message')[0]]);
        }

        case 'upload': {
            if (!Access::can('comm.chat', 'create') && !Access::can('comm.inquiries', 'create')) {
                json_out(['ok' => false, 'error' => 'Your role may not post in the community.'], 403);
            }
            [$ids, $problems] = Community::takeUploads('files');
            $rows = [];
            if ($ids) {
                [$in, $pp] = DB::in('f', $ids);
                foreach (DB::all("SELECT id, file_name, file_size, is_image FROM community_files WHERE id IN $in", $pp) as $f) {
                    $rows[] = ['id' => (int)$f['id'], 'name' => $f['file_name'], 'size' => Community::size((int)$f['file_size']), 'image' => (int)$f['is_image'] === 1,
                        'url' => url('comm.file', ['id' => (int)$f['id'], 'view' => 1])];
                }
            }
            json_out(['ok' => (bool)$rows || !$problems, 'files' => $rows, 'problems' => $problems, 'error' => $problems ? implode(' ', $problems) : '']);
        }

        case 'read': {
            if ($dm = (int)p('dm')) {
                Community::markDmRead($convOf($dm), (int)p('last'));
            } else {
                $c = $channelOf((int)p('ch'));
                Community::markChannelRead((int)$c['id'], (int)p('last'));
                DB::run("UPDATE community_notifications SET is_read = 1 WHERE user_id = :u AND is_read = 0 AND kind IN ('mention', 'reply', 'announcement') AND url LIKE :l",
                    ['u' => $me, 'l' => '%ch=' . $c['slug'] . '%']);
            }
            json_out(['ok' => true, 'notif' => Community::unreadNotifications()]);
        }

        case 'report': {
            Community::report((string)p('type'), (int)p('id'), (string)p('reason'), (string)p('details'));
            json_out(['ok' => true, 'text' => 'Thank you. A moderator will review the report.']);
        }

        case 'dm_start': {
            $conv = Community::conversationWith((int)p('user'));
            json_out(['ok' => true, 'id' => (int)$conv['id']]);
        }

        case 'block': {
            Community::setBlocked((int)p('user'), p('on') === '1');
            json_out(['ok' => true, 'blocked' => Community::blockedList()]);
        }

        case 'badge':
            json_out(['ok' => true, 'notif' => Community::unreadNotifications()]);

        case 'notifications':
            json_out(['ok' => true, 'items' => Community::notifications(25), 'notif' => Community::unreadNotifications()]);

        case 'notif_read':
            Community::readNotification(p('id') === 'all' ? null : (int)p('id'));
            json_out(['ok' => true, 'notif' => Community::unreadNotifications()]);

        case 'settings': {
            $v = ['dm_policy' => p('dm_policy'), 'notify_mentions' => p('notify_mentions') === '1', 'notify_dm' => p('notify_dm') === '1',
                'notify_announcements' => p('notify_announcements') === '1', 'notify_inquiries' => p('notify_inquiries') === '1'];
            if (p('remove_avatar') === '1') {
                $old = Community::settings()['avatar_file_id'];
                $v['avatar_file_id'] = null;
                if ($old) {
                    DB::run("DELETE FROM community_files WHERE id = :id AND owner_type = 'avatar' AND user_id = :u", ['id' => (int)$old, 'u' => $me]);
                }
            }
            $f = $_FILES['avatar'] ?? null;
            if (is_array($f) && (int)($f['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE) {
                if ((int)$f['error'] !== UPLOAD_ERR_OK || !is_uploaded_file((string)$f['tmp_name'])) {
                    fail('The picture did not arrive. Try a smaller one.');
                }
                if (!in_array(Attachments::ext((string)$f['name']), ['jpg', 'jpeg', 'png', 'gif', 'webp'], true)) {
                    fail('Choose a JPG, PNG, GIF or WebP picture.');
                }
                $old = Community::settings()['avatar_file_id'];
                $v['avatar_file_id'] = Community::storeUpload((string)$f['tmp_name'], (string)$f['name'], 'avatar');
                if ($old) {
                    DB::run("DELETE FROM community_files WHERE id = :id AND owner_type = 'avatar' AND user_id = :u", ['id' => (int)$old, 'u' => $me]);
                }
            }
            Community::saveSettings($v);
            json_out(['ok' => true, 'settings' => Community::settings(), 'me' => Community::user($me)]);
        }

        case 'similar':
            json_out(['ok' => true, 'items' => array_map(fn($q) => ['id' => (int)$q['id'], 'title' => $q['title'], 'status' => Community::STATUSES[$q['status']] ?? $q['status'],
                'responses' => (int)$q['response_count'], 'url' => url('comm.inquiries', ['id' => (int)$q['id']])], Inquiries::similar((string)g('q')))]);

        case 'inq_poll': {
            $q = Inquiries::find((int)g('id'));
            if (!$q || !Inquiries::canSee($q)) {
                json_out(['ok' => false, 'error' => 'Not found.'], 404);
            }
            json_out(['ok' => true, 'count' => (int)DB::value('SELECT COUNT(*) FROM community_inquiry_responses WHERE inquiry_id = :i AND deleted_at IS NULL', ['i' => (int)$q['id']]),
                'status' => $q['status'], 'notif' => Community::unreadNotifications()]);
        }
    }
    json_out(['ok' => false, 'error' => 'Unknown request.'], 400);
} catch (UserError $e) {
    if (DB::inTransaction()) {
        DB::rollBack();
    }
    json_out(['ok' => false, 'error' => $e->getMessage()], 422);
}
