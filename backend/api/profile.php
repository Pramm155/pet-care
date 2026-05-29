<?php
require_once '../config/database.php';
require_once '../middleware/auth.php';

$payload = authenticate();
$database = new Database();
$conn = $database->getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get profile with profile_photo
    $stmt = $conn->prepare("SELECT id, name, email, role, phone, address, profile_photo FROM users WHERE id = ?");
    $stmt->execute([$payload['user_id']]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Pastikan profile_photo tidak null
    if ($user['profile_photo'] === null) {
        $user['profile_photo'] = '';
    }
    
    sendResponse(true, 'Profile ditemukan', $user);
    
} elseif ($method === 'PUT') {
    // Update profile including profile_photo
    $data = json_decode(file_get_contents('php://input'), true);
    
    $name = $data['name'] ?? null;
    $phone = $data['phone'] ?? null;
    $address = $data['address'] ?? null;
    $profilePhoto = $data['profile_photo'] ?? null;
    
    $updates = [];
    $params = [];
    
    if ($name !== null) {
        $updates[] = "name = ?";
        $params[] = $name;
    }
    if ($phone !== null) {
        $updates[] = "phone = ?";
        $params[] = $phone;
    }
    if ($address !== null) {
        $updates[] = "address = ?";
        $params[] = $address;
    }
    if ($profilePhoto !== null && $profilePhoto !== '') {
        $updates[] = "profile_photo = ?";
        $params[] = $profilePhoto;
    }
    
    if (count($updates) > 0) {
        $params[] = $payload['user_id'];
        $stmt = $conn->prepare("UPDATE users SET " . implode(', ', $updates) . " WHERE id = ?");
        $stmt->execute($params);
    }
    
    // Ambil data terbaru
    $stmt = $conn->prepare("SELECT id, name, email, role, phone, address, profile_photo FROM users WHERE id = ?");
    $stmt->execute([$payload['user_id']]);
    $updatedUser = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($updatedUser['profile_photo'] === null) {
        $updatedUser['profile_photo'] = '';
    }
    
    sendResponse(true, 'Profile berhasil diperbarui', $updatedUser);
}
?>