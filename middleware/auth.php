<?php
require_once dirname(__DIR__) . '/config/database.php';

function authenticate() {
    // Ambil semua headers
    $headers = getallheaders();
    
    // Cek Authorization header (case insensitive)
    $authHeader = null;
    foreach ($headers as $key => $value) {
        if (strtolower($key) === 'authorization') {
            $authHeader = $value;
            break;
        }
    }
    
    // Jika tidak ditemukan di getallheaders, coba dari $_SERVER
    if (!$authHeader && isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
    }
    
    // Jika masih tidak ada, coba dari REDIRECT_HTTP_AUTHORIZATION
    if (!$authHeader && isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    }
    
    if (!$authHeader) {
        sendResponse(false, 'Token tidak ditemukan', null, 401);
    }
    
    $token = str_replace('Bearer ', '', $authHeader);
    $token = trim($token);
    
    if (empty($token)) {
        sendResponse(false, 'Token kosong', null, 401);
    }
    
    $payload = verifyJWT($token);
    
    if (!$payload) {
        sendResponse(false, 'Token tidak valid atau sudah kadaluarsa', null, 401);
    }
    
    return $payload;
}
?>