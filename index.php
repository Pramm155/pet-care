<?php
echo json_encode([
    'success' => true,
    'message' => 'Pet Boarding API is running',
    'endpoints' => [
        'register' => '/api/register.php',
        'login' => '/api/login.php',
        'profile' => '/api/profile.php',
        'pets' => '/api/pets.php',
        'bookings' => '/api/bookings.php',
        'location' => '/api/location.php',
        'admin' => [
            'bookings' => '/admin/bookings.php',
            'users' => '/admin/users.php',
            'update-status' => '/admin/update-status.php'
        ]
    ]
]);
?>