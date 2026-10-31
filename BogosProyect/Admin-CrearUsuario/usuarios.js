let usuariosGlobal = [];
let modalUsuario;

document.addEventListener("DOMContentLoaded", () => {
    // Configurar fecha actual
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    let fecha = new Date().toLocaleDateString('es-ES', opcionesFecha);
    fecha = fecha.charAt(0).toUpperCase() + fecha.slice(1);
    document.getElementById("fechaActual").innerText = "Hoy: " + fecha;

    // Inicializar modal
    modalUsuario = new bootstrap.Modal(document.getElementById('modalUsuario'));

    // Cargar datos al iniciar
    cargarUsuarios('activos');

    // Listeners de eventos
    document.getElementById("btnNuevoUsuario").addEventListener("click", abrirModalNuevo);
    document.getElementById("btnGuardarUsuario").addEventListener("click", guardarUsuario);
    document.getElementById("buscarUsuario").addEventListener("input", filtrarUsuarios);

    // Pestañas
    document.getElementById("tabActivos").addEventListener("click", (e) => cambiarPestaña(e, 'activos'));
    document.getElementById("tabInactivos").addEventListener("click", (e) => cambiarPestaña(e, 'inactivos'));


    // Lógica para cerrar sesión
    document.getElementById("btnCerrarSesion").addEventListener("click", async (e) => {
        e.preventDefault();
        if (confirm("¿Estás seguro de que deseas cerrar sesión?")) {
            try {
                // Apuntamos a un archivo global de cierre de sesión
                const respuesta = await fetch('../config/logout.php');
                if (respuesta.ok) {
                    window.location.href = '../Inicio/index.html';
                }
            } catch (error) {
                console.error("Error al cerrar sesión:", error);
            }
        }
    });
});

// ================= LÓGICA DE PESTAÑAS =================

function cambiarPestaña(e, estado) {
    e.preventDefault();
    const tabActivos = document.getElementById("tabActivos");
    const tabInactivos = document.getElementById("tabInactivos");
    const vistaActivos = document.getElementById("vistaActivos");
    const vistaInactivos = document.getElementById("vistaInactivos");

    [tabActivos, tabInactivos].forEach(tab => {
        tab.classList.remove('active', 'fw-bold', 'border-bottom', 'border-3');
        tab.style.color = '#6c757d';
        tab.style.borderColor = 'transparent';
    });

    e.target.classList.add('active', 'fw-bold', 'border-bottom', 'border-3');
    e.target.style.color = '#d11f26';
    e.target.style.borderColor = '#d11f26';

    if (estado === 'activos') {
        vistaActivos.classList.remove('d-none');
        vistaInactivos.classList.add('d-none');
        cargarUsuarios('activos');
    } else {
        vistaActivos.classList.add('d-none');
        vistaInactivos.classList.remove('d-none');
        cargarUsuarios('inactivos');
    }
}

// ================= CARGAR DATOS =================

async function cargarUsuarios(estado) {
    const url = estado === 'activos' ? 'obtener_usuarios.php' : 'obtener_usuarios_inactivos.php';
    const tbodyId = estado === 'activos' ? 'tablaUsuariosActivos' : 'tablaUsuariosInactivos';
    const tbody = document.getElementById(tbodyId);

    try {
        const respuesta = await fetch(url);
        const datos = await respuesta.json();

        if (!datos.exito) {
            tbody.innerHTML = `<tr><td colspan="4" class="text-center text-danger py-4">${datos.mensaje}</td></tr>`;
            return;
        }

        // Actualizar el nombre del admin logueado en la esquina superior derecha
        if (datos.usuario && datos.usuario.nombre) {
            document.getElementById("nombreAdmin").innerText = datos.usuario.nombre;
        }

        if (estado === 'activos') {
            usuariosGlobal = datos.usuarios;
            renderizarUsuarios(usuariosGlobal, estado);
        } else {
            renderizarUsuarios(datos.usuarios, estado);
        }

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="4" class="text-center text-danger py-4">Error de conexión.</td></tr>`;
    }
}

function renderizarUsuarios(lista, estado) {
    const tbodyId = estado === 'activos' ? 'tablaUsuariosActivos' : 'tablaUsuariosInactivos';
    const tbody = document.getElementById(tbodyId);
    tbody.innerHTML = "";

    if (lista.length === 0) {
        tbody.innerHTML = `<tr><td colspan="4" class="text-center text-muted py-4">No hay cuentas registradas.</td></tr>`;
        return;
    }

    lista.forEach(user => {
        const tr = document.createElement("tr");
        
        // Estilos para el badge del rol
        let badgeClass = user.rol === 'Administrador' ? 'bg-primary' : 'bg-info text-dark';

        if (estado === 'activos') {
            tr.innerHTML = `
                <td class="ps-4 fw-bold text-dark"><i class="fa-solid fa-user text-secondary me-2"></i> ${user.nombre_completo}</td>
                <td><span class="text-muted fw-semibold">${user.nombre_usuario}</span></td>
                <td><span class="badge ${badgeClass}">${user.rol}</span></td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm btn-outline-primary me-1" onclick='abrirModalEditar(${JSON.stringify(user)})' title="Editar">
                        <i class="fa-solid fa-pen-to-square"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="desactivarUsuario(${user.id_usuario})" title="Revocar Acceso">
                        <i class="fa-solid fa-ban"></i>
                    </button>
                </td>
            `;
        } else {
            tr.innerHTML = `
                <td class="ps-4 fw-bold text-muted">${user.nombre_completo}</td>
                <td class="text-muted">${user.nombre_usuario}</td>
                <td><span class="badge bg-secondary">${user.rol}</span></td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm btn-success fw-bold" onclick="reactivarUsuario(${user.id_usuario})">
                        <i class="fa-solid fa-rotate-left me-1"></i> Reactivar
                    </button>
                </td>
            `;
        }
        tbody.appendChild(tr);
    });
}

function filtrarUsuarios() {
    const termino = document.getElementById("buscarUsuario").value.toLowerCase();
    const filtrados = usuariosGlobal.filter(u => 
        u.nombre_completo.toLowerCase().includes(termino) || 
        u.nombre_usuario.toLowerCase().includes(termino) || 
        u.rol.toLowerCase().includes(termino)
    );
    renderizarUsuarios(filtrados, 'activos');
}

// ================= MODAL Y GUARDADO =================

function abrirModalNuevo() {
    document.getElementById("formUsuario").reset();
    document.getElementById("inputIdUsuario").value = "";
    document.getElementById("tituloModalUsuario").innerText = "Nuevo Usuario";
    
    // Contraseña obligatoria
    document.getElementById("inputPassword").required = true;
    document.getElementById("reqPassword").style.display = "inline";
    document.getElementById("helpPassword").style.display = "none";
    
    // Desbloquear usuario
    document.getElementById("inputNombreUsuario").disabled = false;

    modalUsuario.show();
}

function abrirModalEditar(user) {
    document.getElementById("inputIdUsuario").value = user.id_usuario;
    document.getElementById("inputNombreCompleto").value = user.nombre_completo;
    document.getElementById("inputNombreUsuario").value = user.nombre_usuario;
    document.getElementById("selectRol").value = user.rol;
    document.getElementById("inputPassword").value = "";
    
    document.getElementById("tituloModalUsuario").innerText = "Editar Usuario";
    
    // Contraseña opcional al editar
    document.getElementById("inputPassword").required = false;
    document.getElementById("reqPassword").style.display = "none";
    document.getElementById("helpPassword").style.display = "block";
    
    // Evitar que le cambien el login a uno existente, mejor lo bloqueamos o lo dejamos con cuidado.
    // Por seguridad, dejaremos que lo editen pero se validará en PHP.

    modalUsuario.show();
}

async function guardarUsuario() {
    const id = document.getElementById("inputIdUsuario").value;
    const password = document.getElementById("inputPassword").value;
    
    const datos = {
        id_usuario: id ? parseInt(id) : null,
        nombre_completo: document.getElementById("inputNombreCompleto").value.trim(),
        nombre_usuario: document.getElementById("inputNombreUsuario").value.trim(),
        rol: document.getElementById("selectRol").value,
        password: password
    };

    if (!datos.nombre_completo || !datos.nombre_usuario) {
        alert("El nombre completo y el usuario de acceso son obligatorios.");
        return;
    }

    if (!id && !password) {
        alert("Para un usuario nuevo, la contraseña es obligatoria.");
        return;
    }

    try {
        const respuesta = await fetch('guardar_usuario.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            modalUsuario.hide();
            cargarUsuarios('activos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al guardar el usuario.");
    }
}

// ================= BORRADO LÓGICO Y REACTIVACIÓN =================

async function desactivarUsuario(id) {
    if (!confirm("¿Seguro que deseas revocarle el acceso a este usuario? (No podrá iniciar sesión)")) return;

    try {
        const respuesta = await fetch('desactivar_usuario.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_usuario: id })
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            cargarUsuarios('activos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al dar de baja.");
    }
}

async function reactivarUsuario(id) {
    if (!confirm("¿Deseas restaurar el acceso a este usuario?")) return;

    try {
        const respuesta = await fetch('reactivar_usuario.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_usuario: id })
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            cargarUsuarios('inactivos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al reactivar.");
    }
}