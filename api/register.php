<?php
require_once '../config/database.php';

$database = new Database();
$conn = $database->getConnection();

$data = json_decode(file_get_contents('php://input'), true);

if (!isset($data['name']) || !isset($data['email']) || !isset($data['password'])) {
    sendResponse(false, 'Nama, email, dan password wajib diisi', null, 400);
}

$name = $data['name'];
$email = $data['email'];
$password = md5($data['password']);

$checkStmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
$checkStmt->execute([$email]);

if ($checkStmt->rowCount() > 0) {
    sendResponse(false, 'Email sudah terdaftar', null, 400);
}

$stmt = $conn->prepare("INSERT INTO users (name, email, password) VALUES (?, ?, ?)");

if ($stmt->execute([$name, $email, $password])) {
    sendResponse(true, 'Registrasi berhasil', ['user_id' => $conn->lastInsertId()]);
} else {
    sendResponse(false, 'Registrasi gagal', null, 500);
}
?>