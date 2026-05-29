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
    // Get all pets with user info and photo
    $stmt = $conn->prepare("SELECT p.*, u.name as owner_name, u.email as owner_email 
                           FROM pets p 
                           JOIN users u ON p.user_id = u.id 
                           ORDER BY p.created_at DESC");
    $stmt->execute();
    $pets = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    sendResponse(true, 'Data hewan ditemukan', $pets);
}
?>