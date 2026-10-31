<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);
$id_cliente = $datos['id_cliente'] ?? null;

if (!$id_cliente) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID no proporcionado.']);
    exit;
}

try {
    $stmt = $pdo->prepare("UPDATE clientes SET activo = 1 WHERE id_cliente = ?");
    $stmt->execute([$id_cliente]);
    echo json_encode(['exito' => true, 'mensaje' => 'Tiendita reactivada.']);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al reactivar: ' . $e->getMessage()]);
}
?>