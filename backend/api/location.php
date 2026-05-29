<?php
require_once '../config/database.php';

$location = [
    'name' => 'Vanko Petshop',
    'address' => 'Jl. Jae Sumantoro, Ngabangan, Sidoluhur, Kec. Godean, Kabupaten Sleman, Daerah Istimewa Yogyakarta 55264',
    'phone' => '+62 896-1950-3053',
    'whatsapp' => '+6281225708810',
    'lat' => -7.763405765388021,
    'lng' => 110.29095926485488,
    'openTime' => '08:00',
    'closeTime' => '23:00',
    'rating' => 4.8,
    'totalReviews' => 127,
    'services' => ['Penitipan Hewan', 'Grooming', 'Pet Shop', 'Vaksinasi'],
    'description' => 'Vanko Petshop adalah tempat penitipan hewan dan pet shop terpercaya di Godean, Sleman. Kami menyediakan layanan penitipan hewan dengan fasilitas nyaman, grooming profesional, serta berbagai kebutuhan hewan peliharaan.'
];

sendResponse(true, 'Lokasi ditemukan', $location);
?>