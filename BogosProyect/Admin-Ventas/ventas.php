<?php
session_start();
header('Content-Type: application/json');

// Validación de seguridad
if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode([
        'exito' => false, 
        'codigo' => 'NO_AUTORIZADO', 
        'mensaje' => 'Acceso denegado. Inicie sesión como Administrador.'
    ]);
    exit;
}

require_once '../config/conexion.php';

try {
    // Extraer todos los pedidos con el nombre del cliente, del repartidor y FORMA DE PAGO
    $sql = "
        SELECT 
            p.id_pedido, 
            c.nombre_negocio as cliente, 
            COALESCE(u.nombre_completo, 'Sin asignar') as repartidor,
            p.id_repartidor,
            p.forma_pago, /* <-- CAMPO AGREGADO PARA EL MÉTODO DE PAGO */
            p.fecha_registro, 
            p.total, 
            p.estado 
        FROM pedidos p
        INNER JOIN clientes c ON p.id_cliente = c.id_cliente
        LEFT JOIN repartidores r ON p.id_repartidor = r.id_repartidor
        LEFT JOIN usuarios u ON r.id_usuario = u.id_usuario
        ORDER BY p.fecha_registro DESC
    ";
    
    $stmt = $pdo->query($sql);
    $pedidos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'exito' => true,
        'usuario' => [
            'nombre' => $_SESSION['nombre_completo']
        ],
        'pedidos' => $pedidos
    ]);

} catch (PDOException $e) {
    echo json_encode([
        'exito' => false, 
        'mensaje' => 'Error al consultar los pedidos: ' . $e->getMessage()
    ]);
}
?>