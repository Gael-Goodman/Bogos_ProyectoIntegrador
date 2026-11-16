<?php
/**
 * Muestra (o descarga) el PDF de una factura emitida.
 *
 *   ver_factura_pdf.php?id_venta=15              -> lo abre en el navegador
 *   ver_factura_pdf.php?id_venta=15&descargar=1  -> lo descarga
 *   ver_factura_pdf.php?id_venta=15&regenerar=1  -> lo vuelve a generar
 *
 * Si la factura es anterior a esta mejora y no tiene PDF guardado, se genera en ese momento.
 */
ini_set('display_errors', 0);
session_start();

function facturaErrorHtml($mensaje, $codigo = 400)
{
    http_response_code($codigo);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!DOCTYPE html><html lang="es"><meta charset="utf-8"><body style="font-family:Arial,sans-serif;color:#555;text-align:center;padding-top:60px;">'
       . '<h3 style="color:#d11f26;">No se pudo mostrar el PDF</h3><p>' . htmlspecialchars($mensaje) . '</p></body></html>';
    exit;
}

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    facturaErrorHtml('Acceso denegado. Inicia sesión como administrador.', 403);
}

$id_venta = isset($_GET['id_venta']) ? (int)$_GET['id_venta'] : 0;
if ($id_venta <= 0) {
    facturaErrorHtml('No se especificó la venta.');
}

try {
    require_once '../config/conexion.php';
    require_once __DIR__ . '/factura_pdf.php';

    $datos = facturaObtenerDatos($pdo, $id_venta);
    if (!$datos) {
        facturaErrorHtml('La venta #' . $id_venta . ' no existe.', 404);
    }
    if (empty($datos['id_factura'])) {
        facturaErrorHtml('La venta #' . $id_venta . ' aún no ha sido facturada.', 404);
    }

    $ruta = facturaRutaPdf($datos);
    if (empty($_GET['regenerar']) && is_file($ruta) && filesize($ruta) > 0) {
        $contenido = file_get_contents($ruta);
    } else {
        $contenido = facturaGenerarYGuardarPdf($datos)['contenido'];
    }

    $modo = !empty($_GET['descargar']) ? 'attachment' : 'inline';
    header('Content-Type: application/pdf');
    header('Content-Disposition: ' . $modo . '; filename="' . facturaNombreArchivo($datos) . '"');
    header('Content-Length: ' . strlen($contenido));
    header('Cache-Control: private, no-store');
    echo $contenido;

} catch (Throwable $e) {
    facturaErrorHtml('Error al generar el PDF: ' . $e->getMessage(), 500);
}
