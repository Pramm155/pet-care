<?php
require_once '../config/database.php';
require_once '../middleware/auth.php';

$payload = authenticate();

if ($payload['role'] !== 'admin') {
    sendResponse(false, 'Akses ditolak', null, 403);
}

$database = new Database();
$conn = $database->getConnection();

$data = json_decode(file_get_contents('php://input'), true);

if (!isset($data['id']) || !isset($data['status'])) {
    sendResponse(false, 'ID booking dan status diperlukan', null, 400);
}

$validStatus = ['pending', 'confirmed', 'completed', 'cancelled'];
if (!in_array($data['status'], $validStatus)) {
    sendResponse(false, 'Status tidak valid', null, 400);
}

$stmt = $conn->prepare("UPDATE bookings SET status = ? WHERE id = ?");
$result = $stmt->execute([$data['status'], $data['id']]);

if ($result) {
    sendResponse(true, 'Status booking berhasil diperbarui', null);
} else {
    sendResponse(false, 'Gagal memperbarui status', null, 500);
}
?>