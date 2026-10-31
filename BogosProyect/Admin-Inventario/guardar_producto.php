<?php
session_start();
header('Content-Type: application/json');

// Validar seguridad
if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);

$id_producto = $datos['id_producto'] ?? null;
$codigo = $datos['codigo'] ?? '';
$categoria = $datos['categoria'] ?? '';
$nombre = $datos['nombre'] ?? '';
// Recibimos 'precio_venta' del JS pero lo guardaremos en 'precio_unitario'
$precio_unitario = $datos['precio_venta'] ?? 0; 
$stock_actual = $datos['stock_actual'] ?? 0;
$stock_minimo = $datos['stock_minimo'] ?? 0;

if (empty($codigo) || empty($nombre) || $precio_unitario === '') {
    echo json_encode(['exito' => false, 'mensaje' => 'Faltan datos obligatorios.']);
    exit;
}

try {
    // 1. Verificar que el código (SKU) no esté duplicado
    $stmtCheck = $pdo->prepare("SELECT id_producto FROM productos WHERE codigo = ? AND id_producto != ?");
    $stmtCheck->execute([$codigo, $id_producto ? $id_producto : 0]);
    
    if ($stmtCheck->rowCount() > 0) {
        echo json_encode(['exito' => false, 'mensaje' => 'El código (SKU) ya está registrado en otro producto.']);
        exit;
    }

    // 2. Guardar o Actualizar
    if ($id_producto) {
        $stmt = $pdo->prepare("
            UPDATE productos 
            SET codigo = ?, categoria = ?, nombre = ?, precio_unitario = ?, stock_actual = ?, stock_minimo = ?
            WHERE id_producto = ?
        ");
        $stmt->execute([$codigo, $categoria, $nombre, $precio_unitario, $stock_actual, $stock_minimo, $id_producto]);
        $mensaje = 'Producto actualizado correctamente.';
    } else {
        $stmt = $pdo->prepare("
            INSERT INTO productos (codigo, categoria, nombre, precio_unitario, stock_actual, stock_minimo, activo)
            VALUES (?, ?, ?, ?, ?, ?, 1)
        ");
        $stmt->execute([$codigo, $categoria, $nombre, $precio_unitario, $stock_actual, $stock_minimo]);
        $mensaje = 'Producto registrado correctamente.';
    }

    echo json_encode(['exito' => true, 'mensaje' => $mensaje]);

} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al guardar: ' . $e->getMessage()]);
}
?>