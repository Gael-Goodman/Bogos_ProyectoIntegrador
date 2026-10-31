<?php
session_start();

// Destruir todas las variables de sesión
session_unset();
session_destroy();

// Devolver respuesta JSON al fetch de JavaScript
header('Content-Type: application/json');
echo json_encode(['exito' => true, 'mensaje' => 'Sesión cerrada correctamente']);
?>