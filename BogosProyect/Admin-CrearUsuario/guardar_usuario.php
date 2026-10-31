<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);

$id_usuario = $datos['id_usuario'] ?? null;
$nombre_completo = $datos['nombre_completo'] ?? '';
$nombre_usuario = $datos['nombre_usuario'] ?? '';
$rol = $datos['rol'] ?? '';
$password = $datos['password'] ?? '';

if (!$nombre_completo || !$nombre_usuario || !$rol) {
    echo json_encode(['exito' => false, 'mensaje' => 'Faltan datos obligatorios.']);
    exit;
}

// FORMATO CORPORATIVO: Asegurar que el usuario termine en @bogos.com
$nombre_usuario = trim($nombre_usuario);
if (!str_ends_with(strtolower($nombre_usuario), '@bogos.com')) {
    $nombre_usuario .= '@bogos.com';
}

try {
    // Validar que el usuario no exista
    $stmtCheck = $pdo->prepare("SELECT id_usuario FROM usuarios WHERE usuario = ? AND id_usuario != ?");
    $stmtCheck->execute([$nombre_usuario, $id_usuario ?? 0]);
    if ($stmtCheck->rowCount() > 0) {
        echo json_encode(['exito' => false, 'mensaje' => "El usuario ($nombre_usuario) ya está en uso. Elige otro."]);
        exit;
    }

    if ($id_usuario) {
        if (!empty($password)) {
            // Actualizar GUARDANDO TEXTO PLANO
            $stmt = $pdo->prepare("UPDATE usuarios SET nombre_completo = ?, usuario = ?, rol = ?, contrasena_hash = ? WHERE id_usuario = ?");
            $stmt->execute([$nombre_completo, $nombre_usuario, $rol, $password, $id_usuario]);
        } else {
            // Actualizar sin cambiar contraseña
            $stmt = $pdo->prepare("UPDATE usuarios SET nombre_completo = ?, usuario = ?, rol = ? WHERE id_usuario = ?");
            $stmt->execute([$nombre_completo, $nombre_usuario, $rol, $id_usuario]);
        }
        $mensaje = 'Usuario actualizado correctamente.';
    } else {
        // Crear nuevo GUARDANDO TEXTO PLANO
        $stmt = $pdo->prepare("INSERT INTO usuarios (nombre_completo, usuario, contrasena_hash, rol, activo) VALUES (?, ?, ?, ?, 1)");
        $stmt->execute([$nombre_completo, $nombre_usuario, $password, $rol]);
        $mensaje = 'Usuario registrado exitosamente.';
    }

    echo json_encode(['exito' => true, 'mensaje' => $mensaje]);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al guardar: ' . $e->getMessage()]);
}
?>