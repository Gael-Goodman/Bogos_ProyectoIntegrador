<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);

$id = $datos['id_cliente'] ?? null;
$negocio = $datos['nombre_negocio'] ?? '';
$contacto = $datos['nombre_contacto'] ?? '';
$telefono = $datos['telefono'] ?? '';
$direccion = $datos['direccion'] ?? '';
$referencias = $datos['referencias'] ?? '';

// Nuevos campos fiscales
$rfc = $datos['rfc'] ?? null;
$razon_social = $datos['razon_social'] ?? null;
$cp = $datos['codigo_postal_fiscal'] ?? null;
$regimen = $datos['regimen_fiscal'] ?? null;
$uso = $datos['uso_cfdi'] ?? null;
$correo = $datos['correo_facturacion'] ?? null;

if (!$negocio || !$direccion) {
    echo json_encode(['exito' => false, 'mensaje' => 'Negocio y dirección son obligatorios.']);
    exit;
}

try {
    if ($id) {
        $stmt = $pdo->prepare("UPDATE clientes SET nombre_negocio=?, nombre_contacto=?, telefono=?, direccion=?, referencias=?, rfc=?, razon_social=?, codigo_postal_fiscal=?, regimen_fiscal=?, uso_cfdi=?, correo_facturacion=? WHERE id_cliente=?");
        $stmt->execute([$negocio, $contacto, $telefono, $direccion, $referencias, $rfc, $razon_social, $cp, $regimen, $uso, $correo, $id]);
    } else {
        $stmt = $pdo->prepare("INSERT INTO clientes (nombre_negocio, nombre_contacto, telefono, direccion, referencias, rfc, razon_social, codigo_postal_fiscal, regimen_fiscal, uso_cfdi, correo_facturacion, activo) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)");
        $stmt->execute([$negocio, $contacto, $telefono, $direccion, $referencias, $rfc, $razon_social, $cp, $regimen, $uso, $correo]);
    }
    echo json_encode(['exito' => true, 'mensaje' => 'Cliente guardado correctamente.']);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error: ' . $e->getMessage()]);
}
?>