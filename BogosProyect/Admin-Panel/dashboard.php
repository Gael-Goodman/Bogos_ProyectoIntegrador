<?php
// Iniciar sesión para validar el acceso
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
    // 1. Ventas del día (SOLO DINERO REAL: Pedidos 'Entregada' cobrados hoy)
    $stmtVentas = $pdo->query("SELECT COALESCE(SUM(total), 0) as total_ventas FROM pedidos WHERE estado = 'Entregada' AND DATE(fecha_actualizacion) = CURDATE()");
    $ventasDia = $stmtVentas->fetch(PDO::FETCH_ASSOC)['total_ventas'];

    // 2. Pedidos pendientes (Coincide con 'Pendiente')
    $stmtPendientes = $pdo->query("SELECT COUNT(*) as total_pendientes FROM pedidos WHERE estado = 'Pendiente'");
    $pedidosPendientes = $stmtPendientes->fetch(PDO::FETCH_ASSOC)['total_pendientes'];

    // 3. Entregas de hoy (Busca 'Entregada' y usa fecha_actualizacion)
    $stmtEntregas = $pdo->query("SELECT COUNT(*) as total_entregas FROM pedidos WHERE estado = 'Entregada' AND DATE(fecha_actualizacion) = CURDATE()");
    $entregasHoy = $stmtEntregas->fetch(PDO::FETCH_ASSOC)['total_entregas'];

    // 4. Stock bajo (Usa stock_actual y activo = 1)
    $stmtStock = $pdo->query("SELECT COUNT(*) as productos_riesgo FROM productos WHERE stock_actual <= stock_minimo AND activo = 1");
    $stockBajo = $stmtStock->fetch(PDO::FETCH_ASSOC)['productos_riesgo'];

    // 5. Tabla de Últimos Pedidos (Usa c.nombre_negocio)
    $sqlRecientes = "
        SELECT p.id_pedido, c.nombre_negocio as cliente, p.total, p.estado 
        FROM pedidos p
        INNER JOIN clientes c ON p.id_cliente = c.id_cliente
        ORDER BY p.fecha_registro DESC 
        LIMIT 5
    ";
    $stmtRecientes = $pdo->query($sqlRecientes);
    $pedidosRecientes = $stmtRecientes->fetchAll(PDO::FETCH_ASSOC);

    // 6. Datos para la gráfica: Ganancias reales de los últimos 7 días (Solo 'Entregada')
    $sqlGrafica = "
        SELECT DATE(fecha_actualizacion) as fecha, SUM(total) as total_dia 
        FROM pedidos 
        WHERE estado = 'Entregada' 
          AND fecha_actualizacion >= DATE_SUB(CURDATE(), INTERVAL 6 DAY) 
        GROUP BY DATE(fecha_actualizacion) 
        ORDER BY fecha ASC
    ";
    $stmtGrafica = $pdo->query($sqlGrafica);
    $ventasSemana = $stmtGrafica->fetchAll(PDO::FETCH_ASSOC);

    // 7. ENVIAR TODO JUNTO AL FINAL DEL ÉXITO
    echo json_encode([
        'exito' => true,
        'usuario' => [
            'nombre' => $_SESSION['nombre_completo']
        ],
        'kpis' => [
            'ventas_dia' => (float)$ventasDia,
            'pedidos_pendientes' => (int)$pedidosPendientes,
            'entregas_hoy' => (int)$entregasHoy,
            'stock_bajo' => (int)$stockBajo
        ],
        'pedidos_recientes' => $pedidosRecientes,
        'grafica' => $ventasSemana 
    ]);

} catch (PDOException $e) {
    echo json_encode([
        'exito' => false, 
        'mensaje' => 'Error al consultar los datos del panel: ' . $e->getMessage()
    ]);
}
?>