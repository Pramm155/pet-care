<?php
require_once '../config/database.php';
require_once '../middleware/auth.php';

$payload = authenticate();
$database = new Database();
$conn = $database->getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Get all pets user
    $stmt = $conn->prepare("SELECT * FROM pets WHERE user_id = ? ORDER BY created_at DESC");
    $stmt->execute([$payload['user_id']]);
    $pets = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    sendResponse(true, 'Data hewan ditemukan', $pets);
    
} elseif ($method === 'POST') {
    // Add new pet
    $data = json_decode(file_get_contents('php://input'), true);
    
    $photo = $data['photo'] ?? null;
    
    $stmt = $conn->prepare("INSERT INTO pets (user_id, name, species, breed, age, weight, photo, medical_notes) 
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    
    $result = $stmt->execute([
        $payload['user_id'],
        $data['name'],
        $data['species'],
        $data['breed'] ?? null,
        $data['age'] ?? 0,
        $data['weight'] ?? 0,
        $photo,
        $data['medical_notes'] ?? null
    ]);
    
    if ($result) {
        sendResponse(true, 'Hewan berhasil ditambahkan', ['id' => $conn->lastInsertId()]);
    } else {
        sendResponse(false, 'Gagal menambahkan hewan', null, 500);
    }
    
} elseif ($method === 'PUT') {
    // Update pet
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['id'])) {
        sendResponse(false, 'ID hewan diperlukan', null, 400);
    }
    
    // Cek kepemilikan (user biasa) atau admin bisa update semua
    if ($payload['role'] === 'admin') {
        $checkStmt = $conn->prepare("SELECT id FROM pets WHERE id = ?");
        $checkStmt->execute([$data['id']]);
    } else {
        $checkStmt = $conn->prepare("SELECT id FROM pets WHERE id = ? AND user_id = ?");
        $checkStmt->execute([$data['id'], $payload['user_id']]);
    }
    
    if ($checkStmt->rowCount() === 0) {
        sendResponse(false, 'Hewan tidak ditemukan', null, 404);
    }
    
    $photo = $data['photo'] ?? null;
    
    $stmt = $conn->prepare("UPDATE pets SET name = ?, species = ?, breed = ?, age = ?, weight = ?, photo = ?, medical_notes = ? WHERE id = ?");
    $result = $stmt->execute([
        $data['name'],
        $data['species'],
        $data['breed'] ?? null,
        $data['age'] ?? 0,
        $data['weight'] ?? 0,
        $photo,
        $data['medical_notes'] ?? null,
        $data['id']
    ]);
    
    if ($result) {
        sendResponse(true, 'Hewan berhasil diperbarui', null);
    } else {
        sendResponse(false, 'Gagal memperbarui hewan', null, 500);
    }
    
} elseif ($method === 'DELETE') {
    // DELETE pet (Admin bisa hapus semua, User hanya bisa hapus milik sendiri)
    $id = $_GET['id'] ?? null;
    
    if (!$id) {
        sendResponse(false, 'ID hewan diperlukan', null, 400);
    }
    
    // Cek kepemilikan berdasarkan role
    if ($payload['role'] === 'admin') {
        // Admin bisa hapus semua hewan
        $checkStmt = $conn->prepare("SELECT id FROM pets WHERE id = ?");
        $checkStmt->execute([$id]);
    } else {
        // User hanya bisa hapus hewan milik sendiri
        $checkStmt = $conn->prepare("SELECT id FROM pets WHERE id = ? AND user_id = ?");
        $checkStmt->execute([$id, $payload['user_id']]);
    }
    
    if ($checkStmt->rowCount() === 0) {
        sendResponse(false, 'Hewan tidak ditemukan', null, 404);
    }
    
    // Hapus hewan
    $stmt = $conn->prepare("DELETE FROM pets WHERE id = ?");
    $result = $stmt->execute([$id]);
    
    if ($result) {
        sendResponse(true, 'Hewan berhasil dihapus', null);
    } else {
        sendResponse(false, 'Gagal menghapus hewan', null, 500);
    }
}
?>