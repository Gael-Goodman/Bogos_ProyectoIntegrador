<?php
// Iniciar la sesión para mantener al usuario conectado en las demás pantallas
session_start();
header('Content-Type: application/json');

// Requerir el archivo de conexión PDO
require_once '../config/conexion.php';

// Capturar los datos enviados por fetch
$usuario = $_POST['usuario'] ?? '';
$contrasena = $_POST['contrasena'] ?? '';
$rol_formulario = $_POST['rol'] ?? '';

// 1. Validar que no lleguen datos vacíos
if (empty($usuario) || empty($contrasena) || empty($rol_formulario)) {
    echo json_encode(['exito' => false, 'mensaje' => 'Por favor, complete todos los campos y seleccione un rol.']);
    exit;
}

try {
    // 2. Buscar al usuario en la base de datos
    $stmt = $pdo->prepare("SELECT id_usuario, nombre_completo, contrasena_hash, rol, activo FROM usuarios WHERE usuario = :usuario LIMIT 1");
    $stmt->bindParam(':usuario', $usuario);
    $stmt->execute();

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        // 3. Validar si el empleado está dado de baja (activo = 0)
        if ($user['activo'] == 0) {
            echo json_encode(['exito' => false, 'mensaje' => 'Este usuario está inactivo en el sistema.']);
            exit;
        }

        // 4. Validar que el rol del formulario coincida con el de la base de datos
        if ($user['rol'] !== $rol_formulario) {
            echo json_encode(['exito' => false, 'mensaje' => 'El rol seleccionado no coincide con los permisos de su cuenta.']);
            exit;
        }

        // 5. Validar la contraseña (Texto plano para desarrollo)
        if ($contrasena === $user['contrasena_hash']) {
            
            // 6. Iniciar variables de sesión
            $_SESSION['id_usuario'] = $user['id_usuario'];
            $_SESSION['nombre_completo'] = $user['nombre_completo'];
            $_SESSION['rol'] = $user['rol'];

            echo json_encode([
                'exito' => true, 
                'rol' => $user['rol'],
                'mensaje' => 'Inicio de sesión exitoso'
            ]);
        } else {
            echo json_encode(['exito' => false, 'mensaje' => 'Contraseña incorrecta.']);
        }
    } else {
        echo json_encode(['exito' => false, 'mensaje' => 'El usuario no existe.']);
    }

} catch (PDOException $e) {
    echo json_encode(['exito' => false, 'mensaje' => 'Error de base de datos: ' . $e->getMessage()]);
}
?>