<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    $stmt = $pdo->query("SELECT id_cliente, nombre_negocio, nombre_contacto, direccion FROM clientes WHERE activo = 0 ORDER BY nombre_negocio ASC");
    $clientes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['exito' => true, 'clientes' => $clientes]);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>