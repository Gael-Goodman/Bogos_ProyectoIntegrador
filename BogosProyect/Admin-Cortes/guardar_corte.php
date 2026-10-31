<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);

$fecha = $datos['fecha'] ?? null;
$total_efectivo = $datos['total_efectivo'] ?? 0;
$total_tarjeta = $datos['total_tarjeta'] ?? 0;
$total_transferencia = $datos['total_transferencia'] ?? 0;
$total_general = $datos['total_general'] ?? 0;
$total_ventas_cant = $datos['total_ventas'] ?? 0;
$id_usuario = $_SESSION['id_usuario'];

if (!$fecha) {
    echo json_encode(['exito' => false, 'mensaje' => 'Falta la fecha del corte.']);
    exit;
}

try {
    // CORREGIDO: Buscar en cortes_diarios
    $stmtCheck = $pdo->prepare("SELECT id_corte FROM cortes_diarios WHERE fecha_corte = ?");
    $stmtCheck->execute([$fecha]);
    if ($stmtCheck->fetch()) {
        echo json_encode(['exito' => false, 'mensaje' => 'El corte para esta fecha ya fue realizado previamente.']);
        exit;
    }

    // CORREGIDO: Insertar en cortes_diarios usando los nombres exactos de tus columnas
    $stmtInsert = $pdo->prepare("
        INSERT INTO cortes_diarios 
        (fecha_corte, total_efectivo, total_tarjeta, total_transferencia, total_ventas, num_ventas, id_usuario_genera) 
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $stmtInsert->execute([
        $fecha, $total_efectivo, $total_tarjeta, $total_transferencia, $total_general, $total_ventas_cant, $id_usuario
    ]);

    echo json_encode(['exito' => true, 'mensaje' => 'Corte guardado correctamente en cortes_diarios.']);

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al guardar corte: ' . $e->getMessage()]);
}
?>