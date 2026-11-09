<?php
// The notes API in plain PHP: one front controller, PDO, prepared statements.
function reply(int $status, array $data): never {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

$db = new PDO('sqlite:' . getenv('SQLITE_PATH'));
$db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
const NOTE = 'SELECT n.id, u.username AS author, n.body, n.created_at FROM notes n JOIN users u ON u.id = n.user_id';

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if ($method === 'GET' && $path === '/health') {
    reply(200, ['status' => 'ok']);
}
if ($method === 'GET' && $path === '/notes') {
    reply(200, ['notes' => $db->query(NOTE . ' ORDER BY n.id DESC LIMIT 20')->fetchAll()]);
}
if ($method === 'GET' && preg_match('#^/notes/([^/]+)$#', $path, $m)) {
    if (!preg_match('/^[1-9][0-9]*$/', $m[1])) reply(400, ['error' => 'invalid id']);
    $q = $db->prepare(NOTE . ' WHERE n.id = ?');
    $q->execute([(int) $m[1]]);
    $note = $q->fetch();
    if (!$note) reply(404, ['error' => 'not found']);
    reply(200, ['note' => $note]);
}
if ($method === 'POST' && $path === '/notes') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $user = false;
    if (str_starts_with($auth, 'Bearer ')) {
        $q = $db->prepare('SELECT id, username FROM users WHERE token = ?');
        $q->execute([substr($auth, 7)]);
        $user = $q->fetch();
    }
    if (!$user) reply(401, ['error' => 'unauthorized']);
    $data = json_decode(file_get_contents('php://input'), true);
    if (json_last_error() !== JSON_ERROR_NONE) reply(400, ['error' => 'bad json']);
    $body = is_array($data) && is_string($data['body'] ?? null) ? trim($data['body']) : '';
    if ($body === '' || mb_strlen($body, 'UTF-8') > 500) reply(400, ['error' => 'invalid body']);
    $q = $db->prepare('INSERT INTO notes (user_id, body) VALUES (?, ?) RETURNING id, created_at');
    $q->execute([$user['id'], $body]);
    $row = $q->fetch();
    $q->closeCursor();  // step the statement to the end, so the row is committed before the 201
    reply(201, ['note' => ['id' => $row['id'], 'author' => $user['username'], 'body' => $body, 'created_at' => $row['created_at']]]);
}
reply(404, ['error' => 'not found']);
