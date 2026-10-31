<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Repartidor') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$id_pedido = $_GET['id_pedido'] ?? null;

if (!$id_pedido) {
    echo json_encode(['exito' => false, 'mensaje' => 'Folio no proporcionado.']);
    exit;
}

try {
    $stmt = $pdo->prepare("
        SELECT pr.nombre, dp.cantidad 
        FROM detalle_pedido dp 
        INNER JOIN productos pr ON dp.id_producto = pr.id_producto 
        WHERE dp.id_pedido = ?
    ");
    $stmt->execute([$id_pedido]);
    $productos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['exito' => true, 'productos' => $productos]);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>