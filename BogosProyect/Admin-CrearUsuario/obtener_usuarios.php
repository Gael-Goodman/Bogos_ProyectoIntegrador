<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';

try {
    // Usamos 'AS nombre_usuario' para que JavaScript lo reconozca sin tener que modificar usuarios.js
    $stmt = $pdo->query("SELECT id_usuario, nombre_completo, usuario AS nombre_usuario, rol FROM usuarios WHERE activo = 1 ORDER BY nombre_completo ASC");
    $usuarios = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $usuario_sesion = ['nombre' => $_SESSION['nombre_completo'] ?? 'Administrador'];

    echo json_encode(['exito' => true, 'usuario' => $usuario_sesion, 'usuarios' => $usuarios]);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de BD: ' . $e->getMessage()]);
}
?>