<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$fecha = $_GET['fecha'] ?? date('Y-m-d');

try {
    // CORREGIDO: Buscar en cortes_diarios
    $stmtCorte = $pdo->prepare("SELECT *, total_ventas as total_general FROM cortes_diarios WHERE fecha_corte = ?");
    $stmtCorte->execute([$fecha]);
    $corte_data = $stmtCorte->fetch(PDO::FETCH_ASSOC);
    $corte_cerrado = $corte_data ? true : false;

    // Consultar ventas entregadas
    $stmtVentas = $pdo->prepare("
        SELECT 
            v.id_venta, 
            v.id_pedido, 
            c.nombre_negocio as cliente, 
            v.forma_pago, 
            v.total, 
            DATE_FORMAT(v.fecha_venta, '%H:%i') as hora 
        FROM ventas v
        INNER JOIN clientes c ON v.id_cliente = c.id_cliente
        WHERE DATE(v.fecha_venta) = ?
        ORDER BY v.fecha_venta DESC
    ");
    $stmtVentas->execute([$fecha]);
    $ventas = $stmtVentas->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'exito' => true,
        'usuario' => ['nombre' => $_SESSION['nombre_completo']],
        'ventas' => $ventas,
        'corte_cerrado' => $corte_cerrado,
        'corte_data' => $corte_data
    ]);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error en BD: ' . $e->getMessage()]);
}
?>