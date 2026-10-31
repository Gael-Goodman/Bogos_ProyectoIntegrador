<?php
session_start();
header('Content-Type: application/json');

// SEGURIDAD: Solo acceso a Repartidores
if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Repartidor') {
    echo json_encode(['exito' => false, 'codigo' => 'NO_AUTORIZADO', 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$id_usuario = $_SESSION['id_usuario'];

try {
    // 1. Obtener el ID de repartidor asociado a este usuario
    $stmtRep = $pdo->prepare("SELECT id_repartidor FROM repartidores WHERE id_usuario = ?");
    $stmtRep->execute([$id_usuario]);
    $id_repartidor = $stmtRep->fetchColumn();

    if (!$id_repartidor) {
        echo json_encode(['exito' => false, 'mensaje' => 'Tu usuario no tiene un perfil de repartidor asignado.']);
        exit;
    }

    // 2. Extraer solo los pedidos EN RUTA de este repartidor
    $stmtPedidos = $pdo->prepare("
        SELECT 
            p.id_pedido, 
            c.nombre_negocio as cliente, 
            c.direccion,
            p.total, 
            p.forma_pago
        FROM pedidos p
        INNER JOIN clientes c ON p.id_cliente = c.id_cliente
        WHERE p.id_repartidor = ? AND p.estado = 'En Ruta'
        ORDER BY p.fecha_registro ASC
    ");
    $stmtPedidos->execute([$id_repartidor]);
    $pedidos = $stmtPedidos->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'exito' => true,
        'repartidor' => $_SESSION['nombre_completo'],
        'pedidos' => $pedidos
    ]);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>