<?php
session_start();
header('Content-Type: application/json');

// Validar seguridad
if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);

$id_producto = $datos['id_producto'] ?? null;

if (!$id_producto) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID de producto no proporcionado.']);
    exit;
}

try {
    // Borrado lógico: cambiamos el estatus a 0 (Inactivo)
    $stmt = $pdo->prepare("UPDATE productos SET activo = 0 WHERE id_producto = ?");
    $stmt->execute([$id_producto]);

    echo json_encode(['exito' => true, 'mensaje' => 'Producto desactivado correctamente.']);

} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al desactivar: ' . $e->getMessage()]);
}
?>