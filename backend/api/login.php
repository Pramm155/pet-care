<?php
require_once '../config/database.php';

$database = new Database();
$conn = $database->getConnection();

$data = json_decode(file_get_contents('php://input'), true);

if (!isset($data['email']) || !isset($data['password'])) {
    sendResponse(false, 'Email dan password wajib diisi', null, 400);
}

$email = $data['email'];
$password = md5($data['password']);

// Ambil juga profile_photo
$stmt = $conn->prepare("SELECT id, name, email, role, phone, address, profile_photo FROM users WHERE email = ? AND password = ?");
$stmt->execute([$email, $password]);

if ($stmt->rowCount() > 0) {
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    // Pastikan profile_photo tidak null
    if ($user['profile_photo'] === null) {
        $user['profile_photo'] = '';
    }
    $token = generateJWT($user['id'], $user['email'], $user['role']);
    
    sendResponse(true, 'Login berhasil', [
        'token' => $token,
        'user' => $user
    ]);
} else {
    sendResponse(false, 'Email atau password salah', null, 401);
}
?>