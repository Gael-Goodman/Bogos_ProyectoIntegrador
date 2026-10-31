<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    $stmt = $pdo->query("SELECT id_usuario, nombre_completo, usuario AS nombre_usuario, rol FROM usuarios WHERE activo = 0 ORDER BY nombre_completo ASC");
    $usuarios = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['exito' => true, 'usuarios' => $usuarios]);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>