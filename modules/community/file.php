<?php
declare(strict_types=1);

/**
 * v41: a file of the Community (a picture or document on a message, a private message, an inquiry or a response, or
 * a user's picture): index.php?p=comm.file&id=N (&view=1 shows a picture or a PDF in the tab). Sent only to a user
 * who may see what it is attached to; a file of a private message only to the two people in the conversation.
 */
if (!Community::ready()) {
    http_response_code(404);
    exit;
}
session_write_close();
$f = DB::row('SELECT * FROM community_files WHERE id = :id', ['id' => (int)g('id')]);
if (!$f || Community::suspended() || !Community::canOpenFile($f)) {
    http_response_code($f ? 403 : 404);
    header('Content-Type: text/plain; charset=utf-8');
    exit($f ? 'You may not open this file.' : 'The file was not found. It may have been removed.');
}
Community::sendFile($f, g('view') === '1');
