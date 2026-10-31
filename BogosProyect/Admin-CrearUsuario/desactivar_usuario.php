<?php
session_start();
header('Content-Type: application/json');

if (!isset($_SESSION['id_usuario']) || $_SESSION['rol'] !== 'Administrador') {
    echo json_encode(['exito' => false, 'mensaje' => 'Acceso denegado']);
    exit;
}

require_once '../config/conexion.php';
$datos = json_decode(file_get_contents("php://input"), true);
$id_usuario_baja = $datos['id_usuario'] ?? null;

if (!$id_usuario_baja) {
    echo json_encode(['exito' => false, 'mensaje' => 'ID no proporcionado.']);
    exit;
}

// PROTECCIÓN: Evitar auto-bloqueo
if ($id_usuario_baja == $_SESSION['id_usuario']) {
    echo json_encode(['exito' => false, 'mensaje' => 'Operación rechazada: No puedes revocar tu propio acceso.']);
    exit;
}

try {
    $pdo->beginTransaction();

    // 1. Revisar si el usuario es Repartidor y obtener su ID de logística
    $stmtRep = $pdo->prepare("SELECT id_repartidor FROM repartidores WHERE id_usuario = ?");
    $stmtRep->execute([$id_usuario_baja]);
    $id_repartidor = $stmtRep->fetchColumn();

    if ($id_repartidor) {
        // 2. Validar que no tenga pedidos activos en la calle
        $stmtCheck = $pdo->prepare("SELECT COUNT(*) FROM pedidos WHERE id_repartidor = ? AND estado IN ('En Ruta', 'En camino', 'Asignado')");
        $stmtCheck->execute([$id_repartidor]);
        if ($stmtCheck->fetchColumn() > 0) {
            echo json_encode(['exito' => false, 'mensaje' => 'Bloqueado: El usuario es un repartidor con pedidos en ruta.']);
            $pdo->rollBack();
            exit;
        }

        // 3. Desasignar los pedidos que solo estaban "Pendientes"
        $stmtDesasignar = $pdo->prepare("UPDATE pedidos SET id_repartidor = NULL WHERE id_repartidor = ? AND estado = 'Pendiente'");
        $stmtDesasignar->execute([$id_repartidor]);

        // 4. Dar de baja en el panel de Repartidores (Cascada)
        $stmtBajaRep = $pdo->prepare("UPDATE repartidores SET activo = 0 WHERE id_repartidor = ?");
        $stmtBajaRep->execute([$id_repartidor]);
    }

    // 5. Finalmente, revocar el acceso del sistema
    $stmtBajaUser = $pdo->prepare("UPDATE usuarios SET activo = 0 WHERE id_usuario = ?");
    $stmtBajaUser->execute([$id_usuario_baja]);

    $pdo->commit();
    echo json_encode(['exito' => true, 'mensaje' => 'Acceso revocado y sincronizado correctamente.']);
} catch (Exception $e) {
    $pdo->rollBack();
    echo json_encode(['exito' => false, 'mensaje' => 'Error al desactivar: ' . $e->getMessage()]);
}
?>