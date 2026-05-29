<?php
require_once '../config/database.php';
require_once '../middleware/auth.php';

$payload = authenticate();

// Hanya admin yang bisa menghapus booking
if ($payload['role'] !== 'admin') {
    sendResponse(false, 'Akses ditolak. Hanya admin yang dapat menghapus pesanan.', null, 403);
}

$database = new Database();
$conn = $database->getConnection();

// Ambil ID dari GET parameter
$id = $_GET['id'] ?? null;

if (!$id) {
    sendResponse(false, 'ID booking diperlukan', null, 400);
}

// Cek apakah booking ada
$checkStmt = $conn->prepare("SELECT id FROM bookings WHERE id = ?");
$checkStmt->execute([$id]);

if ($checkStmt->rowCount() === 0) {
    sendResponse(false, 'Booking tidak ditemukan', null, 404);
}

// Hapus booking
$stmt = $conn->prepare("DELETE FROM bookings WHERE id = ?");
$result = $stmt->execute([$id]);

if ($result) {
    sendResponse(true, 'Booking berhasil dihapus', null);
} else {
    sendResponse(false, 'Gagal menghapus booking', null, 500);
}
?>