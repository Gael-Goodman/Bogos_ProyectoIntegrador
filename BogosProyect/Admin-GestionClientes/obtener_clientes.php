<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    // Consulta actualizada pidiendo la información fiscal
    $stmt = $pdo->query("SELECT id_cliente, nombre_negocio, nombre_contacto, telefono, direccion, referencias, latitud, longitud, rfc, razon_social, codigo_postal_fiscal, regimen_fiscal, uso_cfdi, correo_facturacion FROM clientes WHERE activo = 1 ORDER BY nombre_negocio ASC");
    $clientes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $usuario = [
        'nombre' => $_SESSION['nombre_completo'] ?? 'Administrador'
    ];

    echo json_encode([
        'exito' => true, 
        'usuario' => $usuario,
        'clientes' => $clientes
    ]);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>