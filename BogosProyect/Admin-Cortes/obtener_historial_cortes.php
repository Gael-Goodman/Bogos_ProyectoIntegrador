<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';

try {
    // CORREGIDO: Extraer de cortes_diarios unida a usuarios mediante id_usuario_genera
    $stmt = $pdo->query("
        SELECT 
            c.id_corte, 
            DATE_FORMAT(c.fecha_corte, '%d/%m/%Y') as fecha_corte, 
            c.total_efectivo, 
            c.total_tarjeta, 
            c.total_transferencia, 
            c.total_ventas as total_general, 
            COALESCE(u.nombre_completo, 'Usuario Eliminado') as usuario_cierre
        FROM cortes_diarios c
        LEFT JOIN usuarios u ON c.id_usuario_genera = u.id_usuario
        ORDER BY c.fecha_corte DESC
    ");
    $cortes = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['exito' => true, 'cortes' => $cortes]);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al obtener historial: ' . $e->getMessage()]);
}
?>