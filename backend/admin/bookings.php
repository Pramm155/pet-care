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
    // Get all bookings with user and pet info, termasuk profile_photo
    $stmt = $conn->prepare("SELECT b.*, u.name as user_name, u.email as user_email, u.profile_photo as user_photo, p.name as pet_name 
                           FROM bookings b 
                           JOIN users u ON b.user_id = u.id 
                           JOIN pets p ON b.pet_id = p.id 
                           ORDER BY b.created_at DESC");
    $stmt->execute();
    $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Pastikan user_photo tidak null
    foreach ($bookings as &$booking) {
        if ($booking['user_photo'] === null) {
            $booking['user_photo'] = '';
        }
    }
    
    sendResponse(true, 'Data booking ditemukan', $bookings);
    
} elseif ($method === 'DELETE') {
    // Delete booking by admin
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
}
?>