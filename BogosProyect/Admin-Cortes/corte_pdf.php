<?php
/**
 * Funciones para generar, guardar y localizar el PDF de un corte de caja.
 * Lo usan guardar_corte.php (al cerrar caja) y ver_corte_pdf.php (al consultarlo).
 *
 * Los PDF se guardan en Admin-Cortes/pdf/ con el nombre Corte_AAAA-MM-DD_N.pdf
 */
require_once __DIR__ . '/../libs/PdfBogos.php';

const CORTE_DIR_PDF = __DIR__ . '/pdf';
const CORTE_LOGO    = __DIR__ . '/../CSS-IMAGENES/imagenes/logo.jpg';

/** Ventas de una fecha (misma consulta que usa la pantalla de cortes). */
function corteObtenerVentas(PDO $pdo, $fecha)
{
    $stmt = $pdo->prepare("
        SELECT v.id_venta, v.id_pedido, c.nombre_negocio AS cliente, v.forma_pago, v.total, v.fecha_venta
        FROM ventas v
        INNER JOIN clientes c ON v.id_cliente = c.id_cliente
        WHERE DATE(v.fecha_venta) = ?
        ORDER BY v.fecha_venta ASC
    ");
    $stmt->execute([$fecha]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

/** Suma las ventas por forma de pago (misma regla que la pantalla: Efectivo / Tarjeta / Transferencia). */
function corteCalcularTotales(array $ventas)
{
    $t = [
        'efectivo' => 0.0, 'tarjeta' => 0.0, 'transferencia' => 0.0, 'otros' => 0.0,
        'cant_efectivo' => 0, 'cant_tarjeta' => 0, 'cant_transferencia' => 0, 'cant_otros' => 0,
        'total_general' => 0.0, 'num_ventas' => count($ventas),
    ];
    foreach ($ventas as $v) {
        $monto = (float)$v['total'];
        switch (trim((string)$v['forma_pago'])) {
            case 'Efectivo':      $t['efectivo'] += $monto;      $t['cant_efectivo']++;      break;
            case 'Tarjeta':       $t['tarjeta'] += $monto;       $t['cant_tarjeta']++;       break;
            case 'Transferencia': $t['transferencia'] += $monto; $t['cant_transferencia']++; break;
            default:              $t['otros'] += $monto;         $t['cant_otros']++;
        }
    }
    $t['total_general'] = $t['efectivo'] + $t['tarjeta'] + $t['transferencia'];
    return $t;
}

/** Datos del corte + nombre de quien lo cerró. Devuelve false si no existe. */
function corteObtener(PDO $pdo, $id_corte)
{
    $stmt = $pdo->prepare("
        SELECT c.*, COALESCE(u.nombre_completo, 'Usuario eliminado') AS usuario_cierre
        FROM cortes_diarios c
        LEFT JOIN usuarios u ON c.id_usuario_genera = u.id_usuario
        WHERE c.id_corte = ?
    ");
    $stmt->execute([$id_corte]);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

function corteNombreArchivo(array $corte)
{
    $fecha = preg_replace('/[^0-9\-]/', '', substr((string)$corte['fecha_corte'], 0, 10));
    return 'Corte_' . $fecha . '_' . (int)$corte['id_corte'] . '.pdf';
}

function corteRutaPdf(array $corte)
{
    return CORTE_DIR_PDF . '/' . corteNombreArchivo($corte);
}

function corteFechaLarga($fecha)
{
    $dias  = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    $meses = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    $ts = strtotime(substr((string)$fecha, 0, 10) . ' 12:00:00');
    if (!$ts) return (string)$fecha;
    return ucfirst($dias[(int)date('w', $ts)]) . ' ' . (int)date('j', $ts) . ' de ' . $meses[(int)date('n', $ts)] . ' de ' . date('Y', $ts);
}

function corteDinero($n)
{
    return '$' . number_format((float)$n, 2, '.', ',');
}

/** Fecha y hora actuales tomadas de la base de datos (misma zona horaria que las ventas). */
function corteAhora(PDO $pdo)
{
    try {
        $ts = strtotime((string)$pdo->query("SELECT NOW()")->fetchColumn());
        if ($ts) return date('d/m/Y H:i', $ts);
    } catch (Throwable $e) { /* se usa la hora de PHP */ }
    return date('d/m/Y H:i');
}

/**
 * Construye el PDF del corte y devuelve su contenido binario.
 */
function corteGenerarPdf(PDO $pdo, array $corte)
{
    $fecha  = substr((string)$corte['fecha_corte'], 0, 10);
    $ventas = corteObtenerVentas($pdo, $fecha);
    $calc   = corteCalcularTotales($ventas);

    // Los importes oficiales son los que quedaron guardados al cerrar la caja
    $efectivo      = (float)$corte['total_efectivo'];
    $tarjeta       = (float)$corte['total_tarjeta'];
    $transferencia = (float)$corte['total_transferencia'];
    $total         = (float)$corte['total_ventas'];
    $numVentas     = isset($corte['num_ventas']) ? (int)$corte['num_ventas'] : $calc['num_ventas'];

    $azul = [11, 26, 69];
    $rojo = [209, 31, 38];
    $M = 36;                       // margen
    $W = PdfBogos::ANCHO - 2 * $M; // ancho útil

    $pdf = new PdfBogos();
    $pdf->titulo = 'Corte de caja #' . $corte['id_corte'] . ' - ' . $fecha;
    $pdf->pieIzquierdo = 'Botanas Bogos · Corte de caja #' . $corte['id_corte'] . ' · Generado el ' . corteAhora($pdo);

    // ---------- Encabezado ----------
    $pdf->colorRelleno(...$azul);
    $pdf->rect(0, 0, PdfBogos::ANCHO, 86);
    $pdf->colorRelleno(...$rojo);
    $pdf->rect(0, 86, PdfBogos::ANCHO, 4);

    $xTitulo = $M;
    if ($pdf->imagenJpeg(CORTE_LOGO, $M, 13, 60) > 0) $xTitulo = $M + 74;

    $pdf->colorTexto(255, 255, 255);
    $pdf->fuente('B', 19);
    $pdf->texto($xTitulo, 42, 'BOTANAS BOGOS');
    $pdf->fuente('', 11);
    $pdf->texto($xTitulo, 60, 'Corte de caja diario');
    $pdf->fuente('B', 17);
    $pdf->texto($M + $W, 42, 'CORTE #' . $corte['id_corte'], 'R');
    $pdf->fuente('', 10.5);
    $pdf->texto($M + $W, 60, corteFechaLarga($fecha), 'R');

    // ---------- Datos generales ----------
    $y = 116;
    $col = $W / 3;
    $datos = [
        ['FECHA DEL CORTE', date('d/m/Y', strtotime($fecha))],
        ['CERRADO POR', $corte['usuario_cierre']],
        ['VENTAS REGISTRADAS', $numVentas . ($numVentas == 1 ? ' venta' : ' ventas')],
    ];
    foreach ($datos as $i => $d) {
        $x = $M + $i * $col;
        $pdf->fuente('B', 7.5);
        $pdf->colorTexto(110, 117, 125);
        $pdf->texto($x, $y, $d[0]);
        $pdf->fuente('B', 11);
        $pdf->colorTexto(33, 37, 41);
        $pdf->texto($x, $y + 15, $pdf->recortar($d[1], $col - 10));
    }

    // ---------- Tarjetas de resumen ----------
    $y = 150;
    $sep = 10;
    $wc = ($W - 3 * $sep) / 4;
    $hc = 58;
    $tarjetas = [
        ['EFECTIVO EN CAJA',   $efectivo,      $calc['cant_efectivo'],      [25, 135, 84]],
        ['TARJETA (TERMINAL)', $tarjeta,       $calc['cant_tarjeta'],       [13, 110, 253]],
        ['TRANSFERENCIAS',     $transferencia, $calc['cant_transferencia'], [13, 160, 190]],
    ];
    foreach ($tarjetas as $i => $t) {
        $x = $M + $i * ($wc + $sep);
        $pdf->colorRelleno(246, 247, 249);
        $pdf->rect($x, $y, $wc, $hc);
        $pdf->colorRelleno(...$t[3]);
        $pdf->rect($x, $y, 4, $hc);
        $pdf->fuente('B', 7.5);
        $pdf->colorTexto(110, 117, 125);
        $pdf->texto($x + 12, $y + 16, $t[0]);
        $pdf->fuente('B', 15);
        $pdf->colorTexto(...$t[3]);
        $pdf->texto($x + 12, $y + 36, corteDinero($t[1]));
        $pdf->fuente('', 8);
        $pdf->colorTexto(110, 117, 125);
        $pdf->texto($x + 12, $y + 50, $t[2] . ' venta(s)');
    }
    $x = $M + 3 * ($wc + $sep);
    $pdf->colorRelleno(...$azul);
    $pdf->rect($x, $y, $wc, $hc);
    $pdf->fuente('B', 7.5);
    $pdf->colorTexto(190, 196, 214);
    $pdf->texto($x + 12, $y + 16, 'TOTAL DEL CORTE');
    $pdf->fuente('B', 15);
    $pdf->colorTexto(255, 255, 255);
    $pdf->texto($x + 12, $y + 36, corteDinero($total));
    $pdf->fuente('', 8);
    $pdf->colorTexto(190, 196, 214);
    $pdf->texto($x + 12, $y + 50, $numVentas . ' entrega(s) en total');

    // ---------- Tabla de ventas ----------
    $y = 236;
    $pdf->fuente('B', 11);
    $pdf->colorTexto(...$azul);
    $pdf->texto($M, $y, 'Detalle de ventas del día');
    $y += 10;

    // x inicial y ancho de cada columna
    $cols = [
        ['Venta #',        $M,        60],
        ['Pedido',         $M + 60,   65],
        ['Cliente',        $M + 125, 205],
        ['Forma de pago',  $M + 330,  95],
        ['Hora',           $M + 425,  45],
        ['Total',          $M + 470,  70],
    ];
    $altoFila = 18;
    $limite = PdfBogos::ALTO - 56;

    $encabezadoTabla = function ($y) use ($pdf, $cols, $M, $W, $azul, $altoFila) {
        $pdf->colorRelleno(...$azul);
        $pdf->rect($M, $y, $W, $altoFila);
        $pdf->fuente('B', 8.5);
        $pdf->colorTexto(255, 255, 255);
        foreach ($cols as $i => $c) {
            if ($i === 5) $pdf->texto($c[1] + $c[2] - 8, $y + 12, $c[0], 'R');
            else $pdf->texto($c[1] + 8, $y + 12, $c[0]);
        }
        return $y + $altoFila;
    };

    $saltoPagina = function () use ($pdf, $M, $corte, $azul) {
        $pdf->nuevaPagina();
        $pdf->fuente('B', 9);
        $pdf->colorTexto(...$azul);
        $pdf->texto($M, 44, 'Corte de caja #' . $corte['id_corte'] . ' (continuación)');
        return 54;
    };

    $y = $encabezadoTabla($y);

    if (count($ventas) === 0) {
        $pdf->fuente('I', 9.5);
        $pdf->colorTexto(110, 117, 125);
        $pdf->texto($M + $W / 2, $y + 20, 'No hay ventas registradas en esta fecha.', 'C');
        $y += 34;
    }

    foreach ($ventas as $i => $v) {
        if ($y + $altoFila > $limite) {
            $y = $encabezadoTabla($saltoPagina());
        }
        if ($i % 2 === 1) {
            $pdf->colorRelleno(246, 247, 249);
            $pdf->rect($M, $y, $W, $altoFila);
        }
        $ts = strtotime((string)$v['fecha_venta']);
        $pago = trim((string)$v['forma_pago']) !== '' ? $v['forma_pago'] : 'No especificada';

        $pdf->colorTexto(33, 37, 41);
        $pdf->fuente('B', 9);
        $pdf->texto($cols[0][1] + 8, $y + 12, '#' . $v['id_venta']);
        $pdf->fuente('', 9);
        $pdf->texto($cols[1][1] + 8, $y + 12, '#' . $v['id_pedido']);
        $pdf->texto($cols[2][1] + 8, $y + 12, $pdf->recortar($v['cliente'], $cols[2][2] - 12));
        $pdf->texto($cols[3][1] + 8, $y + 12, $pdf->recortar($pago, $cols[3][2] - 12));
        $pdf->texto($cols[4][1] + 8, $y + 12, $ts ? date('H:i', $ts) : '-');
        $pdf->fuente('B', 9);
        $pdf->texto($cols[5][1] + $cols[5][2] - 8, $y + 12, corteDinero($v['total']), 'R');
        $y += $altoFila;
    }

    // Línea de total
    if ($y + 26 > $limite) $y = $saltoPagina();
    $pdf->colorLinea(...$azul);
    $pdf->grosorLinea(1);
    $pdf->linea($M, $y, $M + $W, $y);
    $pdf->fuente('B', 10.5);
    $pdf->colorTexto(...$azul);
    $pdf->texto($cols[4][1] + $cols[4][2], $y + 17, 'TOTAL DEL CORTE', 'R');
    $pdf->texto($M + $W - 8, $y + 17, corteDinero($total), 'R');
    $y += 38;

    // ---------- Avisos ----------
    $avisos = [];
    if ($calc['cant_otros'] > 0) {
        $avisos[] = 'Hay ' . $calc['cant_otros'] . ' venta(s) con otra forma de pago o sin especificar por '
                  . corteDinero($calc['otros']) . '; aparecen en el detalle pero no se suman al total del corte.';
    }
    if (abs($calc['total_general'] - $total) > 0.009) {
        $avisos[] = 'Las ventas listadas suman ' . corteDinero($calc['total_general']) . ' y el corte se cerró por '
                  . corteDinero($total) . '. La diferencia corresponde a ventas registradas o modificadas después del cierre.';
    }
    if ($avisos) {
        $pdf->fuente('I', 8.5);
        foreach ($avisos as $a) {
            $lineas = $pdf->partir('Nota: ' . $a, $W);
            if ($y + count($lineas) * 11 > $limite) $y = $saltoPagina();
            $pdf->colorTexto(...$rojo);
            foreach ($lineas as $l) { $pdf->texto($M, $y, $l); $y += 11; }
            $y += 4;
        }
    }

    // ---------- Firmas ----------
    if ($y + 80 > $limite) $y = $saltoPagina();
    $y += 56;
    $wf = 190;
    $pdf->colorLinea(90, 90, 90);
    $pdf->grosorLinea(0.7);
    $firmas = [[$M + 40, 'Entregó (cierre de caja)', $corte['usuario_cierre']], [$M + $W - 40 - $wf, 'Recibió / Revisó', '']];
    foreach ($firmas as $f) {
        $pdf->linea($f[0], $y, $f[0] + $wf, $y);
        $pdf->fuente('B', 8.5);
        $pdf->colorTexto(33, 37, 41);
        $pdf->texto($f[0] + $wf / 2, $y + 12, $f[1], 'C');
        if ($f[2] !== '') {
            $pdf->fuente('', 8.5);
            $pdf->colorTexto(110, 117, 125);
            $pdf->texto($f[0] + $wf / 2, $y + 23, $pdf->recortar($f[2], $wf), 'C');
        }
    }

    return $pdf->salida();
}

/**
 * Genera el PDF del corte y lo guarda en Admin-Cortes/pdf/.
 * Devuelve ['contenido' => bytes, 'guardado' => bool, 'archivo' => nombre].
 * Si la carpeta no se puede escribir, el PDF se devuelve igual (solo no queda archivado).
 */
function corteGenerarYGuardarPdf(PDO $pdo, array $corte)
{
    $contenido = corteGenerarPdf($pdo, $corte);
    $guardado = false;

    if (!is_dir(CORTE_DIR_PDF)) @mkdir(CORTE_DIR_PDF, 0775, true);
    if (is_dir(CORTE_DIR_PDF)) {
        // Impide abrir los PDF escribiendo la URL directa; solo se sirven desde ver_corte_pdf.php (con sesión)
        $ht = CORTE_DIR_PDF . '/.htaccess';
        if (!is_file($ht)) @file_put_contents($ht, "Require all denied\n");
        $guardado = @file_put_contents(corteRutaPdf($corte), $contenido, LOCK_EX) !== false;
    }

    return ['contenido' => $contenido, 'guardado' => $guardado, 'archivo' => corteNombreArchivo($corte)];
}
