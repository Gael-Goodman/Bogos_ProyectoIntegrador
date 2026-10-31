<?php
session_start();
header('Content-Type: application/json');

// Validar seguridad
if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    $stmt = $pdo->query("
        SELECT id_producto, codigo, categoria, nombre 
        FROM productos 
        WHERE activo = 0 
        ORDER BY nombre ASC
    ");
    
    $productos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['exito' => true, 'productos' => $productos]);

} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>