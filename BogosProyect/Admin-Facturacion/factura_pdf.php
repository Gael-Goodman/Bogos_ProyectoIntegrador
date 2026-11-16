<?php
/**
 * Funciones para generar, guardar y localizar el PDF de una factura.
 * Lo usan generar_factura.php (al timbrar) y ver_factura_pdf.php (al consultarla).
 *
 * Los PDF se guardan en Admin-Facturacion/pdf/ con el nombre Factura_SERIE-FOLIO.pdf
 */
require_once __DIR__ . '/../libs/PdfBogos.php';

const FACTURA_DIR_PDF = __DIR__ . '/pdf';
const FACTURA_LOGO    = __DIR__ . '/../CSS-IMAGENES/imagenes/logo.jpg';
const FACTURA_EMISOR_NOMBRE = 'DISTRIBUIDORA DE BOTANAS BOGOS';

// El sistema genera el folio fiscal (UUID) y los sellos de forma simulada, sin pasar por un PAC
// ni por el SAT, así que el PDF lo dice en el pie de página. Si algún día se conecta un
// timbrado real, deja esta constante vacía ('') para quitar la leyenda.
const FACTURA_AVISO_SIMULADO = 'Timbrado simulado por el sistema: documento sin validez fiscal ante el SAT.';

/** Venta + cliente + factura + emisor + conceptos. Devuelve false si la venta no existe. */
function facturaObtenerDatos(PDO $pdo, $id_venta)
{
    $emisor = $pdo->query("SELECT rfc, regimen_fiscal, codigo_postal FROM empresa_emisor LIMIT 1")->fetch(PDO::FETCH_ASSOC);

    $stmt = $pdo->prepare("
        SELECT
            v.id_venta, v.total, v.forma_pago,
            c.razon_social AS cliente_razon, c.nombre_negocio AS cliente_negocio,
            c.rfc AS cliente_rfc, c.uso_cfdi AS cliente_uso, c.codigo_postal_fiscal AS cliente_cp,
            f.id_factura, f.folio AS factura_folio, f.serie AS factura_serie, f.uuid AS factura_uuid,
            f.sello_emisor AS factura_sello_emisor, f.sello_sat AS factura_sello_sat,
            f.fecha_emision AS factura_fecha
        FROM ventas v
        INNER JOIN clientes c ON v.id_cliente = c.id_cliente
        LEFT JOIN facturas f ON v.id_venta = f.id_venta
        WHERE v.id_venta = ?
    ");
    $stmt->execute([$id_venta]);
    $venta = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$venta) return false;

    // Mismos valores por defecto que preparar_factura.php
    $venta['emisor_rfc']     = $emisor ? $emisor['rfc'] : 'BOGO261027XYZ';
    $venta['emisor_regimen'] = $emisor ? $emisor['regimen_fiscal'] . ' - Régimen General' : '612 - Personas Físicas';
    $venta['emisor_cp']      = $emisor ? $emisor['codigo_postal'] : '66600';

    $stmtC = $pdo->prepare("
        SELECT pr.nombre, dv.cantidad, dv.precio_unitario, dv.subtotal
        FROM detalle_venta dv
        INNER JOIN productos pr ON dv.id_producto = pr.id_producto
        WHERE dv.id_venta = ?
    ");
    $stmtC->execute([$id_venta]);
    $venta['conceptos'] = $stmtC->fetchAll(PDO::FETCH_ASSOC);

    return $venta;
}

function facturaNombreArchivo(array $d)
{
    $folio = preg_replace('/[^A-Za-z0-9_\-]/', '', $d['factura_serie'] . '-' . $d['factura_folio']);
    return 'Factura_' . ($folio !== '' && $folio !== '-' ? $folio : 'venta' . (int)$d['id_venta']) . '.pdf';
}

function facturaRutaPdf(array $d)
{
    return FACTURA_DIR_PDF . '/' . facturaNombreArchivo($d);
}

function facturaDinero($n)
{
    return '$' . number_format((float)$n, 2, '.', ',');
}

/** 1234.5 -> "MIL DOSCIENTOS TREINTA Y CUATRO PESOS 50/100 M.N." */
function facturaImporteConLetra($monto)
{
    $monto = round((float)$monto, 2);
    $entero = (int)floor($monto);
    $centavos = (int)round(($monto - $entero) * 100);
    if ($centavos >= 100) { $entero++; $centavos = 0; }

    $unidades = ['', 'UN', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE', 'DIEZ', 'ONCE', 'DOCE', 'TRECE', 'CATORCE', 'QUINCE',
                 'DIECISÉIS', 'DIECISIETE', 'DIECIOCHO', 'DIECINUEVE', 'VEINTE', 'VEINTIÚN', 'VEINTIDÓS', 'VEINTITRÉS', 'VEINTICUATRO', 'VEINTICINCO',
                 'VEINTISÉIS', 'VEINTISIETE', 'VEINTIOCHO', 'VEINTINUEVE'];
    $decenas  = ['', '', '', 'TREINTA', 'CUARENTA', 'CINCUENTA', 'SESENTA', 'SETENTA', 'OCHENTA', 'NOVENTA'];
    $centenas = ['', 'CIENTO', 'DOSCIENTOS', 'TRESCIENTOS', 'CUATROCIENTOS', 'QUINIENTOS', 'SEISCIENTOS', 'SETECIENTOS', 'OCHOCIENTOS', 'NOVECIENTOS'];

    $hasta999 = function ($n) use ($unidades, $decenas, $centenas) {
        if ($n == 100) return 'CIEN';
        $txt = $centenas[intdiv($n, 100)];
        $r = $n % 100;
        if ($r > 0) {
            if ($r < 30) $parte = $unidades[$r];
            else $parte = $decenas[intdiv($r, 10)] . ($r % 10 ? ' Y ' . $unidades[$r % 10] : '');
            $txt = trim($txt . ' ' . $parte);
        }
        return $txt;
    };

    if ($entero == 0) {
        $letras = 'CERO';
    } else {
        $millones = intdiv($entero, 1000000);
        $miles    = intdiv($entero % 1000000, 1000);
        $resto    = $entero % 1000;
        $partes = [];
        if ($millones > 0) $partes[] = $millones == 1 ? 'UN MILLÓN' : $hasta999($millones) . ' MILLONES';
        if ($miles > 0)    $partes[] = $miles == 1 ? 'MIL' : $hasta999($miles) . ' MIL';
        if ($resto > 0)    $partes[] = $hasta999($resto);
        $letras = implode(' ', $partes);
        if ($millones > 0 && $miles == 0 && $resto == 0) $letras .= ' DE';
    }

    return $letras . ($entero == 1 ? ' PESO ' : ' PESOS ') . sprintf('%02d', $centavos) . '/100 M.N.';
}

/**
 * Construye el PDF de la factura y devuelve su contenido binario.
 * $d es el arreglo que devuelve facturaObtenerDatos() y debe tener factura emitida.
 */
function facturaGenerarPdf(array $d)
{
    $azul = [11, 26, 69];
    $rojo = [209, 31, 38];
    $gris = [110, 117, 125];
    $negro = [33, 37, 41];
    $M = 36;
    $W = PdfBogos::ANCHO - 2 * $M;
    $limite = PdfBogos::ALTO - 56;

    $folio = $d['factura_serie'] . '-' . $d['factura_folio'];
    $ts = strtotime((string)$d['factura_fecha']);
    $fechaEmision = $ts ? date('d/m/Y H:i:s', $ts) : (string)$d['factura_fecha'];

    $total = (float)$d['total'];
    $subtotal = $total / 1.16;
    $iva = $total - $subtotal;

    $pdf = new PdfBogos();
    $pdf->titulo = 'Factura ' . $folio;
    $pdf->pieIzquierdo = trim('Factura ' . $folio . ' · ' . FACTURA_AVISO_SIMULADO, ' ·');

    $etiqueta = function ($x, $y, $txt) use ($pdf, $gris) {
        $pdf->fuente('B', 7);
        $pdf->colorTexto(...$gris);
        $pdf->texto($x, $y, function_exists('mb_strtoupper') ? mb_strtoupper($txt, 'UTF-8') : strtoupper($txt));
    };
    $saltoPagina = function () use ($pdf, $M, $folio, $azul) {
        $pdf->nuevaPagina();
        $pdf->fuente('B', 9);
        $pdf->colorTexto(...$azul);
        $pdf->texto($M, 44, 'Factura ' . $folio . ' (continuación)');
        return 58;
    };

    // ---------- Emisor ----------
    $xEmisor = $M;
    if ($pdf->imagenJpeg(FACTURA_LOGO, $M, 36, 72) > 0) $xEmisor = $M + 86;
    $anchoEmisor = 372 - $xEmisor;

    $pdf->fuente('B', 13);
    $pdf->colorTexto(...$azul);
    $y = $pdf->parrafo($xEmisor, 52, FACTURA_EMISOR_NOMBRE, $anchoEmisor, 15);
    $pdf->colorTexto(...$negro);
    foreach ([['RFC: ', $d['emisor_rfc']], ['Régimen fiscal: ', $d['emisor_regimen']], ['C.P. de expedición: ', $d['emisor_cp']]] as $par) {
        $pdf->fuente('B', 9);
        $pdf->texto($xEmisor, $y, $par[0]);
        $ancho = $pdf->anchoTexto($par[0]);
        $pdf->fuente('', 9);
        $pdf->texto($xEmisor + $ancho, $y, $pdf->recortar($par[1], $anchoEmisor - $ancho));
        $y += 12.5;
    }

    // ---------- Recuadro de la factura (derecha) ----------
    $xc = 386;
    $wc = $M + $W - $xc;
    $pdf->fuente('B', 8);
    $pdf->colorTexto(...$gris);
    $pdf->texto($M + $W, 44, 'FACTURA', 'R');
    $pdf->fuente('B', 17);
    $pdf->colorTexto(...$rojo);
    $pdf->texto($M + $W, 62, $folio, 'R');

    $pdf->colorRelleno(246, 247, 249);
    $pdf->colorLinea(206, 212, 218);
    $pdf->grosorLinea(0.7);
    $pdf->rect($xc, 70, $wc, 86, 'FD');
    $etiqueta($xc + 8, 83, 'Folio fiscal (UUID)');
    $pdf->fuente('B', 7.6);
    $pdf->colorTexto(...$rojo);
    $pdf->texto($xc + 8, 94, $pdf->recortar($d['factura_uuid'], $wc - 14));
    $etiqueta($xc + 8, 110, 'Fecha y hora de emisión');
    $pdf->fuente('', 9);
    $pdf->colorTexto(...$negro);
    $pdf->texto($xc + 8, 121, $fechaEmision);
    $etiqueta($xc + 8, 137, 'Tipo de comprobante');
    $pdf->fuente('', 9);
    $pdf->colorTexto(...$negro);
    $pdf->texto($xc + 8, 148, 'I - Ingreso');

    $pdf->colorRelleno(...$rojo);
    $pdf->rect($M, 166, $W, 2.5);

    // ---------- Receptor ----------
    $y = 180;
    $pdf->colorLinea(206, 212, 218);
    $pdf->rect($M, $y, $W, 82, 'D');
    $pdf->fuente('B', 9.5);
    $pdf->colorTexto(...$azul);
    $pdf->texto($M + 10, $y + 16, 'DATOS DEL RECEPTOR');
    $pdf->linea($M + 10, $y + 22, $M + $W - 10, $y + 22);

    $mitad = $W / 2;
    $campos = [
        [$M + 10,          $y + 36, 'Razón social / Nombre', $d['cliente_razon'] ?: $d['cliente_negocio'], 'B'],
        [$M + 10,          $y + 62, 'RFC', $d['cliente_rfc'] ?: 'XAXX010101000', ''],
        [$M + $mitad + 10, $y + 36, 'Uso de CFDI', ($d['cliente_uso'] ?: 'G03') . ' - Gastos en general', ''],
        [$M + $mitad + 10, $y + 62, 'Domicilio fiscal (C.P.)', $d['cliente_cp'] ?: '66600', ''],
    ];
    foreach ($campos as $c) {
        $etiqueta($c[0], $c[1], $c[2]);
        $pdf->fuente($c[4], 9.5);
        $pdf->colorTexto(...$negro);
        $pdf->texto($c[0], $c[1] + 11.5, $pdf->recortar($c[3], $mitad - 20));
    }

    // ---------- Datos de pago ----------
    $y = 282;
    $formaPago = $d['forma_pago'] ?: 'Efectivo';
    $clave = $formaPago === 'Tarjeta' ? '04' : ($formaPago === 'Transferencia' ? '03' : '01');
    $tercio = $W / 3;
    $pago = [['Forma de pago', $clave . ' - ' . $formaPago], ['Método de pago', 'PUE - Pago en una sola exhibición'], ['Moneda', 'MXN - Peso Mexicano']];
    foreach ($pago as $i => $p) {
        $etiqueta($M + $i * $tercio, $y, $p[0]);
        $pdf->fuente('', 9.5);
        $pdf->colorTexto(...$negro);
        $pdf->texto($M + $i * $tercio, $y + 12, $p[1]);
    }

    // ---------- Conceptos ----------
    $y = 312;
    $cols = [
        ['Cant.',          $M,        50],
        ['Clave prod.',    $M + 50,   75],
        ['Descripción',    $M + 125, 245],
        ['Valor unitario', $M + 370,  85],
        ['Importe',        $M + 455,  85],
    ];
    $encabezadoTabla = function ($y) use ($pdf, $cols, $M, $W, $azul) {
        $pdf->colorRelleno(...$azul);
        $pdf->rect($M, $y, $W, 18);
        $pdf->fuente('B', 8.5);
        $pdf->colorTexto(255, 255, 255);
        foreach ($cols as $i => $c) {
            if ($i >= 3) $pdf->texto($c[1] + $c[2] - 8, $y + 12, $c[0], 'R');
            else $pdf->texto($c[1] + 8, $y + 12, $c[0]);
        }
        return $y + 18;
    };
    $y = $encabezadoTabla($y);

    $pdf->colorLinea(222, 226, 230);
    $pdf->grosorLinea(0.5);
    foreach ($d['conceptos'] as $i => $c) {
        $pdf->fuente('', 9);
        $lineas = $pdf->partir($c['nombre'], $cols[2][2] - 14);
        $alto = max(18, count($lineas) * 11 + 7);
        if ($y + $alto > $limite) $y = $encabezadoTabla($saltoPagina());

        if ($i % 2 === 1) {
            $pdf->colorRelleno(246, 247, 249);
            $pdf->rect($M, $y, $W, $alto);
        }
        $pdf->colorTexto(...$negro);
        $pdf->fuente('', 9);
        $cant = (float)$c['cantidad'];
        $pdf->texto($cols[0][1] + 8, $y + 12, rtrim(rtrim(number_format($cant, 2, '.', ''), '0'), '.'));
        $pdf->texto($cols[1][1] + 8, $y + 12, '80141628');
        foreach ($lineas as $k => $l) $pdf->texto($cols[2][1] + 8, $y + 12 + $k * 11, $l);
        $pdf->texto($cols[3][1] + $cols[3][2] - 8, $y + 12, facturaDinero($c['precio_unitario'] / 1.16), 'R');
        $pdf->fuente('B', 9);
        $pdf->texto($cols[4][1] + $cols[4][2] - 8, $y + 12, facturaDinero($c['subtotal'] / 1.16), 'R');
        $y += $alto;
        $pdf->linea($M, $y, $M + $W, $y);
    }
    if (count($d['conceptos']) === 0) {
        $pdf->fuente('I', 9);
        $pdf->colorTexto(...$gris);
        $pdf->texto($M + $W / 2, $y + 16, 'Esta venta no tiene conceptos registrados.', 'C');
        $y += 28;
    }

    // ---------- Totales e importe con letra ----------
    if ($y + 76 > $limite) $y = $saltoPagina();
    $y += 18;
    $xEtq = $M + $W - 95;
    $xVal = $M + $W - 8;

    $etiqueta($M, $y, 'Importe con letra');
    $pdf->fuente('', 8.5);
    $pdf->colorTexto(...$negro);
    $pdf->parrafo($M, $y + 12, facturaImporteConLetra($total), 300, 11);

    $pdf->fuente('B', 9.5);
    $pdf->colorTexto(...$negro);
    $pdf->texto($xEtq, $y, 'SUBTOTAL:', 'R');
    $pdf->fuente('', 9.5);
    $pdf->texto($xVal, $y, facturaDinero($subtotal), 'R');
    $pdf->fuente('B', 9.5);
    $pdf->texto($xEtq, $y + 15, 'IVA (16%):', 'R');
    $pdf->fuente('', 9.5);
    $pdf->texto($xVal, $y + 15, facturaDinero($iva), 'R');
    $pdf->colorLinea(...$negro);
    $pdf->grosorLinea(0.8);
    $pdf->linea($M + $W - 190, $y + 22, $M + $W, $y + 22);
    $pdf->fuente('B', 13);
    $pdf->colorTexto(...$azul);
    $pdf->texto($xEtq, $y + 40, 'TOTAL:', 'R');
    $pdf->texto($xVal, $y + 40, facturaDinero($total), 'R');
    $y += 62;

    // ---------- Sellos digitales ----------
    $cadena = '||1.1|' . $d['factura_uuid'] . '|' . ($ts ? date('Y-m-d\TH:i:s', $ts) : '') . '|' . $d['factura_sello_emisor'] . '|00001000000500000000||';
    $sellos = [
        ['Sello digital del CFDI', (string)$d['factura_sello_emisor']],
        ['Sello del SAT', (string)$d['factura_sello_sat']],
        ['Cadena original del complemento de certificación del SAT', $cadena],
    ];
    $pdf->fuente('M', 6.5);
    $altoSellos = 14;
    foreach ($sellos as $k => $s) {
        $sellos[$k][2] = $pdf->partir($s[1], $W);
        $altoSellos += 12 + count($sellos[$k][2]) * 8.5 + 6;
    }
    if ($y + $altoSellos + 14 > $limite) $y = $saltoPagina();

    $pdf->colorLinea(206, 212, 218);
    $pdf->grosorLinea(0.7);
    $pdf->linea($M, $y, $M + $W, $y);
    $y += 14;
    foreach ($sellos as $s) {
        $etiqueta($M, $y, $s[0]);
        $y += 10;
        $pdf->fuente('M', 6.5);
        $pdf->colorTexto(85, 85, 85);
        foreach ($s[2] as $l) { $pdf->texto($M, $y, $l); $y += 8.5; }
        $y += 8;
    }

    $pdf->fuente('', 7.5);
    $pdf->colorTexto(...$gris);
    $pdf->texto($M + $W / 2, $y + 6, 'Este documento es una representación impresa de un CFDI.', 'C');

    return $pdf->salida();
}

/**
 * Genera el PDF de la factura y lo guarda en Admin-Facturacion/pdf/.
 * Devuelve ['contenido' => bytes, 'guardado' => bool, 'archivo' => nombre].
 * Si la carpeta no se puede escribir, el PDF se devuelve igual (solo no queda archivado).
 */
function facturaGenerarYGuardarPdf(array $d)
{
    $contenido = facturaGenerarPdf($d);
    $guardado = false;

    if (!is_dir(FACTURA_DIR_PDF)) @mkdir(FACTURA_DIR_PDF, 0775, true);
    if (is_dir(FACTURA_DIR_PDF)) {
        // Impide abrir los PDF escribiendo la URL directa; solo se sirven desde ver_factura_pdf.php (con sesión)
        $ht = FACTURA_DIR_PDF . '/.htaccess';
        if (!is_file($ht)) @file_put_contents($ht, "Require all denied\n");
        $guardado = @file_put_contents(facturaRutaPdf($d), $contenido, LOCK_EX) !== false;
    }

    return ['contenido' => $contenido, 'guardado' => $guardado, 'archivo' => facturaNombreArchivo($d)];
}
