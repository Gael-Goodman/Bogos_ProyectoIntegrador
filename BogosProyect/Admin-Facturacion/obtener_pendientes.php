<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';

try {
    // Usamos LEFT JOIN y filtramos donde f.id_factura es NULL (no existe factura)
    $stmt = $pdo->query("
        SELECT 
            v.id_venta, 
            DATE_FORMAT(v.fecha_venta, '%d/%m/%Y %H:%i') as fecha_venta, 
            c.nombre_negocio, 
            c.razon_social, 
            c.rfc, 
            v.forma_pago, 
            v.total 
        FROM ventas v
        INNER JOIN clientes c ON v.id_cliente = c.id_cliente
        LEFT JOIN facturas f ON v.id_venta = f.id_venta
        WHERE f.id_factura IS NULL
        ORDER BY v.fecha_venta DESC
    ");
    
    $ventas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['exito' => true, 'ventas' => $ventas, 'usuario' => ['nombre' => $_SESSION['nombre_completo']]]);
} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error BD: ' . $e->getMessage()]);
}
?>