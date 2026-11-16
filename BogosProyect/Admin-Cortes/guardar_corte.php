<?php
ini_set('display_errors', 0);
session_start();
header('Content-Type: application/json; charset=utf-8');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado.']);
    exit;
}

require_once '../config/conexion.php';
require_once __DIR__ . '/corte_pdf.php';

$datos = json_decode(file_get_contents("php://input"), true);
$fecha = $datos['fecha'] ?? null;
$id_usuario = $_SESSION['id_usuario'];

if (!$fecha || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $fecha)) {
    echo json_encode(['exito' => false, 'mensaje' => 'Falta la fecha del corte o no es válida.']);
    exit;
}

try {
    $stmtCheck = $pdo->prepare("SELECT id_corte FROM cortes_diarios WHERE fecha_corte = ?");
    $stmtCheck->execute([$fecha]);
    if ($stmtCheck->fetch()) {
        echo json_encode(['exito' => false, 'mensaje' => 'El corte para esta fecha ya fue realizado previamente.']);
        exit;
    }

    // MEJORA: los totales se calculan aquí, directo de las ventas en la base de datos,
    // en lugar de confiar en los números que manda el navegador. Así el corte guardado
    // y su PDF siempre coinciden con las ventas reales del día.
    $totales = corteCalcularTotales(corteObtenerVentas($pdo, $fecha));

    $stmtInsert = $pdo->prepare("
        INSERT INTO cortes_diarios
        (fecha_corte, total_efectivo, total_tarjeta, total_transferencia, total_ventas, num_ventas, id_usuario_genera)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $stmtInsert->execute([
        $fecha,
        round($totales['efectivo'], 2),
        round($totales['tarjeta'], 2),
        round($totales['transferencia'], 2),
        round($totales['total_general'], 2),
        $totales['num_ventas'],
        $id_usuario
    ]);
    $id_corte = (int)$pdo->lastInsertId();
    if ($id_corte <= 0) {
        // Por si la tabla no reporta el ID insertado: se busca por fecha
        $stmtCheck->execute([$fecha]);
        $id_corte = (int)$stmtCheck->fetchColumn();
    }

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al guardar corte: ' . $e->getMessage()]);
    exit;
}

// NUEVO: generar y archivar el PDF del corte.
// Si algo falla aquí el corte YA quedó guardado; el PDF se puede generar después desde el historial.
$pdf_generado = false;
try {
    $corte = corteObtener($pdo, $id_corte);
    if ($corte) {
        $pdf_generado = corteGenerarYGuardarPdf($pdo, $corte)['guardado'];
    }
} catch (Throwable $e) {
    $pdf_generado = false;
}

echo json_encode([
    'exito' => true,
    'mensaje' => 'Corte guardado correctamente.',
    'id_corte' => $id_corte,
    'pdf_generado' => $pdf_generado
]);
