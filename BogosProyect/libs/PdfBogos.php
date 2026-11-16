<?php
/**
 * PdfBogos - Generador de PDF ligero, sin dependencias (no requiere Composer,
 * FPDF ni ninguna extensión especial de PHP).
 *
 * - Tamaño carta (612 x 792 puntos), origen arriba-izquierda.
 * - Todos los textos se reciben en UTF-8 (acentos y ñ funcionan).
 * - Fuentes estándar: '' normal, 'B' negrita, 'I' cursiva, 'M' monoespaciada.
 *
 * Lo usan los módulos Admin-Cortes y Admin-Facturacion.
 */
class PdfBogos
{
    const ANCHO = 612;
    const ALTO  = 792;

    private $paginas = [];
    private $actual = -1;
    private $estilo = '';
    private $tam = 10;
    private $imagenes = [];

    /** Texto que se imprime abajo a la izquierda de todas las páginas. */
    public $pieIzquierdo = '';
    /** Título interno del documento (propiedades del PDF). */
    public $titulo = 'Documento';

    private static $fuentes = ['' => 'F1', 'B' => 'F2', 'M' => 'F3', 'I' => 'F4'];

    // Anchos de los caracteres 32 a 126 (Helvetica y Helvetica-Bold)
    private static $anchosNormal = [278,278,355,556,556,889,667,191,333,333,389,584,278,333,278,278,556,556,556,556,556,556,556,556,556,556,278,278,584,584,584,556,1015,667,667,722,722,667,611,778,722,278,500,667,556,833,722,778,667,778,722,667,611,722,667,944,667,667,611,278,278,278,469,556,333,556,556,500,556,556,278,556,556,222,222,500,222,833,556,556,556,556,333,500,278,556,500,722,500,500,500,334,260,334,584];
    private static $anchosNegrita = [278,333,474,556,556,889,722,238,333,333,389,584,278,333,278,278,556,556,556,556,556,556,556,556,556,556,333,333,584,584,584,611,975,722,722,722,722,667,611,778,722,278,556,722,611,833,722,778,667,778,722,667,611,722,667,944,667,667,611,333,278,333,584,556,333,556,611,556,611,556,333,611,611,278,278,556,278,889,611,611,611,611,389,556,333,611,556,778,556,556,500,389,280,389,584];

    public function __construct()
    {
        $this->nuevaPagina();
    }

    // ------------------------------------------------------------------
    // Páginas y estado gráfico
    // ------------------------------------------------------------------

    public function nuevaPagina()
    {
        $this->paginas[] = '';
        $this->actual = count($this->paginas) - 1;
    }

    public function numPaginas()
    {
        return count($this->paginas);
    }

    public function fuente($estilo = '', $tam = 10)
    {
        $this->estilo = isset(self::$fuentes[$estilo]) ? $estilo : '';
        $this->tam = $tam;
    }

    public function colorTexto($r, $g, $b)
    {
        $this->colorRelleno($r, $g, $b);
    }

    public function colorRelleno($r, $g, $b)
    {
        $this->cmd(sprintf('%.3F %.3F %.3F rg', $r / 255, $g / 255, $b / 255));
    }

    public function colorLinea($r, $g, $b)
    {
        $this->cmd(sprintf('%.3F %.3F %.3F RG', $r / 255, $g / 255, $b / 255));
    }

    public function grosorLinea($g)
    {
        $this->cmd(sprintf('%.2F w', $g));
    }

    // ------------------------------------------------------------------
    // Dibujo
    // ------------------------------------------------------------------

    /** $modo: 'F' relleno, 'D' contorno, 'FD' ambos. */
    public function rect($x, $y, $w, $h, $modo = 'F')
    {
        $op = $modo === 'F' ? 'f' : ($modo === 'FD' ? 'B' : 'S');
        $this->cmd(sprintf('%.2F %.2F %.2F %.2F re %s', $x, self::ALTO - $y - $h, $w, $h, $op));
    }

    public function linea($x1, $y1, $x2, $y2)
    {
        $this->cmd(sprintf('%.2F %.2F m %.2F %.2F l S', $x1, self::ALTO - $y1, $x2, self::ALTO - $y2));
    }

    /**
     * Escribe una línea de texto. $y es la línea base.
     * $alin: 'L' ($x es el borde izquierdo), 'R' ($x es el borde derecho), 'C' ($x es el centro).
     */
    public function texto($x, $y, $txt, $alin = 'L')
    {
        $txt = (string)$txt;
        if ($txt === '') return;
        if ($alin === 'R') $x -= $this->anchoTexto($txt);
        elseif ($alin === 'C') $x -= $this->anchoTexto($txt) / 2;

        $s = str_replace(['\\', '(', ')', "\r", "\n"], ['\\\\', '\\(', '\\)', '', ' '], $this->win($txt));
        $this->cmd(sprintf('BT /%s %.2F Tf %.2F %.2F Td (%s) Tj ET',
            self::$fuentes[$this->estilo], $this->tam, $x, self::ALTO - $y, $s));
    }

    /** Ancho en puntos de un texto con la fuente actual. */
    public function anchoTexto($txt)
    {
        $s = $this->win((string)$txt);
        $n = strlen($s);
        if ($this->estilo === 'M') return $n * 0.6 * $this->tam;

        $tabla = $this->estilo === 'B' ? self::$anchosNegrita : self::$anchosNormal;
        $w = 0;
        for ($i = 0; $i < $n; $i++) {
            $c = ord($s[$i]);
            if ($c >= 32 && $c <= 126) { $w += $tabla[$c - 32]; continue; }
            $w += $this->anchoExtendido($c, $tabla);
        }
        return $w * $this->tam / 1000;
    }

    /** Parte un texto en líneas que quepan en $anchoMax (corta palabras muy largas, p. ej. sellos). */
    public function partir($txt, $anchoMax)
    {
        $lineas = [];
        foreach (preg_split('/\r\n|\r|\n/', (string)$txt) as $parrafo) {
            $linea = '';
            foreach (preg_split('/\s+/u', trim($parrafo)) as $palabra) {
                if ($palabra === '') continue;
                $prueba = $linea === '' ? $palabra : $linea . ' ' . $palabra;
                if ($this->anchoTexto($prueba) <= $anchoMax) { $linea = $prueba; continue; }
                if ($linea !== '') { $lineas[] = $linea; $linea = ''; }
                // La palabra sola no cabe: se corta por caracteres
                if ($this->anchoTexto($palabra) > $anchoMax) {
                    $trozo = '';
                    foreach (preg_split('//u', $palabra, -1, PREG_SPLIT_NO_EMPTY) as $ch) {
                        if ($trozo !== '' && $this->anchoTexto($trozo . $ch) > $anchoMax) {
                            $lineas[] = $trozo;
                            $trozo = '';
                        }
                        $trozo .= $ch;
                    }
                    $linea = $trozo;
                } else {
                    $linea = $palabra;
                }
            }
            $lineas[] = $linea;
        }
        return $lineas;
    }

    /** Escribe un párrafo con salto de línea automático. Devuelve la Y de la siguiente línea. */
    public function parrafo($x, $y, $txt, $anchoMax, $interlineado = null)
    {
        if ($interlineado === null) $interlineado = $this->tam * 1.25;
        foreach ($this->partir($txt, $anchoMax) as $l) {
            $this->texto($x, $y, $l);
            $y += $interlineado;
        }
        return $y;
    }

    /** Recorta un texto con "..." para que quepa en $anchoMax. */
    public function recortar($txt, $anchoMax)
    {
        $txt = (string)$txt;
        if ($this->anchoTexto($txt) <= $anchoMax) return $txt;
        $chars = preg_split('//u', $txt, -1, PREG_SPLIT_NO_EMPTY);
        while (count($chars) > 1 && $this->anchoTexto(implode('', $chars) . '...') > $anchoMax) {
            array_pop($chars);
        }
        return rtrim(implode('', $chars)) . '...';
    }

    /**
     * Inserta una imagen JPG con el ancho indicado (alto proporcional).
     * Devuelve el alto dibujado, o 0 si no se pudo cargar (el PDF se genera igual).
     */
    public function imagenJpeg($ruta, $x, $y, $w)
    {
        if (!isset($this->imagenes[$ruta])) {
            $info = (is_file($ruta) && is_readable($ruta)) ? @getimagesize($ruta) : false;
            if (!$info || $info[2] !== IMAGETYPE_JPEG) return 0;
            $canales = isset($info['channels']) ? $info['channels'] : 3;
            $this->imagenes[$ruta] = [
                'nombre' => 'Im' . (count($this->imagenes) + 1),
                'datos'  => file_get_contents($ruta),
                'w' => $info[0], 'h' => $info[1],
                'cs' => $canales == 1 ? 'DeviceGray' : ($canales == 4 ? 'DeviceCMYK' : 'DeviceRGB'),
            ];
        }
        $img = $this->imagenes[$ruta];
        $h = $w * $img['h'] / $img['w'];
        $this->cmd(sprintf('q %.2F 0 0 %.2F %.2F %.2F cm /%s Do Q', $w, $h, $x, self::ALTO - $y - $h, $img['nombre']));
        return $h;
    }

    // ------------------------------------------------------------------
    // Salida
    // ------------------------------------------------------------------

    /** Devuelve el contenido binario del PDF. */
    public function salida()
    {
        // Pie de página con numeración
        $total = count($this->paginas);
        for ($i = 0; $i < $total; $i++) {
            $this->actual = $i;
            $this->fuente('', 7.5);
            $this->colorTexto(120, 120, 120);
            if ($this->pieIzquierdo !== '') $this->texto(36, self::ALTO - 24, $this->pieIzquierdo);
            $this->texto(self::ANCHO - 36, self::ALTO - 24, 'Página ' . ($i + 1) . ' de ' . $total, 'R');
        }

        $objs = [];   // número de objeto => contenido
        $objs[1] = '<< /Type /Catalog /Pages 2 0 R >>';
        $objs[2] = ''; // se llena al final
        $objs[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>';
        $objs[4] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>';
        $objs[5] = '<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>';
        $objs[6] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>';
        $n = 6;

        $xobj = '';
        foreach ($this->imagenes as $img) {
            $n++;
            $extra = $img['cs'] === 'DeviceCMYK' ? ' /Decode [1 0 1 0 1 0 1 0]' : '';
            $objs[$n] = sprintf("<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /%s /BitsPerComponent 8 /Filter /DCTDecode%s /Length %d >>\nstream\n",
                    $img['w'], $img['h'], $img['cs'], $extra, strlen($img['datos'])) . $img['datos'] . "\nendstream";
            $xobj .= sprintf('/%s %d 0 R ', $img['nombre'], $n);
        }

        $recursos = '<< /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R /F4 6 0 R >>'
                  . ($xobj !== '' ? ' /XObject << ' . $xobj . '>>' : '') . ' >>';

        $kids = '';
        foreach ($this->paginas as $contenido) {
            $filtro = '';
            if (function_exists('gzcompress')) {
                $contenido = gzcompress($contenido);
                $filtro = ' /Filter /FlateDecode';
            }
            $nPag = ++$n;
            $nCont = ++$n;
            $objs[$nPag] = sprintf('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] /Resources %s /Contents %d 0 R >>',
                self::ANCHO, self::ALTO, $recursos, $nCont);
            $objs[$nCont] = sprintf("<< /Length %d%s >>\nstream\n", strlen($contenido), $filtro) . $contenido . "\nendstream";
            $kids .= $nPag . ' 0 R ';
        }
        $objs[2] = sprintf('<< /Type /Pages /Kids [%s] /Count %d >>', $kids, $total);

        $n++;
        $objs[$n] = sprintf('<< /Title (%s) /Producer (Botanas Bogos) /CreationDate (D:%s) >>',
            str_replace(['\\', '(', ')'], ['\\\\', '\\(', '\\)'], $this->win($this->titulo)), date('YmdHis'));
        $nInfo = $n;

        ksort($objs);
        $pdf = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n";
        $offsets = [];
        foreach ($objs as $num => $cuerpo) {
            $offsets[$num] = strlen($pdf);
            $pdf .= $num . " 0 obj\n" . $cuerpo . "\nendobj\n";
        }
        $inicioXref = strlen($pdf);
        $pdf .= "xref\n0 " . ($n + 1) . "\n0000000000 65535 f \n";
        for ($i = 1; $i <= $n; $i++) {
            $pdf .= sprintf("%010d 00000 n \n", $offsets[$i]);
        }
        $pdf .= sprintf("trailer\n<< /Size %d /Root 1 0 R /Info %d 0 R >>\nstartxref\n%d\n%%%%EOF\n", $n + 1, $nInfo, $inicioXref);
        return $pdf;
    }

    // ------------------------------------------------------------------
    // Internos
    // ------------------------------------------------------------------

    private function cmd($c)
    {
        $this->paginas[$this->actual] .= $c . "\n";
    }

    /** UTF-8 -> Windows-1252 (la codificación de las fuentes estándar del PDF). */
    private function win($s)
    {
        if ($s === '' || !preg_match('/[\x80-\xFF]/', $s)) return $s;
        if (function_exists('iconv')) {
            $r = @iconv('UTF-8', 'Windows-1252//TRANSLIT//IGNORE', $s);
            if ($r !== false) return $r;
        }
        if (function_exists('mb_convert_encoding')) {
            return mb_convert_encoding($s, 'Windows-1252', 'UTF-8');
        }
        return preg_replace('/[\x80-\xFF]+/', '?', $s);
    }

    /** Ancho aproximado de letras acentuadas y símbolos (código Windows-1252). */
    private function anchoExtendido($c, $tabla)
    {
        $base = null;
        if ($c >= 0xC0 && $c <= 0xC5) $base = 'A';
        elseif ($c == 0xC7) $base = 'C';
        elseif ($c >= 0xC8 && $c <= 0xCB) $base = 'E';
        elseif ($c >= 0xCC && $c <= 0xCF) $base = 'I';
        elseif ($c == 0xD1) $base = 'N';
        elseif ($c >= 0xD2 && $c <= 0xD6) $base = 'O';
        elseif ($c >= 0xD9 && $c <= 0xDC) $base = 'U';
        elseif ($c >= 0xE0 && $c <= 0xE5) $base = 'a';
        elseif ($c == 0xE7) $base = 'c';
        elseif ($c >= 0xE8 && $c <= 0xEB) $base = 'e';
        elseif ($c >= 0xEC && $c <= 0xEF) return 278;
        elseif ($c == 0xF1) $base = 'n';
        elseif ($c >= 0xF2 && $c <= 0xF6) $base = 'o';
        elseif ($c >= 0xF9 && $c <= 0xFC) $base = 'u';
        elseif ($c == 0xA1) return 333;   // ¡
        elseif ($c == 0xBF) return 611;   // ¿
        elseif ($c == 0xB0) return 400;   // °
        elseif ($c == 0x95) return 350;   // viñeta
        elseif ($c == 0x97) return 1000;  // raya
        return $base !== null ? $tabla[ord($base) - 32] : 556;
    }
}
