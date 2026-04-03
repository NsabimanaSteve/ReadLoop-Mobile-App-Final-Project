<?php
// Database Configuration
class Database {
    private $host = "localhost";
    private $username = "steve.nsabimana";
    private $password = "Nsateve2@"; 
    private $database = "readloop_db";
    private $conn;

    public function __construct() {
        $this->connect();
    }

    private function connect() {
        try {
            $this->conn = new PDO(
                "mysql:host={$this->host};dbname={$this->database}",
                $this->username,
                $this->password
            );
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        } catch(PDOException $e) {
            echo "Connection failed: " . $e->getMessage();
        }
    }

    public function getConnection() {
        return $this->conn;
    }
}

// Enable CORS
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE, PUT");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Get request method and endpoint
$method = $_SERVER['REQUEST_METHOD'];
$request_uri = $_SERVER['REQUEST_URI'];
$path = parse_url($request_uri, PHP_URL_PATH);
$path_parts = explode('/', $path);
$endpoint = end($path_parts);

// Database instance
$db = new Database();
$conn = $db->getConnection();

// Route requests
switch($endpoint) {
    case 'login.php':
    case 'login':
        handleLogin($conn);
        break;
    case 'register.php':
    case 'register':
        handleRegister($conn);
        break;
    case 'users.php':
    case 'users':
        handleUsers($conn);
        break;
    case 'logout.php':
    case 'logout':
        handleLogout($conn);
        break;
    default:
        echo json_encode(['error' => 'Endpoint not found']);
        break;
}

// Login Handler
function handleLogin($conn) {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        return;
    }

    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['email']) || !isset($data['password'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Email and password required']);
        return;
    }

    $email = $data['email'];
    $password = $data['password'];

    try {
        $stmt = $conn->prepare("SELECT * FROM users WHERE email = :email");
        $stmt->bindParam(':email', $email);
        $stmt->execute();
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($user && password_verify($password, $user['password'])) {
            // Remove password from response
            unset($user['password']);
            
            // Set session
            session_start();
            $_SESSION['user_id'] = $user['id'];
            $_SESSION['email'] = $user['email'];
            
            echo json_encode([
                'success' => true,
                'user' => $user
            ]);
        } else {
            http_response_code(401);
            echo json_encode(['error' => 'Invalid credentials']);
        }
    } catch(PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
    }
}

// Register Handler
function handleRegister($conn) {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        return;
    }

    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['email']) || !isset($data['password']) || !isset($data['displayName'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Email, password, and display name required']);
        return;
    }

    $email = $data['email'];
    $password = $data['password'];
    $displayName = $data['displayName'];

    // Validate email
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid email format']);
        return;
    }

    // Check if email already exists
    try {
        $stmt = $conn->prepare("SELECT id FROM users WHERE email = :email");
        $stmt->bindParam(':email', $email);
        $stmt->execute();
        
        if ($stmt->fetch()) {
            http_response_code(409);
            echo json_encode(['error' => 'Email already exists']);
            return;
        }

        // Hash password
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        
        // Insert new user
        $stmt = $conn->prepare("INSERT INTO users (email, password, displayName, currentStreak, booksRead, created_at) VALUES (:email, :password, :displayName, 0, 0, NOW())");
        $stmt->bindParam(':email', $email);
        $stmt->bindParam(':password', $hashedPassword);
        $stmt->bindParam(':displayName', $displayName);
        $stmt->execute();

        $userId = $conn->lastInsertId();
        
        echo json_encode([
            'success' => true,
            'user' => [
                'id' => $userId,
                'email' => $email,
                'displayName' => $displayName,
                'currentStreak' => 0,
                'booksRead' => 0
            ]
        ]);
    } catch(PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
    }
}

// Users Handler
function handleUsers($conn) {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        return;
    }

    try {
        $stmt = $conn->prepare("SELECT id, email, displayName, currentStreak, booksRead, created_at FROM users ORDER BY created_at DESC");
        $stmt->execute();
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'success' => true,
            'users' => $users
        ]);
    } catch(PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
    }
}

// Logout Handler
function handleLogout($conn) {
    session_start();
    session_destroy();
    
    echo json_encode([
        'success' => true,
        'message' => 'Logged out successfully'
    ]);
}
?>
