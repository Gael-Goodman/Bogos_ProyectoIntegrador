<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Repartidor') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);

$id_pedido = $datos['id_pedido'] ?? null;
$nuevo_estado = $datos['estado'] ?? null; // Entregada, No entregada, Rechazada, Cancelada
$id_usuario = $_SESSION['id_usuario'];

if (!$id_pedido || !$nuevo_estado) {
    echo json_encode(['exito' => false, 'mensaje' => 'Faltan datos para actualizar el estado.']);
    exit;
}

try {
    $pdo->beginTransaction();

    // 1. Verificar identidad del repartidor
    $stmtRep = $pdo->prepare("SELECT id_repartidor FROM repartidores WHERE id_usuario = ?");
    $stmtRep->execute([$id_usuario]);
    $id_repartidor = $stmtRep->fetchColumn();

    // 2. Obtener y asegurar que el pedido pertenece a este repartidor
    $stmtActual = $pdo->prepare("SELECT estado, id_cliente, total, forma_pago, id_repartidor FROM pedidos WHERE id_pedido = ? FOR UPDATE");
    $stmtActual->execute([$id_pedido]);
    $pedido = $stmtActual->fetch(PDO::FETCH_ASSOC);

    if (!$pedido || $pedido['id_repartidor'] != $id_repartidor) {
        throw new Exception("El pedido no existe o no te pertenece.");
    }

    $estado_actual = $pedido['estado'];

    // 3. Lógica de inventario (De "En Ruta" a problemas -> Devolver stock)
    $estados_cancelados = ['Cancelada', 'Rechazada', 'No entregada'];
    
    if ($estado_actual === 'En Ruta' && in_array($nuevo_estado, $estados_cancelados)) {
        
        $stmtDetalles = $pdo->prepare("SELECT id_producto, cantidad FROM detalle_pedido WHERE id_pedido = ?");
        $stmtDetalles->execute([$id_pedido]);
        $productos = $stmtDetalles->fetchAll(PDO::FETCH_ASSOC);

        $stmtGetStock = $pdo->prepare("SELECT stock_actual FROM productos WHERE id_producto = ? FOR UPDATE");
        $stmtUpdateStock = $pdo->prepare("UPDATE productos SET stock_actual = ? WHERE id_producto = ?");
        $stmtMovimiento = $pdo->prepare("INSERT INTO movimientos_inventario (id_producto, tipo, cantidad, stock_resultante, id_pedido, id_usuario, motivo) VALUES (?, 'Cancelacion', ?, ?, ?, ?, ?)");

        foreach ($productos as $item) {
            $id_prod = $item['id_producto'];
            $cant_pedido = (int)$item['cantidad'];

            $stmtGetStock->execute([$id_prod]);
            $stock_actual = (int)$stmtGetStock->fetchColumn();

            $nuevo_stock = $stock_actual + $cant_pedido;
            $motivo = "Reporte de repartidor: $nuevo_estado (Pedido #$id_pedido)";

            $stmtUpdateStock->execute([$nuevo_stock, $id_prod]);
            $stmtMovimiento->execute([$id_prod, $cant_pedido, $nuevo_stock, $id_pedido, $id_usuario, $motivo]);
        }
    }

    // 4. Actualizar el estado del pedido
    $stmtUpdatePedido = $pdo->prepare("UPDATE pedidos SET estado = ? WHERE id_pedido = ?");
    $stmtUpdatePedido->execute([$nuevo_estado, $id_pedido]);

    // 5. CONVERSIÓN DE PEDIDO A VENTA
    if ($estado_actual === 'En Ruta' && $nuevo_estado === 'Entregada') {
        $stmtInsertVenta = $pdo->prepare("INSERT INTO ventas (id_pedido, id_cliente, id_usuario, total, forma_pago) VALUES (?, ?, ?, ?, ?)");
        $stmtInsertVenta->execute([$id_pedido, $pedido['id_cliente'], $id_usuario, $pedido['total'], $pedido['forma_pago']]);
        $id_venta = $pdo->lastInsertId();

        $stmtGetDetalle = $pdo->prepare("SELECT id_producto, cantidad, precio_unitario FROM detalle_pedido WHERE id_pedido = ?");
        $stmtGetDetalle->execute([$id_pedido]);
        $detalles_pedido = $stmtGetDetalle->fetchAll(PDO::FETCH_ASSOC);

        $stmtInsertDetVenta = $pdo->prepare("INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario) VALUES (?, ?, ?, ?)");
        foreach ($detalles_pedido as $det) {
            $stmtInsertDetVenta->execute([$id_venta, $det['id_producto'], $det['cantidad'], $det['precio_unitario']]);
        }
    }

    $pdo->commit();
    echo json_encode(['exito' => true, 'mensaje' => 'Ruta actualizada.']);

} catch (Exception $e) {
    $pdo->rollBack();
    echo json_encode(['exito' => false, 'mensaje' => 'Error: ' . $e->getMessage()]);
}
?>