<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';

try {
    $stmt = $pdo->query("
        SELECT 
            f.folio, 
            f.serie, 
            f.uuid, 
            DATE_FORMAT(f.fecha_emision, '%d/%m/%Y %H:%i') as fecha_emision,
            c.nombre_negocio, 
            c.razon_social, 
            f.id_venta, 
            f.total
        FROM facturas f
        INNER JOIN ventas v ON f.id_venta = v.id_venta
        INNER JOIN clientes c ON f.id_cliente = c.id_cliente
        ORDER BY f.fecha_emision DESC
    ");
    
    $facturas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['exito' => true, 'facturas' => $facturas]);
} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error BD: ' . $e->getMessage()]);
}
?>