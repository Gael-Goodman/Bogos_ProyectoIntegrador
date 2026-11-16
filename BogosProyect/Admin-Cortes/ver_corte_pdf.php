<?php
/**
 * Muestra (o descarga) el PDF de un corte de caja cerrado.
 *
 *   ver_corte_pdf.php?id_corte=12              -> lo abre en el navegador
 *   ver_corte_pdf.php?id_corte=12&descargar=1  -> lo descarga
 *   ver_corte_pdf.php?id_corte=12&regenerar=1  -> lo vuelve a generar con los datos actuales
 *
 * Si el corte es anterior a esta mejora y no tiene PDF guardado, se genera en ese momento.
 */
ini_set('display_errors', 0);
session_start();

function corteErrorHtml($mensaje, $codigo = 400)
{
    http_response_code($codigo);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!DOCTYPE html><html lang="es"><meta charset="utf-8"><body style="font-family:Arial,sans-serif;color:#555;text-align:center;padding-top:60px;">'
       . '<h3 style="color:#d11f26;">No se pudo mostrar el PDF</h3><p>' . htmlspecialchars($mensaje) . '</p></body></html>';
    exit;
}

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    corteErrorHtml('Acceso denegado. Inicia sesión como administrador.', 403);
}

$id_corte = isset($_GET['id_corte']) ? (int)$_GET['id_corte'] : 0;
if ($id_corte <= 0) {
    corteErrorHtml('No se especificó el corte.');
}

try {
    require_once '../config/conexion.php';
    require_once __DIR__ . '/corte_pdf.php';

    $corte = corteObtener($pdo, $id_corte);
    if (!$corte) {
        corteErrorHtml('El corte #' . $id_corte . ' no existe.', 404);
    }

    $ruta = corteRutaPdf($corte);
    if (empty($_GET['regenerar']) && is_file($ruta) && filesize($ruta) > 0) {
        $contenido = file_get_contents($ruta);
    } else {
        $contenido = corteGenerarYGuardarPdf($pdo, $corte)['contenido'];
    }

    $modo = !empty($_GET['descargar']) ? 'attachment' : 'inline';
    header('Content-Type: application/pdf');
    header('Content-Disposition: ' . $modo . '; filename="' . corteNombreArchivo($corte) . '"');
    header('Content-Length: ' . strlen($contenido));
    header('Cache-Control: private, no-store');
    echo $contenido;

} catch (Throwable $e) {
    corteErrorHtml('Error al generar el PDF: ' . $e->getMessage(), 500);
}
