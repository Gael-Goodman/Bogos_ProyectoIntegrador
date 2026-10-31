<?php
session_start();
header('Content-Type: application/json');

// Validar seguridad
if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    // Extraer los últimos 150 movimientos ordenados del más reciente al más antiguo
    $stmt = $pdo->query("
        SELECT 
            m.id_movimiento,
            p.nombre AS producto_nombre,
            m.tipo,
            m.cantidad,
            m.stock_resultante,
            m.motivo,
            DATE_FORMAT(m.fecha_movimiento, '%d/%m/%Y %h:%i %p') AS fecha_formateada
        FROM movimientos_inventario m
        INNER JOIN productos p ON m.id_producto = p.id_producto
        ORDER BY m.fecha_movimiento DESC
        LIMIT 150
    ");
    
    $movimientos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'exito' => true,
        'movimientos' => $movimientos
    ]);

} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>