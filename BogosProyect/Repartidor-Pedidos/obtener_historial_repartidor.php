<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Repartidor') {
    echo json_encode(['exito' => false, 'codigo' => 'NO_AUTORIZADO', 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$id_usuario = $_SESSION['id_usuario'];

try {
    // 1. Obtener ID del repartidor
    $stmtRep = $pdo->prepare("SELECT id_repartidor FROM repartidores WHERE id_usuario = ?");
    $stmtRep->execute([$id_usuario]);
    $id_repartidor = $stmtRep->fetchColumn();

    if (!$id_repartidor) {
        echo json_encode(['exito' => false, 'mensaje' => 'Perfil de repartidor no encontrado.']);
        exit;
    }

    // 2. Extraer historial (Estados terminales) limitado a los últimos 40 para no saturar memoria
    $stmtPedidos = $pdo->prepare("
        SELECT 
            p.id_pedido, 
            c.nombre_negocio as cliente, 
            p.total, 
            p.forma_pago,
            p.estado,
            DATE_FORMAT(p.fecha_registro, '%d/%m %H:%i') as fecha_corta
        FROM pedidos p
        INNER JOIN clientes c ON p.id_cliente = c.id_cliente
        WHERE p.id_repartidor = ? 
          AND p.estado IN ('Entregada', 'Cancelada', 'Rechazada', 'No entregada')
        ORDER BY p.id_pedido DESC
        LIMIT 40
    ");
    $stmtPedidos->execute([$id_repartidor]);
    $pedidos = $stmtPedidos->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'exito' => true,
        'pedidos' => $pedidos
    ]);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>