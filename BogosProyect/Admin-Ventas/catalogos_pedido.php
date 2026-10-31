<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    // 1. Obtener lista de clientes (SOLO LOS ACTIVOS)
    $stmtClientes = $pdo->query("SELECT id_cliente, nombre_negocio FROM clientes WHERE activo = 1 ORDER BY nombre_negocio ASC");
    $clientes = $stmtClientes->fetchAll(PDO::FETCH_ASSOC);

    // 2. Obtener lista de repartidores (SOLO LOS ACTIVOS)
    $stmtRepartidores = $pdo->query("
        SELECT r.id_repartidor, u.nombre_completo 
        FROM repartidores r
        INNER JOIN usuarios u ON r.id_usuario = u.id_usuario
        WHERE r.activo = 1
        ORDER BY u.nombre_completo ASC
    ");
    $repartidores = $stmtRepartidores->fetchAll(PDO::FETCH_ASSOC);

    // 3. Obtener productos activos usando precio_unitario
    $stmtProductos = $pdo->query("
        SELECT id_producto, nombre, precio_unitario AS precio_venta, stock_actual 
        FROM productos 
        WHERE activo = 1
        ORDER BY nombre ASC
    ");
    $productos = $stmtProductos->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'exito' => true,
        'clientes' => $clientes,
        'repartidores' => $repartidores,
        'productos' => $productos
    ]);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al cargar los catálogos: ' . $e->getMessage()]);
}
?>