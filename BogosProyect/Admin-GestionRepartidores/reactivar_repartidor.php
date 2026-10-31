<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);
$id_repartidor = $datos['id_repartidor'] ?? null;

if (!$id_repartidor) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID no proporcionado.']);
    exit;
}

try {
    // NUEVO CANDADO: Verificar si la cuenta maestra de usuario está activa
    $stmtCheck = $pdo->prepare("
        SELECT u.activo 
        FROM usuarios u 
        INNER JOIN repartidores r ON u.id_usuario = r.id_usuario 
        WHERE r.id_repartidor = ?
    ");
    $stmtCheck->execute([$id_repartidor]);
    
    if ($stmtCheck->fetchColumn() == 0) {
        echo json_encode(['exito' => false, 'mensaje' => 'Denegado: No puedes reactivar a este repartidor porque su cuenta de acceso fue revocada. Restáuralo desde la sección "Usuarios".']);
        exit;
    }

    $stmt = $pdo->prepare("UPDATE repartidores SET activo = 1 WHERE id_repartidor = ?");
    $stmt->execute([$id_repartidor]);
    echo json_encode(['exito' => true, 'mensaje' => 'Repartidor reincorporado a la logística.']);
} catch (Exception $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error al reactivar: ' . $e->getMessage()]);
}
?>