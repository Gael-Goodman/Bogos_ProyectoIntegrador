<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);
$id_usuario_restaurar = $datos['id_usuario'] ?? null;

if (!$id_usuario_restaurar) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID no proporcionado.']);
    exit;
}

try {
    $pdo->beginTransaction();

    // 1. Restaurar el acceso al sistema
    $stmt = $pdo->prepare("UPDATE usuarios SET activo = 1 WHERE id_usuario = ?");
    $stmt->execute([$id_usuario_restaurar]);

    // 2. Si el usuario es repartidor, restaurar su perfil logístico automáticamente
    $stmtRep = $pdo->prepare("UPDATE repartidores SET activo = 1 WHERE id_usuario = ?");
    $stmtRep->execute([$id_usuario_restaurar]);

    $pdo->commit();
    echo json_encode(['exito' => true, 'mensaje' => 'Acceso y perfil restaurados correctamente.']);
} catch (Exception $e) {
    $pdo->rollBack();
    echo json_encode(['exito' => false, 'mensaje' => 'Error al reactivar: ' . $e->getMessage()]);
}
?>