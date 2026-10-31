<?php
session_start();
header('Content-Type: application/json');

// Validar seguridad
if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'codigo' => 'NO_AUTORIZADO', 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    $stmt = $pdo->query("
        SELECT 
            id_producto, 
            codigo, 
            categoria, 
            nombre, 
            precio_unitario AS precio_venta, 
            stock_actual, 
            stock_minimo 
        FROM productos 
        WHERE activo = 1 
        ORDER BY nombre ASC
    ");
    
    $productos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $usuario = [
        'nombre' => $_SESSION['nombre_completo'] ?? 'Administrador'
    ];

    echo json_encode([
        'exito' => true,
        'usuario' => $usuario,
        'productos' => $productos
    ]);

} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>