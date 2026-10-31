<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);

$id_pedido = $datos['id_pedido'] ?? null;
$nuevo_estado = $datos['estado'] ?? null;
$id_repartidor = $datos['id_repartidor'] ?? null;
$nueva_forma_pago = $datos['forma_pago'] ?? null;
$id_usuario = $_SESSION['id_usuario'];

if (!$id_pedido || !$nuevo_estado) {
    echo json_encode(['exito' => false, 'mensaje' => 'Faltan datos para actualizar el estado.']);
    exit;
}

// BLOQUEO BACKEND: Evitar trucos o errores de red (El doble candado)
if (($nuevo_estado === 'En Ruta' || $nuevo_estado === 'Entregada') && !$id_repartidor) {
    echo json_encode(['exito' => false, 'mensaje' => 'Acción denegada: Un pedido no puede estar en ruta o entregado sin un repartidor asignado.']);
    exit;
}

try {
    $pdo->beginTransaction();

    // 1. Obtener datos actuales del pedido
    $stmtActual = $pdo->prepare("SELECT estado, id_cliente, total, forma_pago FROM pedidos WHERE id_pedido = ? FOR UPDATE");
    $stmtActual->execute([$id_pedido]);
    $pedido = $stmtActual->fetch(PDO::FETCH_ASSOC);

    if (!$pedido) {
        throw new Exception("El pedido no existe.");
    }

    $estado_actual = $pedido['estado'];
    $forma_pago_final = $nueva_forma_pago ? $nueva_forma_pago : $pedido['forma_pago'];

    // 2. Lógica de inventario (Devolver o Descontar)
    $estados_activos = ['Pendiente', 'En Ruta', 'Entregada'];
    $estados_cancelados = ['Cancelada', 'Rechazada', 'No entregada'];
    $accion_stock = 'ninguna';
    
    if (in_array($estado_actual, $estados_activos) && in_array($nuevo_estado, $estados_cancelados)) {
        $accion_stock = 'devolver';
    } elseif (in_array($estado_actual, $estados_cancelados) && in_array($nuevo_estado, $estados_activos)) {
        $accion_stock = 'descontar';
    }

    if ($accion_stock !== 'ninguna') {
        $stmtDetalles = $pdo->prepare("SELECT id_producto, cantidad FROM detalle_pedido WHERE id_pedido = ?");
        $stmtDetalles->execute([$id_pedido]);
        $productos = $stmtDetalles->fetchAll(PDO::FETCH_ASSOC);

        $stmtGetStock = $pdo->prepare("SELECT stock_actual FROM productos WHERE id_producto = ? FOR UPDATE");
        $stmtUpdateStock = $pdo->prepare("UPDATE productos SET stock_actual = ? WHERE id_producto = ?");
        $stmtMovimiento = $pdo->prepare("INSERT INTO movimientos_inventario (id_producto, tipo, cantidad, stock_resultante, id_pedido, id_usuario, motivo) VALUES (?, ?, ?, ?, ?, ?, ?)");

        foreach ($productos as $item) {
            $id_prod = $item['id_producto'];
            $cant_pedido = (int)$item['cantidad'];

            $stmtGetStock->execute([$id_prod]);
            $stock_actual = (int)$stmtGetStock->fetchColumn();

            if ($accion_stock === 'devolver') {
                $nuevo_stock = $stock_actual + $cant_pedido;
                $tipo_mov = 'Cancelacion';
                $cant_mov = $cant_pedido; // Positivo
                $motivo = "Cancelación de pedido #$id_pedido";
            } else {
                if ($stock_actual < $cant_pedido) throw new Exception("Stock insuficiente. No puedes reactivar este pedido.");
                
                // RESTA CORREGIDA PERFECTAMENTE
                $nuevo_stock = $stock_actual - $cant_pedido; 
                
                $tipo_mov = 'Pedido';
                $cant_mov = -$cant_pedido; // Negativo
                $motivo = "Reactivación de pedido #$id_pedido";
            }

            $stmtUpdateStock->execute([$nuevo_stock, $id_prod]);
            $stmtMovimiento->execute([$id_prod, $tipo_mov, $cant_mov, $nuevo_stock, $id_pedido, $id_usuario, $motivo]);
        }
    }

    // 3. Actualizar el pedido principal
    $stmtUpdatePedido = $pdo->prepare("UPDATE pedidos SET estado = ?, id_repartidor = ?, forma_pago = ? WHERE id_pedido = ?");
    $stmtUpdatePedido->execute([$nuevo_estado, $id_repartidor, $forma_pago_final, $id_pedido]);

    // 4. CONVERSIÓN DE PEDIDO A VENTA
    if ($estado_actual !== 'Entregada' && $nuevo_estado === 'Entregada') {
        $stmtInsertVenta = $pdo->prepare("INSERT INTO ventas (id_pedido, id_cliente, id_usuario, total, forma_pago) VALUES (?, ?, ?, ?, ?)");
        $stmtInsertVenta->execute([$id_pedido, $pedido['id_cliente'], $id_usuario, $pedido['total'], $forma_pago_final]);
        $id_venta = $pdo->lastInsertId();

        $stmtGetDetalle = $pdo->prepare("SELECT id_producto, cantidad, precio_unitario FROM detalle_pedido WHERE id_pedido = ?");
        $stmtGetDetalle->execute([$id_pedido]);
        $detalles_pedido = $stmtGetDetalle->fetchAll(PDO::FETCH_ASSOC);

        $stmtInsertDetVenta = $pdo->prepare("INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario) VALUES (?, ?, ?, ?)");
        foreach ($detalles_pedido as $det) {
            $stmtInsertDetVenta->execute([$id_venta, $det['id_producto'], $det['cantidad'], $det['precio_unitario']]);
        }
    } 
    elseif ($estado_actual === 'Entregada' && $nuevo_estado !== 'Entregada') {
        $stmtGetVenta = $pdo->prepare("SELECT id_venta FROM ventas WHERE id_pedido = ?");
        $stmtGetVenta->execute([$id_pedido]);
        $id_venta = $stmtGetVenta->fetchColumn();

        if ($id_venta) {
            $pdo->prepare("DELETE FROM detalle_venta WHERE id_venta = ?")->execute([$id_venta]);
            $pdo->prepare("DELETE FROM ventas WHERE id_pedido = ?")->execute([$id_pedido]);
        }
    }

    // Confirmar transacción y responder a JS
    $pdo->commit();
    echo json_encode(['exito' => true, 'mensaje' => 'Actualización y sincronización correctas.']);

} catch (Exception $e) {
    $pdo->rollBack();
    echo json_encode(['exito' => false, 'mensaje' => 'Error al actualizar: ' . $e->getMessage()]);
}
?>