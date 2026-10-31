document.addEventListener("DOMContentLoaded", () => {
    const formLogin = document.getElementById("formLogin");
    const togglePassword = document.getElementById("togglePassword");
    const contrasenaInput = document.getElementById("contrasena");
    
    // 1. Lógica de selección de rol interactiva
    const roleBoxes = document.querySelectorAll('.role-box');
    const rolInput = document.getElementById('rolSeleccionado');

    roleBoxes.forEach(box => {
        box.addEventListener('click', () => {
            // Reiniciar estilos de ambos botones a su estado original (gris)
            roleBoxes.forEach(b => {
                b.classList.remove('border-danger', 'text-danger');
                b.classList.add('border', 'text-secondary');
            });
            
            // Pintar de rojo el botón seleccionado
            box.classList.remove('border', 'text-secondary');
            box.classList.add('border-danger', 'text-danger');
            
            // Guardar el valor exacto ('Administrador' o 'Repartidor') en el input oculto
            rolInput.value = box.getAttribute('data-rol');
        });
    });

    // 2. Funcionalidad para mostrar/ocultar la contraseña
    if (togglePassword) {
        togglePassword.addEventListener("click", () => {
            const type = contrasenaInput.getAttribute("type") === "password" ? "text" : "password";
            contrasenaInput.setAttribute("type", type);
            
            // Cambiar el ícono de FontAwesome
            const icon = togglePassword.querySelector("i");
            icon.classList.toggle("fa-eye");
            icon.classList.toggle("fa-eye-slash");
        });
    }

    // 3. Interceptar el formulario y enviarlo a PHP
    formLogin.addEventListener("submit", async (e) => {
        e.preventDefault(); // Evita que la página se recargue

        // Validar que se haya elegido un rol antes de procesar
        if (rolInput.value === "") {
            alert("Por favor, selecciona tu rol (Administrador o Repartidor) haciendo clic en los iconos.");
            return;
        }

        // Ruta de tu archivo PHP en el servidor local
        const urlBackend = 'login.php'; 
        
        // Recolectar los datos del formulario (incluyendo el rol oculto)
        const formData = new FormData(formLogin);

        try {
            const respuesta = await fetch(urlBackend, {
                method: 'POST',
                body: formData
            });

            const datos = await respuesta.json();

            if (datos.exito) {
                // Redirigir dependiendo del rol del usuario validado por el servidor
                if (datos.rol === 'Administrador') {
                    window.location.href = '../Admin-Panel/index.html';
                } else if (datos.rol === 'Repartidor') {
                    window.location.href = '../Repartidor-Pedidos/index.html';
                }
            } else {
                // Mostrar mensaje de error si las credenciales o el rol fallan
                alert("Error: " + datos.mensaje);
            }
        } catch (error) {
            console.error("Error en la conexión:", error);
            alert("No se pudo conectar con el servidor local. Verifica que XAMPP/Laragon esté ejecutándose.");
        }
    });
});