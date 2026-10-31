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
$id_repartidor = $datos['id_repartidor'] ?? null;
$forma_pago = $datos['forma_pago'] ?? 'Efectivo'; // <-- CAPTURA DE LA FORMA DE PAGO
$productos = $datos['productos'] ?? [];

if (!$id_cliente || empty($productos)) {
    echo json_encode(['exito' => false, 'mensaje' => 'Datos incompletos para generar el pedido.']);
    exit;
}

try {
    $pdo->beginTransaction();

    $total_pedido = 0;
    foreach ($productos as $item) {
        $total_pedido += (float)$item['subtotal'];
    }

    // Asignar estado automático según si hay repartidor o no
    $estado = $id_repartidor ? 'En Ruta' : 'Pendiente';

    // Insertar pedido incluyendo estado automático y forma_pago
    $stmtPedido = $pdo->prepare("INSERT INTO pedidos (id_cliente, id_repartidor, id_usuario_registro, total, estado, forma_pago) VALUES (?, ?, ?, ?, ?, ?)");
    $stmtPedido->execute([$id_cliente, $id_repartidor, $_SESSION['id_usuario'], $total_pedido, $estado, $forma_pago]);
    $id_pedido = $pdo->lastInsertId();

    // Se elimina 'subtotal' del INSERT porque MySQL lo calcula solo
    $stmtDetalle = $pdo->prepare("INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (?, ?, ?, ?)");
    
    $stmtGetStock = $pdo->prepare("SELECT stock_actual FROM productos WHERE id_producto = ? FOR UPDATE");
    $stmtUpdateStock = $pdo->prepare("UPDATE productos SET stock_actual = ? WHERE id_producto = ?");
    $stmtMovimiento = $pdo->prepare("INSERT INTO movimientos_inventario (id_producto, tipo, cantidad, stock_resultante, id_pedido, id_usuario, motivo) VALUES (?, 'Pedido', ?, ?, ?, ?, 'Registro de nuevo pedido')");

    foreach ($productos as $item) {
        $id_prod = $item['id_producto'];
        $cant = (int)$item['cantidad'];
        
        $stmtGetStock->execute([$id_prod]);
        $stock_actual = (int)$stmtGetStock->fetchColumn();
        
        // Resta corregida
        $stock_resultante = $stock_actual - $cant;

        // Validar stock negativo por seguridad
        if ($stock_resultante < 0) {
            throw new PDOException("Stock insuficiente para el producto ID: $id_prod");
        }

        $stmtDetalle->execute([$id_pedido, $id_prod, $cant, $item['precio_unitario']]);
        
        $stmtUpdateStock->execute([$stock_resultante, $id_prod]);
        
        $cantidad_movimiento = -$cant;
        $stmtMovimiento->execute([$id_prod, $cantidad_movimiento, $stock_resultante, $id_pedido, $_SESSION['id_usuario']]);
    }

    $pdo->commit();
    echo json_encode(['exito' => true, 'mensaje' => 'Pedido generado correctamente.']);

} catch (PDOException $e) {
    $pdo->rollBack();
    echo json_encode(['exito' => false, 'mensaje' => 'Error al guardar: ' . $e->getMessage()]);
}
?>