<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE, PUT");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

function getConn() {
    static $conn = null;
    if ($conn !== null) return $conn;
    try {
        $conn = new PDO(
            "mysql:host=localhost;dbname=mobileapps_2026B_steve_nsabimana;charset=utf8mb4",
            "steve.nsabimana",
            "Nsabimana2@"
        );
        $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        return $conn;
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'DB connection failed: ' . $e->getMessage()]);
        exit();
    }
}

function setupTables($conn) {
    $conn->exec("CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        displayName VARCHAR(255) NOT NULL,
        currentStreak INT DEFAULT 0,
        booksRead INT DEFAULT 0,
        avatar_url VARCHAR(500) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $conn->exec("CREATE TABLE IF NOT EXISTS books (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        title VARCHAR(500) NOT NULL,
        author VARCHAR(255) NOT NULL,
        status ENUM('want_to_read','currently_reading','finished') DEFAULT 'want_to_read',
        total_pages INT DEFAULT 0,
        current_page INT DEFAULT 0,
        description TEXT,
        thumbnail VARCHAR(500),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $conn->exec("CREATE TABLE IF NOT EXISTS circles (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        creator_id INT NOT NULL,
        book_title VARCHAR(500) DEFAULT '',
        genre VARCHAR(100) DEFAULT 'General',
        is_public TINYINT(1) DEFAULT 1,
        max_members INT DEFAULT 50,
        latitude DECIMAL(10,8),
        longitude DECIMAL(11,8),
        location_name VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $conn->exec("CREATE TABLE IF NOT EXISTS circle_members (
        id INT AUTO_INCREMENT PRIMARY KEY,
        circle_id INT NOT NULL,
        user_id INT NOT NULL,
        joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_circle_user (circle_id, user_id),
        FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $conn->exec("CREATE TABLE IF NOT EXISTS discussions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        circle_id INT NOT NULL,
        user_id INT NOT NULL,
        sender_name VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        image_url VARCHAR(500) DEFAULT NULL,
        reply_to INT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $conn->exec("CREATE TABLE IF NOT EXISTS message_likes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        message_id INT NOT NULL,
        user_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_msg_user (message_id, user_id),
        FOREIGN KEY (message_id) REFERENCES discussions(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $conn->exec("CREATE TABLE IF NOT EXISTS activity_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        actor_name VARCHAR(255) NOT NULL,
        action VARCHAR(100) NOT NULL,
        target VARCHAR(500) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

$conn = getConn();
setupTables($conn);

// Add image_url column to discussions if it doesn't exist yet
// (safe to run every time — catches existing tables created before this column was added)
try {
    $conn->exec("ALTER TABLE discussions ADD COLUMN image_url VARCHAR(500) DEFAULT NULL");
} catch (Exception $e) {
    // Column already exists — ignore
}

$action = $_GET['action'] ?? $_GET['endpoint'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

if ($action === '') {
    $uri   = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    $parts = explode('/', trim($uri, '/'));
    foreach (array_reverse($parts) as $part) {
        $clean = str_replace('.php', '', $part);
        if ($clean !== '' && $clean !== 'index') {
            $action = $clean;
            break;
        }
    }
}

switch ($action) {
    case 'login':            handleLogin($conn);                break;
    case 'register':         handleRegister($conn);             break;
    case 'books':            handleBooks($conn, $method);       break;
    case 'update_progress':  handleUpdateProgress($conn);       break;
    case 'update_streak':    handleUpdateStreak($conn);         break;
    case 'circles':          handleCircles($conn, $method);     break;
    case 'join_circle':      handleJoinCircle($conn);           break;
    case 'leave_circle':     handleLeaveCircle($conn);          break;
    case 'circle_members':   handleCircleMembers($conn);        break;
    case 'discussions':      handleDiscussions($conn, $method); break;
    case 'like_message':     handleLikeMessage($conn);          break;
    case 'activity':         handleActivity($conn);             break;
    case 'users':            handleUsers($conn);                break;
    case 'upload_avatar':    handleUploadAvatar($conn);         break;
    case 'remove_avatar':    handleRemoveAvatar($conn);         break;
    case 'ping':
        echo json_encode(['success'=>true,'status'=>'ReadLoop API is running','time'=>date('Y-m-d H:i:s'),'db'=>'connected']);
        break;
    default:
        echo json_encode(['success'=>true,'status'=>'ReadLoop API running','usage'=>'Add ?action=ENDPOINT to your URL']);
}

// AUTH

function handleLogin($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!isset($data['email'], $data['password'])) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Email and password required']);
        return;
    }
    $stmt = $conn->prepare("SELECT * FROM users WHERE email = :email");
    $stmt->execute([':email' => trim($data['email'])]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($user && password_verify($data['password'], $user['password'])) {
        unset($user['password']);
        echo json_encode(['success' => true, 'user' => $user]);
    } else {
        http_response_code(401);
        echo json_encode(['success'=>false,'error'=>'Invalid email or password']);
    }
}

function handleRegister($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!isset($data['email'], $data['password'], $data['displayName'])) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'All fields required']);
        return;
    }
    if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Invalid email format']);
        return;
    }
    $check = $conn->prepare("SELECT id FROM users WHERE email = :email");
    $check->execute([':email' => trim($data['email'])]);
    if ($check->fetch()) {
        http_response_code(409);
        echo json_encode(['success'=>false,'error'=>'Email already registered']);
        return;
    }
    $hashed = password_hash($data['password'], PASSWORD_DEFAULT);
    $stmt = $conn->prepare("INSERT INTO users (email, password, displayName) VALUES (:email, :password, :displayName)");
    $stmt->execute([':email'=>trim($data['email']),':password'=>$hashed,':displayName'=>$data['displayName']]);
    $userId = $conn->lastInsertId();
    echo json_encode(['success'=>true,'user'=>['id'=>$userId,'email'=>$data['email'],'displayName'=>$data['displayName'],'currentStreak'=>0,'booksRead'=>0]]);
}

function handleUsers($conn) {
    $stmt = $conn->prepare("SELECT id, email, displayName, currentStreak, booksRead, created_at FROM users");
    $stmt->execute();
    echo json_encode(['success'=>true,'users'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

//  BOOKS

function handleBooks($conn, $method) {
    if ($method === 'GET') {
        $userId = $_GET['user_id'] ?? null;
        if (!$userId) { echo json_encode(['success'=>false,'error'=>'user_id required']); return; }
        $stmt = $conn->prepare("SELECT * FROM books WHERE user_id = :uid ORDER BY updated_at DESC");
        $stmt->execute([':uid' => $userId]);
        echo json_encode(['success'=>true,'books'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
    } elseif ($method === 'POST') {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!isset($data['user_id'], $data['title'])) { echo json_encode(['success'=>false,'error'=>'user_id and title required']); return; }
        $stmt = $conn->prepare("INSERT INTO books (user_id, title, author, status, total_pages, current_page, description, thumbnail) VALUES (:uid, :title, :author, :status, :total_pages, :current_page, :description, :thumbnail)");
        $stmt->execute([':uid'=>$data['user_id'],':title'=>$data['title'],':author'=>$data['author']??'',':status'=>$data['status']??'want_to_read',':total_pages'=>intval($data['total_pages']??0),':current_page'=>intval($data['current_page']??0),':description'=>$data['description']??'',':thumbnail'=>$data['thumbnail']??'']);
        $bookId = $conn->lastInsertId();
        logActivity($conn, $data['user_id'], 'You', 'added book', $data['title']);
        echo json_encode(['success'=>true,'id'=>$bookId]);
    } elseif ($method === 'DELETE') {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!isset($data['id'], $data['user_id'])) { echo json_encode(['success'=>false,'error'=>'id and user_id required']); return; }
        $stmt = $conn->prepare("DELETE FROM books WHERE id = :id AND user_id = :uid");
        $stmt->execute([':id'=>$data['id'],':uid'=>$data['user_id']]);
        echo json_encode(['success'=>true]);
    }
}

function handleUpdateProgress($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!isset($data['id'], $data['status'], $data['user_id'])) { echo json_encode(['success'=>false,'error'=>'id, status, user_id required']); return; }
    $stmt = $conn->prepare("UPDATE books SET status=:status, current_page=:page, updated_at=NOW() WHERE id=:id AND user_id=:uid");
    $stmt->execute([':status'=>$data['status'],':page'=>intval($data['current_page']??0),':id'=>$data['id'],':uid'=>$data['user_id']]);
    if ($data['status'] === 'finished') {
        $book = $conn->prepare("SELECT title FROM books WHERE id=:id");
        $book->execute([':id'=>$data['id']]);
        $row = $book->fetch(PDO::FETCH_ASSOC);
        if ($row) logActivity($conn, $data['user_id'], 'You', 'finished reading', $row['title']);
        $conn->prepare("UPDATE users SET booksRead = (SELECT COUNT(*) FROM books WHERE user_id=:uid AND status='finished') WHERE id=:uid")->execute([':uid'=>$data['user_id']]);
    }
    echo json_encode(['success'=>true]);
}

function handleUpdateStreak($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!isset($data['user_id'])) { echo json_encode(['success'=>false,'error'=>'user_id required']); return; }
    $stmt = $conn->prepare("UPDATE users SET currentStreak=:streak WHERE id=:id");
    $stmt->execute([':streak'=>intval($data['streak']??0),':id'=>$data['user_id']]);
    echo json_encode(['success'=>true]);
}

// CIRCLES 
function handleCircles($conn, $method) {
    if ($method === 'GET') {
        $userId = $_GET['user_id'] ?? null;
        $stmt = $conn->query("SELECT c.*, u.displayName AS creator_name, GROUP_CONCAT(DISTINCT cm.user_id ORDER BY cm.joined_at SEPARATOR ',') AS member_ids FROM circles c LEFT JOIN users u ON u.id = c.creator_id LEFT JOIN circle_members cm ON cm.circle_id = c.id GROUP BY c.id ORDER BY c.created_at DESC");
        $circles = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($circles as &$circle) {
            $ids = $circle['member_ids'] ? array_values(array_filter(explode(',', $circle['member_ids']))) : [];
            $circle['member_ids'] = $ids;
            $circle['is_member']  = $userId ? in_array((string)$userId, array_map('strval', $ids)) : false;
        }
        echo json_encode(['success'=>true,'circles'=>$circles]);
    } elseif ($method === 'POST') {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!isset($data['name'], $data['creator_id'])) { echo json_encode(['success'=>false,'error'=>'name and creator_id required']); return; }
        $stmt = $conn->prepare("INSERT INTO circles (name, description, creator_id, book_title, genre, is_public, latitude, longitude, location_name) VALUES (:name, :desc, :cid, :book, :genre, :pub, :lat, :lng, :loc)");
        $stmt->execute([':name'=>$data['name'],':desc'=>$data['description']??'',':cid'=>$data['creator_id'],':book'=>$data['book_title']??'',':genre'=>$data['genre']??'General',':pub'=>isset($data['is_public'])?(int)$data['is_public']:1,':lat'=>$data['latitude']??null,':lng'=>$data['longitude']??null,':loc'=>$data['location_name']??null]);
        $circleId = $conn->lastInsertId();
        $conn->prepare("INSERT IGNORE INTO circle_members (circle_id, user_id) VALUES (:cid, :uid)")->execute([':cid'=>$circleId,':uid'=>$data['creator_id']]);
        logActivity($conn, $data['creator_id'], 'You', 'created circle', $data['name']);
        echo json_encode(['success'=>true,'id'=>$circleId]);
    }
}

function handleJoinCircle($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!isset($data['circle_id'], $data['user_id'])) { echo json_encode(['success'=>false,'error'=>'circle_id and user_id required']); return; }
    $conn->prepare("INSERT IGNORE INTO circle_members (circle_id, user_id) VALUES (:cid, :uid)")->execute([':cid'=>$data['circle_id'],':uid'=>$data['user_id']]);
    $cRow = $conn->prepare("SELECT name FROM circles WHERE id=:id");
    $cRow->execute([':id'=>$data['circle_id']]);
    $circle = $cRow->fetch(PDO::FETCH_ASSOC);
    if ($circle) {
        $uRow = $conn->prepare("SELECT displayName FROM users WHERE id=:id");
        $uRow->execute([':id'=>$data['user_id']]);
        $user = $uRow->fetch(PDO::FETCH_ASSOC);
        logActivity($conn, $data['user_id'], $user ? $user['displayName'] : 'Someone', 'joined circle', $circle['name']);
    }
    echo json_encode(['success'=>true]);
}

function handleLeaveCircle($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    $circle_id = $data['circle_id'] ?? null;
    $user_id   = $data['user_id']   ?? null;
    if (!$circle_id || !$user_id) { echo json_encode(['success'=>false,'error'=>'Missing fields']); return; }
    $stmt = $conn->prepare("DELETE FROM circle_members WHERE circle_id = ? AND user_id = ?");
    $stmt->execute([$circle_id, $user_id]);
    echo json_encode(['success'=>true]);
}

function handleCircleMembers($conn) {
    $circleId = $_GET['circle_id'] ?? null;
    if (!$circleId) { echo json_encode(['success'=>false,'error'=>'circle_id required']); return; }
    $stmt = $conn->prepare("SELECT u.id, u.displayName, u.email, u.avatar_url, cm.joined_at FROM circle_members cm JOIN users u ON u.id = cm.user_id WHERE cm.circle_id = :cid ORDER BY cm.joined_at ASC");
    $stmt->execute([':cid'=>$circleId]);
    echo json_encode(['success'=>true,'members'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

//  DISCUSSIONS (with image support) 

function handleDiscussions($conn, $method) {
    if ($method === 'GET') {
        $circleId = $_GET['circle_id'] ?? null;
        $userId   = $_GET['user_id']   ?? null;
        if (!$circleId) { echo json_encode(['success'=>false,'error'=>'circle_id required']); return; }

        // Fetch top-level messages (reply_to IS NULL), including image_url
        $stmt = $conn->prepare("
            SELECT
                d.id, d.circle_id, d.user_id, d.sender_name,
                d.message, d.image_url, d.reply_to, d.created_at,
                COUNT(DISTINCT ml.id) AS like_count,
                COUNT(DISTINCT r.id)  AS reply_count,
                MAX(CASE WHEN ml.user_id = :uid THEN 1 ELSE 0 END) AS is_liked
            FROM discussions d
            LEFT JOIN message_likes ml ON ml.message_id = d.id
            LEFT JOIN discussions r ON r.reply_to = d.id
            WHERE d.circle_id = :cid AND d.reply_to IS NULL
            GROUP BY d.id
            ORDER BY d.created_at ASC
        ");
        $stmt->execute([':cid' => $circleId, ':uid' => $userId ?? 0]);
        $messages = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // For each top-level message, fetch its nested replies (also with image_url)
        $replyStmt = $conn->prepare("
            SELECT
                d.id, d.circle_id, d.user_id, d.sender_name,
                d.message, d.image_url, d.reply_to, d.created_at,
                COUNT(DISTINCT ml.id) AS like_count,
                MAX(CASE WHEN ml.user_id = :uid THEN 1 ELSE 0 END) AS is_liked
            FROM discussions d
            LEFT JOIN message_likes ml ON ml.message_id = d.id
            WHERE d.reply_to = :parent_id
            GROUP BY d.id
            ORDER BY d.created_at ASC
        ");

        foreach ($messages as &$msg) {
            $msg['like_count']  = (int)$msg['like_count'];
            $msg['reply_count'] = (int)$msg['reply_count'];
            $msg['is_liked']    = (bool)$msg['is_liked'];
            $msg['image_url']   = $msg['image_url'] ?: null;

            $replyStmt->execute([':parent_id' => $msg['id'], ':uid' => $userId ?? 0]);
            $replies = $replyStmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($replies as &$r) {
                $r['like_count'] = (int)$r['like_count'];
                $r['is_liked']   = (bool)$r['is_liked'];
                $r['image_url']  = $r['image_url'] ?: null;
            }
            $msg['replies'] = $replies;
        }

        echo json_encode(['success'=>true,'messages'=>$messages]);

    } elseif ($method === 'POST') {

        // Detect multipart (image upload) vs plain JSON
        $isMultipart = isset($_FILES['image']) || isset($_POST['circle_id']);

        if ($isMultipart) {
            $circleId = $_POST['circle_id'] ?? null;
            $userId   = $_POST['user_id']   ?? null;
            $message  = $_POST['message']   ?? '';
            $replyTo  = $_POST['reply_to']  ?? null;
        } else {
            $data     = json_decode(file_get_contents('php://input'), true);
            $circleId = $data['circle_id'] ?? null;
            $userId   = $data['user_id']   ?? null;
            $message  = $data['message']   ?? '';
            $replyTo  = $data['reply_to']  ?? null;
        }

        if (!$circleId || !$userId) {
            echo json_encode(['success'=>false,'error'=>'circle_id and user_id required']);
            return;
        }

        // Look up sender name
        $uRow = $conn->prepare("SELECT displayName FROM users WHERE id=:id");
        $uRow->execute([':id' => $userId]);
        $user = $uRow->fetch(PDO::FETCH_ASSOC);
        $senderName = $user ? $user['displayName'] : 'Unknown';

        // Handle image upload if present
        $imageUrl = null;
        if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
            $file    = $_FILES['image'];
            $allowed = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
            if (in_array($file['type'], $allowed) && $file['size'] <= 5 * 1024 * 1024) {
                $uploadDir = __DIR__ . '/discussion_images/';
                if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);
                $ext      = pathinfo($file['name'], PATHINFO_EXTENSION) ?: 'jpg';
                $filename = 'msg_' . $userId . '_' . time() . '.' . $ext;
                if (move_uploaded_file($file['tmp_name'], $uploadDir . $filename)) {
                    $imageUrl = 'http://169.239.251.102:280/~steve.nsabimana/api/discussion_images/' . $filename;
                }
            }
        }

        // Insert the message
        $stmt = $conn->prepare("INSERT INTO discussions (circle_id, user_id, sender_name, message, image_url, reply_to) VALUES (:cid, :uid, :sender, :msg, :img, :reply)");
        $stmt->execute([
            ':cid'    => $circleId,
            ':uid'    => $userId,
            ':sender' => $senderName,
            ':msg'    => $message,
            ':img'    => $imageUrl,
            ':reply'  => $replyTo ?: null,
        ]);
        $msgId = $conn->lastInsertId();

        $cRow = $conn->prepare("SELECT name FROM circles WHERE id=:id");
        $cRow->execute([':id' => $circleId]);
        $circle = $cRow->fetch(PDO::FETCH_ASSOC);
        if ($circle) logActivity($conn, $userId, $senderName, 'commented in', $circle['name']);

        echo json_encode([
            'success'     => true,
            'id'          => $msgId,
            'sender_name' => $senderName,
            'image_url'   => $imageUrl,
        ]);
    }
}

//  LIKES 

function handleLikeMessage($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    $messageId = $data['message_id'] ?? null;
    $userId    = $data['user_id']    ?? null;
    if (!$messageId || !$userId) {
        echo json_encode(['success'=>false,'error'=>'message_id and user_id required']);
        return;
    }
    $check = $conn->prepare("SELECT id FROM message_likes WHERE message_id=:mid AND user_id=:uid");
    $check->execute([':mid'=>$messageId, ':uid'=>$userId]);
    $existing = $check->fetch();
    if ($existing) {
        $conn->prepare("DELETE FROM message_likes WHERE message_id=:mid AND user_id=:uid")
             ->execute([':mid'=>$messageId, ':uid'=>$userId]);
        $liked = false;
    } else {
        $conn->prepare("INSERT IGNORE INTO message_likes (message_id, user_id) VALUES (:mid, :uid)")
             ->execute([':mid'=>$messageId, ':uid'=>$userId]);
        $liked = true;
    }
    $count = $conn->prepare("SELECT COUNT(*) FROM message_likes WHERE message_id=:mid");
    $count->execute([':mid'=>$messageId]);
    $likeCount = (int)$count->fetchColumn();
    echo json_encode(['success'=>true,'liked'=>$liked,'like_count'=>$likeCount]);
}

//  ACTIVITY 

function handleActivity($conn) {
    $user_id = $_GET['user_id'] ?? null;
    if (!$user_id) { echo json_encode(['success'=>false,'error'=>'user_id required']); return; }
    $stmt = $conn->prepare("SELECT a.id, a.user_id, a.actor_name, a.action, a.target, a.created_at FROM activity_log a WHERE a.user_id = :uid ORDER BY a.created_at DESC LIMIT 20");
    $stmt->execute([':uid' => $user_id]);
    echo json_encode(['success'=>true,'activity'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function logActivity($conn, $userId, $actorName, $action, $target) {
    try {
        $conn->prepare("INSERT INTO activity_log (user_id, actor_name, action, target) VALUES (:uid, :actor, :action, :target)")
             ->execute([':uid'=>$userId,':actor'=>$actorName,':action'=>$action,':target'=>$target]);
    } catch (Exception $e) {}
}

//  AVATAR

function handleUploadAvatar($conn) {
    error_log('POST data: ' . print_r($_POST, true));
    error_log('FILES data: ' . print_r($_FILES, true));

    if (!isset($_FILES['avatar'], $_POST['user_id'])) {
        echo json_encode([
            'success'    => false,
            'error'      => 'Missing file or user_id',
            'post_keys'  => array_keys($_POST),
            'files_keys' => array_keys($_FILES)
        ]);
        return;
    }
    $userId  = $_POST['user_id'];
    $file    = $_FILES['avatar'];
    $allowed = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!in_array($file['type'], $allowed)) { echo json_encode(['success'=>false,'error'=>'Only JPG, PNG, GIF, WEBP allowed']); return; }
    if ($file['size'] > 2 * 1024 * 1024) { echo json_encode(['success'=>false,'error'=>'Image too large. Max 2MB']); return; }
    $uploadDir = __DIR__ . '/avatars/';
    if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);
    $old = $conn->prepare("SELECT avatar_url FROM users WHERE id=:id");
    $old->execute([':id'=>$userId]);
    $oldUser = $old->fetch(PDO::FETCH_ASSOC);
    if ($oldUser && $oldUser['avatar_url']) {
        $oldPath = __DIR__ . '/avatars/' . basename($oldUser['avatar_url']);
        if (file_exists($oldPath)) unlink($oldPath);
    }
    $ext      = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = 'avatar_' . $userId . '_' . time() . '.' . $ext;
    $dest     = $uploadDir . $filename;
    if (!move_uploaded_file($file['tmp_name'], $dest)) { echo json_encode(['success'=>false,'error'=>'Failed to save image']); return; }
    $baseUrl   = 'http://169.239.251.102:280/~steve.nsabimana/api/avatars/';
    $avatarUrl = $baseUrl . $filename;
    $conn->prepare("UPDATE users SET avatar_url=:url WHERE id=:id")->execute([':url'=>$avatarUrl,':id'=>$userId]);
    echo json_encode(['success'=>true,'avatar_url'=>$avatarUrl]);
}

function handleRemoveAvatar($conn) {
    $data   = json_decode(file_get_contents('php://input'), true);
    $userId = $data['user_id'] ?? null;
    if (!$userId) { echo json_encode(['success'=>false,'error'=>'user_id required']); return; }
    $old = $conn->prepare("SELECT avatar_url FROM users WHERE id=:id");
    $old->execute([':id'=>$userId]);
    $oldUser = $old->fetch(PDO::FETCH_ASSOC);
    if ($oldUser && $oldUser['avatar_url']) {
        $oldPath = __DIR__ . '/avatars/' . basename($oldUser['avatar_url']);
        if (file_exists($oldPath)) unlink($oldPath);
    }
    $conn->prepare("UPDATE users SET avatar_url=NULL WHERE id=:id")->execute([':id'=>$userId]);
    echo json_encode(['success'=>true]);
}
