<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);
$id_repartidor = $datos['id_repartidor'] ?? null;

if (!$id_repartidor) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID no proporcionado.']);
    exit;
}

try {
    // Bloquear si el repartidor tiene pedidos en curso asignados
    $stmtCheck = $pdo->prepare("SELECT COUNT(*) FROM pedidos WHERE id_repartidor = ? AND estado IN ('Pendiente', 'En Ruta', 'En camino', 'Asignado')");
    $stmtCheck->execute([$id_repartidor]);
    if ($stmtCheck->fetchColumn() > 0) {
        echo json_encode(['exito' => false, 'mensaje' => 'No puedes dar de baja a un repartidor con pedidos en ruta.']);
        exit;
    }

    $stmt = $pdo->prepare("UPDATE repartidores SET activo = 0 WHERE id_repartidor = ?");
    $stmt->execute([$id_repartidor]);
    echo json_encode(['exito' => true, 'mensaje' => 'Repartidor dado de baja.']);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al desactivar: ' . $e->getMessage()]);
}
?>