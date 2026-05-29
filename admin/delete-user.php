<?php
require_once '../config/database.php';
require_once '../middleware/auth.php';

$payload = authenticate();

// Check admin role
if ($payload['role'] !== 'admin') {
    sendResponse(false, 'Akses ditolak. Hanya admin yang dapat menghapus user.', null, 403);
}

$database = new Database();
$conn = $database->getConnection();

// Ambil data dari body
$input = json_decode(file_get_contents('php://input'), true);
$id = $input['id'] ?? null;

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

// Hapus user (data terkait akan otomatis terhapus karena foreign key ON DELETE CASCADE)
$stmt = $conn->prepare("DELETE FROM users WHERE id = ?");
$result = $stmt->execute([$id]);

if ($result) {
    sendResponse(true, 'User berhasil dihapus', null);
} else {
    sendResponse(false, 'Gagal menghapus user', null, 500);
}
?>