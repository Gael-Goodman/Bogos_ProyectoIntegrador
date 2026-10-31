<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$id_pedido = $_GET['id'] ?? null;

if (!$id_pedido) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID no proporcionado']);
    exit;
}

try {
    // 1. Obtener la dirección del cliente y la forma de pago del pedido
    $stmtInfo = $pdo->prepare("
        SELECT c.direccion, p.forma_pago 
        FROM pedidos p 
        INNER JOIN clientes c ON p.id_cliente = c.id_cliente 
        WHERE p.id_pedido = ?
    ");
    $stmtInfo->execute([$id_pedido]);
    $infoPedido = $stmtInfo->fetch(PDO::FETCH_ASSOC);

    // 2. Obtener la lista de productos de ese pedido
    $stmtProd = $pdo->prepare("
        SELECT pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal 
        FROM detalle_pedido dp 
        INNER JOIN productos pr ON dp.id_producto = pr.id_producto 
        WHERE dp.id_pedido = ?
    ");
    $stmtProd->execute([$id_pedido]);
    $productos = $stmtProd->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'exito' => true,
        'direccion' => $infoPedido['direccion'] ?? 'Sin dirección',
        'forma_pago' => $infoPedido['forma_pago'] ?? 'No especificado',
        'productos' => $productos
    ]);
} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>