(async function verificarAcceso() {
    try {
        const respuesta = await fetch('../config/verificar_sesion.php');
        const datos = await respuesta.json();
        if (!datos.exito) {
            window.location.replace('../Inicio/index.html');
        }
    } catch (error) {
        window.location.replace('../Inicio/index.html');
    }
})();