<?php
require_once '../config/database.php';
require_once '../middleware/auth.php';

$payload = authenticate();

// Check admin role
if ($payload['role'] !== 'admin') {
    sendResponse(false, 'Akses ditolak', null, 403);
}

$database = new Database();
$conn = $database->getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get all users (except admin) with profile_photo
    $stmt = $conn->prepare("SELECT id, name, email, role, phone, address, profile_photo, created_at FROM users WHERE role != 'admin'");
    $stmt->execute();
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    sendResponse(true, 'Data user ditemukan', $users);
    
} elseif ($method === 'DELETE') {
    // Delete user
    $id = $_GET['id'] ?? null;
    
    if (!$id) {
        sendResponse(false, 'ID user diperlukan', null, 400);
    }
    
    // Cek apakah user ada
    $checkStmt = $conn->prepare("SELECT id, role FROM users WHERE id = ?");
    $checkStmt->execute([$id]);
    $user = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        sendResponse(false, 'User tidak ditemukan', null, 404);
    }
    
    // Cegah menghapus admin
    if ($user['role'] === 'admin') {
        sendResponse(false, 'Tidak dapat menghapus akun admin', null, 403);
    }
    
    // Hapus user
    $stmt = $conn->prepare("DELETE FROM users WHERE id = ?");
    $result = $stmt->execute([$id]);
    
    if ($result) {
        sendResponse(true, 'User berhasil dihapus', null);
    } else {
        sendResponse(false, 'Gagal menghapus user', null, 500);
    }
}
?>