<?php
$host = 'localhost';
$dbname = 'botanas_bogos';
$username = 'root'; // Usuario por defecto en XAMPP/Laragon
$password = ''; // Deja vacío si no le tienes contraseña a tu MySQL local

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    // Configurar PDO para que lance excepciones en caso de error
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    // Si falla, devuelve un JSON para que el frontend no se rompa
    die(json_encode(['exito' => false, 'mensaje' => 'Error de conexión a la base de datos']));
}
?>