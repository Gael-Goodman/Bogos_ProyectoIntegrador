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
    // 1. Verificar si el cliente tiene pedidos pendientes o por asignar
    // Ajusta los nombres de los estados ('Pendiente', 'Asignado') según los uses en tu BD
    $stmtCheck = $pdo->prepare("SELECT COUNT(*) FROM pedidos WHERE id_cliente = ? AND estado IN ('Pendiente', 'Asignado', 'En camino')");
    $stmtCheck->execute([$id_cliente]);
    $pedidos_activos = $stmtCheck->fetchColumn();

    if ($pedidos_activos > 0) {
        echo json_encode(['exito' => false, 'mensaje' => 'No puedes enviar a la papelera a un cliente con pedidos en curso.']);
        exit;
    }

    // 2. Si no tiene pedidos activos, hacemos el borrado lógico
    $stmt = $pdo->prepare("UPDATE clientes SET activo = 0 WHERE id_cliente = ?");
    $stmt->execute([$id_cliente]);
    echo json_encode(['exito' => true, 'mensaje' => 'Tiendita enviada a papelera.']);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al desactivar: ' . $e->getMessage()]);
}
?>