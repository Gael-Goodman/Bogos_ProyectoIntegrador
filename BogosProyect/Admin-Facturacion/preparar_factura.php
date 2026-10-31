<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$id_venta = $_GET['id_venta'] ?? null;

if (!$id_venta) {
    echo json_encode(['exito' => false, 'mensaje' => 'No se especificó la venta.']);
    exit;
}

try {
    // 1. Obtener datos de la empresa emisora (Bogos)
    $stmtEmisor = $pdo->query("SELECT rfc, regimen_fiscal, codigo_postal FROM empresa_emisor LIMIT 1");
    $emisor = $stmtEmisor->fetch(PDO::FETCH_ASSOC);
    
    // Fallbacks por si no han configurado la empresa
    $emisor_rfc = $emisor ? $emisor['rfc'] : 'BOGO261027XYZ';
    $emisor_regimen = $emisor ? $emisor['regimen_fiscal'] . ' - Régimen General' : '612 - Personas Físicas';
    $emisor_cp = $emisor ? $emisor['codigo_postal'] : '66600';

    // 2. Obtener datos de la Venta, Cliente y Factura (si existe)
    $stmtVenta = $pdo->prepare("
        SELECT 
            v.id_venta, v.total, v.forma_pago,
            c.razon_social as cliente_razon, c.nombre_negocio as cliente_negocio,
            c.rfc as cliente_rfc, c.uso_cfdi as cliente_uso, c.codigo_postal_fiscal as cliente_cp,
            f.folio as factura_folio, f.serie as factura_serie, f.uuid as factura_uuid,
            f.sello_emisor as factura_sello_emisor, f.sello_sat as factura_sello_sat,
            DATE_FORMAT(f.fecha_emision, '%d/%m/%Y %H:%i:%s') as factura_fecha
        FROM ventas v
        INNER JOIN clientes c ON v.id_cliente = c.id_cliente
        LEFT JOIN facturas f ON v.id_venta = f.id_venta
        WHERE v.id_venta = ?
    ");
    $stmtVenta->execute([$id_venta]);
    $venta = $stmtVenta->fetch(PDO::FETCH_ASSOC);

    if (!$venta) {
        echo json_encode(['exito' => false, 'mensaje' => 'La venta no existe.']);
        exit;
    }

    // Insertar datos del emisor en el arreglo de la venta
    $venta['emisor_rfc'] = $emisor_rfc;
    $venta['emisor_regimen'] = $emisor_regimen;
    $venta['emisor_cp'] = $emisor_cp;

    // 3. Obtener Conceptos (Productos)
    $stmtConceptos = $pdo->prepare("
        SELECT pr.nombre, dv.cantidad, dv.precio_unitario, dv.subtotal
        FROM detalle_venta dv
        INNER JOIN productos pr ON dv.id_producto = pr.id_producto
        WHERE dv.id_venta = ?
    ");
    $stmtConceptos->execute([$id_venta]);
    $conceptos = $stmtConceptos->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['exito' => true, 'venta' => $venta, 'conceptos' => $conceptos]);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error: ' . $e->getMessage()]);
}
?>