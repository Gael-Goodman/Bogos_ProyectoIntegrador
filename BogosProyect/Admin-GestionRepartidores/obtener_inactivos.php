<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    $stmt = $pdo->query("
        SELECT r.id_repartidor, r.id_usuario, r.telefono, r.vehiculo, u.nombre_completo 
        FROM repartidores r
        INNER JOIN usuarios u ON r.id_usuario = u.id_usuario
        WHERE r.activo = 0 
        ORDER BY u.nombre_completo ASC
    ");
    $repartidores = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['exito' => true, 'repartidores' => $repartidores]);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>