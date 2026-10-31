<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);
$id_venta = $datos['id_venta'] ?? null;

if (!$id_venta) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID de venta no recibido.']);
    exit;
}

try {
    $pdo->beginTransaction();

    // 1. Validar que la venta exista y no esté facturada ya
    $stmtCheck = $pdo->prepare("SELECT v.id_cliente, v.total, f.id_factura FROM ventas v LEFT JOIN facturas f ON v.id_venta = f.id_venta WHERE v.id_venta = ? FOR UPDATE");
    $stmtCheck->execute([$id_venta]);
    $venta = $stmtCheck->fetch(PDO::FETCH_ASSOC);

    if (!$venta) throw new Exception("La venta no existe.");
    if ($venta['id_factura']) throw new Exception("Esta venta ya fue facturada.");

    // 2. Obtener y actualizar Folio de la Empresa Emisora
    $stmtEmisor = $pdo->query("SELECT serie_factura, folio_siguiente FROM empresa_emisor LIMIT 1 FOR UPDATE");
    $emisor = $stmtEmisor->fetch(PDO::FETCH_ASSOC);
    
    $serie = $emisor ? $emisor['serie_factura'] : 'F';
    $folio_actual = $emisor ? $emisor['folio_siguiente'] : 1;
    $folio_formateado = str_pad($folio_actual, 4, '0', STR_PAD_LEFT); // Ej: 0001
    
    if ($emisor) {
        $pdo->query("UPDATE empresa_emisor SET folio_siguiente = folio_siguiente + 1");
    }

    // 3. Generar UUID (Folio Fiscal Simulado) y Sellos Aleatorios
    $uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
    $selloEmisor = base64_encode(random_bytes(64)) . "==";
    $selloSat = base64_encode(random_bytes(64)) . "==";

    // 4. Insertar la nueva factura
    $stmtInsert = $pdo->prepare("
        INSERT INTO facturas (folio, serie, id_venta, id_cliente, total, uuid, sello_emisor, sello_sat) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmtInsert->execute([
        $folio_formateado, $serie, $id_venta, $venta['id_cliente'], $venta['total'], $uuid, $selloEmisor, $selloSat
    ]);

    $pdo->commit();
    echo json_encode(['exito' => true, 'mensaje' => 'Factura timbrada exitosamente.']);

} catch (Exception $e) {
    $pdo->rollBack();
    echo json_encode(['exito' => false, 'mensaje' => 'Error al generar: ' . $e->getMessage()]);
}
?>