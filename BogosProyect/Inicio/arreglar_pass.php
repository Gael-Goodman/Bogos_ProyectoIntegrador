<?php
require_once 'config/conexion.php'; // Ajusta la ruta si es necesario

try {
    // Generar hashes reales usando tu propio servidor
    $hashAdmin = password_hash('Admin123', PASSWORD_DEFAULT);
    $hashRep = password_hash('Rep123', PASSWORD_DEFAULT);

    // Actualizar al Administrador
    $stmt1 = $pdo->prepare("UPDATE usuarios SET contrasena_hash = ? WHERE usuario = 'admin@bogos.com'");
    $stmt1->execute([$hashAdmin]);

    // Actualizar a los Repartidores
    $stmt2 = $pdo->prepare("UPDATE usuarios SET contrasena_hash = ? WHERE rol = 'Repartidor'");
    $stmt2->execute([$hashRep]);

    echo "<h3>¡Éxito! Las contraseñas han sido encriptadas con hashes reales.</h3>";
    echo "<p>Ya puedes ir a iniciar sesión con <b>Admin123</b> y <b>Rep123</b>.</p>";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage();
}
?>