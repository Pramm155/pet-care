<?php
require_once '../config/database.php';
require_once '../middleware/auth.php';

$payload = authenticate();
$database = new Database();
$conn = $database->getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    
    // CEK ROLE: Admin atau User?
    if ($payload['role'] === 'admin') {
        // ADMIN: lihat semua booking
        $stmt = $conn->prepare("SELECT b.*, 
                                       u.name as user_name, 
                                       u.email as user_email, 
                                       u.profile_photo as user_photo, 
                                       p.name as pet_name,
                                       p.photo as pet_photo
                                FROM bookings b 
                                JOIN users u ON b.user_id = u.id 
                                JOIN pets p ON b.pet_id = p.id 
                                ORDER BY b.created_at DESC");
        $stmt->execute();
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
    } else {
        // USER: lihat booking sendiri
        $stmt = $conn->prepare("SELECT b.*, 
                                       p.name as pet_name, 
                                       p.photo as pet_photo, 
                                       u.name as user_name, 
                                       u.email as user_email, 
                                       u.profile_photo as user_photo
                                FROM bookings b 
                                JOIN pets p ON b.pet_id = p.id
                                JOIN users u ON b.user_id = u.id
                                WHERE b.user_id = ? 
                                ORDER BY b.created_at DESC");
        $stmt->execute([$payload['user_id']]);
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    // Handle null photos untuk semua kasus
    foreach ($bookings as &$booking) {
        if ($booking['pet_photo'] === null) {
            $booking['pet_photo'] = '';
        }
        if ($booking['user_photo'] === null) {
            $booking['user_photo'] = '';
        }
    }
    
    sendResponse(true, 'Data booking ditemukan', $bookings);
    
} elseif ($method === 'POST') {
    // USER only: tambah booking
    if ($payload['role'] !== 'user') {
        sendResponse(false, 'Hanya user yang bisa membuat booking', null, 403);
    }
    
    $data = json_decode(file_get_contents('php://input'), true);
    
    // Validasi kepemilikan pet
    $checkPet = $conn->prepare("SELECT id FROM pets WHERE id = ? AND user_id = ?");
    $checkPet->execute([$data['pet_id'], $payload['user_id']]);
    if ($checkPet->rowCount() === 0) {
        sendResponse(false, 'Hewan tidak ditemukan atau bukan milik Anda', null, 404);
    }
    
    $stmt = $conn->prepare("INSERT INTO bookings (user_id, pet_id, check_in_date, check_out_date, service_type, total_price, special_requests, status) 
                           VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')");
    
    $result = $stmt->execute([
        $payload['user_id'],
        $data['pet_id'],
        $data['check_in_date'],
        $data['check_out_date'],
        $data['service_type'],
        $data['total_price'],
        $data['special_requests'] ?? null
    ]);
    
    if ($result) {
        sendResponse(true, 'Booking berhasil dibuat', ['id' => $conn->lastInsertId()]);
    } else {
        sendResponse(false, 'Gagal membuat booking', null, 500);
    }
    
} elseif ($method === 'PUT') {
    // USER only: update booking sendiri (hanya pending)
    if ($payload['role'] !== 'user') {
        sendResponse(false, 'Hanya user yang bisa mengupdate booking', null, 403);
    }
    
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['id'])) {
        sendResponse(false, 'ID booking diperlukan', null, 400);
    }
    
    $checkStmt = $conn->prepare("SELECT id, status FROM bookings WHERE id = ? AND user_id = ?");
    $checkStmt->execute([$data['id'], $payload['user_id']]);
    $booking = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$booking) {
        sendResponse(false, 'Booking tidak ditemukan', null, 404);
    }
    
    if ($booking['status'] !== 'pending') {
        sendResponse(false, 'Booking tidak dapat diubah karena sudah diproses', null, 400);
    }
    
    $stmt = $conn->prepare("UPDATE bookings SET pet_id = ?, check_in_date = ?, check_out_date = ?, service_type = ?, total_price = ?, special_requests = ? WHERE id = ?");
    $result = $stmt->execute([
        $data['pet_id'],
        $data['check_in_date'],
        $data['check_out_date'],
        $data['service_type'],
        $data['total_price'],
        $data['special_requests'] ?? null,
        $data['id']
    ]);
    
    if ($result) {
        sendResponse(true, 'Booking berhasil diperbarui', null);
    } else {
        sendResponse(false, 'Gagal memperbarui booking', null, 500);
    }
    
} elseif ($method === 'DELETE') {
    
    if ($payload['role'] === 'admin') {
        // ADMIN: hapus booking apapun
        $id = $_GET['id'] ?? null;
        
        if (!$id) {
            sendResponse(false, 'ID booking diperlukan', null, 400);
        }
        
        $checkStmt = $conn->prepare("SELECT id FROM bookings WHERE id = ?");
        $checkStmt->execute([$id]);
        
        if ($checkStmt->rowCount() === 0) {
            sendResponse(false, 'Booking tidak ditemukan', null, 404);
        }
        
        $stmt = $conn->prepare("DELETE FROM bookings WHERE id = ?");
        $result = $stmt->execute([$id]);
        
    } else {
        // USER: hapus booking sendiri (hanya pending)
        $id = $_GET['id'] ?? null;
        
        if (!$id) {
            sendResponse(false, 'ID booking diperlukan', null, 400);
        }
        
        $checkStmt = $conn->prepare("SELECT id, status FROM bookings WHERE id = ? AND user_id = ?");
        $checkStmt->execute([$id, $payload['user_id']]);
        $booking = $checkStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$booking) {
            sendResponse(false, 'Booking tidak ditemukan', null, 404);
        }
        
        if ($booking['status'] !== 'pending') {
            sendResponse(false, 'Booking tidak dapat dihapus karena sudah diproses', null, 400);
        }
        
        $stmt = $conn->prepare("DELETE FROM bookings WHERE id = ?");
        $result = $stmt->execute([$id]);
    }
    
    if ($result) {
        sendResponse(true, 'Booking berhasil dihapus', null);
    } else {
        sendResponse(false, 'Gagal menghapus booking', null, 500);
    }
}
?>