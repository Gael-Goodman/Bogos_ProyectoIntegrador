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
$id_usuario = $datos['id_usuario'] ?? null;
$telefono = $datos['telefono'] ?? '';
$vehiculo = $datos['vehiculo'] ?? '';
$placas = $datos['placas'] ?? '';

if (!$id_usuario) {
    echo json_encode(['exito' => false, 'mensaje' => 'El usuario es obligatorio.']);
    exit;
}

try {
    if ($id_repartidor) {
        $stmt = $pdo->prepare("UPDATE repartidores SET telefono = ?, vehiculo = ?, placas = ? WHERE id_repartidor = ?");
        $stmt->execute([$telefono, $vehiculo, $placas, $id_repartidor]);
        $mensaje = 'Datos del repartidor actualizados.';
    } else {
        $stmt = $pdo->prepare("INSERT INTO repartidores (id_usuario, telefono, vehiculo, placas, activo) VALUES (?, ?, ?, ?, 1)");
        $stmt->execute([$id_usuario, $telefono, $vehiculo, $placas]);
        $mensaje = 'Repartidor registrado correctamente.';
    }
    echo json_encode(['exito' => true, 'mensaje' => $mensaje]);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al guardar: ' . $e->getMessage()]);
}
?>