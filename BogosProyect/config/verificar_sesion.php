<?php
session_start();
header('Content-Type: application/json');
if (!isset($_SESSION['id_usuario'])) {
    echo json_encode(['exito' => false]);
    exit;
}
echo json_encode(['exito' => true]);
?>