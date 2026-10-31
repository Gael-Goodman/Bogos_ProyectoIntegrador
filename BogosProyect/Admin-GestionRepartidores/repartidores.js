let repartidoresGlobal = [];
let modalRepartidor;

document.addEventListener("DOMContentLoaded", () => {
    // Configurar fecha actual
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    let fecha = new Date().toLocaleDateString('es-ES', opcionesFecha);
    fecha = fecha.charAt(0).toUpperCase() + fecha.slice(1);
    document.getElementById("fechaActual").innerText = "Hoy: " + fecha;

    // Inicializar modal
    modalRepartidor = new bootstrap.Modal(document.getElementById('modalRepartidor'));

    // Cargar datos
    cargarRepartidores('activos');
    cargarUsuariosDisponibles();

    // Event Listeners
    document.getElementById("btnNuevoRepartidor").addEventListener("click", abrirModalNuevo);
    document.getElementById("btnGuardarRepartidor").addEventListener("click", guardarRepartidor);
    document.getElementById("buscarRepartidor").addEventListener("input", filtrarRepartidores);

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
        cargarRepartidores('activos');
    } else {
        vistaActivos.classList.add('d-none');
        vistaInactivos.classList.remove('d-none');
        cargarRepartidores('inactivos');
    }
}

// ================= CARGAR DATOS =================

async function cargarUsuariosDisponibles() {
    try {
        const respuesta = await fetch('obtener_usuarios_repartidores.php');
        const datos = await respuesta.json();
        
        const select = document.getElementById("selectUsuario");
        select.innerHTML = '<option value="">Seleccione un usuario...</option>';
        
        if (datos.exito) {
            datos.usuarios.forEach(u => {
                select.innerHTML += `<option value="${u.id_usuario}">${u.nombre_completo}</option>`;
            });
        }
    } catch (error) {
        console.error("Error al cargar usuarios:", error);
    }
}

async function cargarRepartidores(estado) {
    const url = estado === 'activos' ? 'obtener_repartidores.php' : 'obtener_inactivos.php';
    const tbodyId = estado === 'activos' ? 'tablaRepartidoresActivos' : 'tablaRepartidoresInactivos';
    const tbody = document.getElementById(tbodyId);

    try {
        const respuesta = await fetch(url);
        const datos = await respuesta.json();

        if (!datos.exito) {
            tbody.innerHTML = `<tr><td colspan="5" class="text-center text-danger py-4">${datos.mensaje}</td></tr>`;
            return;
        }

        if (datos.usuario && datos.usuario.nombre) {
            document.getElementById("nombreAdmin").innerText = datos.usuario.nombre;
        }

        if (estado === 'activos') {
            repartidoresGlobal = datos.repartidores;
            renderizarRepartidores(repartidoresGlobal, estado);
        } else {
            renderizarRepartidores(datos.repartidores, estado);
        }

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="5" class="text-center text-danger py-4">Error de conexión.</td></tr>`;
    }
}

function renderizarRepartidores(lista, estado) {
    const tbodyId = estado === 'activos' ? 'tablaRepartidoresActivos' : 'tablaRepartidoresInactivos';
    const tbody = document.getElementById(tbodyId);
    tbody.innerHTML = "";

    if (lista.length === 0) {
        const cols = estado === 'activos' ? 5 : 4;
        tbody.innerHTML = `<tr><td colspan="${cols}" class="text-center text-muted py-4">No hay repartidores registrados.</td></tr>`;
        return;
    }

    lista.forEach(rep => {
        const tr = document.createElement("tr");

        if (estado === 'activos') {
            tr.innerHTML = `
                <td class="ps-4 fw-bold text-dark"><i class="fa-solid fa-helmet-safety text-secondary me-2"></i> ${rep.nombre_completo}</td>
                <td>${rep.telefono || '<span class="text-muted fst-italic">N/A</span>'}</td>
                <td>${rep.vehiculo || '<span class="text-muted fst-italic">N/A</span>'}</td>
                <td>${rep.placas ? `<span class="badge bg-secondary">${rep.placas}</span>` : '-'}</td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm btn-outline-primary me-1" onclick='abrirModalEditar(${JSON.stringify(rep)})' title="Editar">
                        <i class="fa-solid fa-pen-to-square"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="desactivarRepartidor(${rep.id_repartidor})" title="Dar de baja">
                        <i class="fa-solid fa-trash-can"></i>
                    </button>
                </td>
            `;
        } else {
            tr.innerHTML = `
                <td class="ps-4 fw-bold text-muted">${rep.nombre_completo}</td>
                <td class="text-muted">${rep.telefono || '-'}</td>
                <td class="text-muted">${rep.vehiculo || '-'}</td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm btn-success fw-bold" onclick="reactivarRepartidor(${rep.id_repartidor})">
                        <i class="fa-solid fa-rotate-left me-1"></i> Reactivar
                    </button>
                </td>
            `;
        }
        tbody.appendChild(tr);
    });
}

function filtrarRepartidores() {
    const termino = document.getElementById("buscarRepartidor").value.toLowerCase();
    const filtrados = repartidoresGlobal.filter(r => 
        r.nombre_completo.toLowerCase().includes(termino) || 
        (r.vehiculo && r.vehiculo.toLowerCase().includes(termino)) || 
        (r.placas && r.placas.toLowerCase().includes(termino))
    );
    renderizarRepartidores(filtrados, 'activos');
}

// ================= MODAL Y GUARDADO =================

function abrirModalNuevo() {
    document.getElementById("formRepartidor").reset();
    document.getElementById("inputIdRepartidor").value = "";
    document.getElementById("selectUsuario").disabled = false;
    document.getElementById("tituloModalRepartidor").innerText = "Nuevo Repartidor";
    cargarUsuariosDisponibles(); // Refrescar lista de usuarios libres
    modalRepartidor.show();
}

function abrirModalEditar(rep) {
    document.getElementById("inputIdRepartidor").value = rep.id_repartidor;
    
    // Configurar el select con el usuario actual y bloquearlo
    const selectU = document.getElementById("selectUsuario");
    selectU.innerHTML = `<option value="${rep.id_usuario}">${rep.nombre_completo}</option>`;
    selectU.value = rep.id_usuario;
    selectU.disabled = true; // No se debe cambiar el usuario base

    document.getElementById("inputTelefono").value = rep.telefono || "";
    document.getElementById("inputVehiculo").value = rep.vehiculo || "";
    document.getElementById("inputPlacas").value = rep.placas || "";
    
    document.getElementById("tituloModalRepartidor").innerText = "Editar Repartidor";
    modalRepartidor.show();
}

async function guardarRepartidor() {
    const id = document.getElementById("inputIdRepartidor").value;
    const datos = {
        id_repartidor: id ? parseInt(id) : null,
        id_usuario: document.getElementById("selectUsuario").value,
        telefono: document.getElementById("inputTelefono").value.trim(),
        vehiculo: document.getElementById("inputVehiculo").value.trim(),
        placas: document.getElementById("inputPlacas").value.trim()
    };

    if (!datos.id_usuario) {
        alert("Debes seleccionar un usuario del sistema.");
        return;
    }

    try {
        const respuesta = await fetch('guardar_repartidor.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            modalRepartidor.hide();
            cargarRepartidores('activos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al guardar el repartidor.");
    }
}

// ================= BORRADO LÓGICO Y REACTIVACIÓN =================

async function desactivarRepartidor(id) {
    if (!confirm("¿Seguro que deseas dar de baja a este repartidor?")) return;

    try {
        const respuesta = await fetch('desactivar_repartidor.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_repartidor: id })
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            cargarRepartidores('activos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al dar de baja.");
    }
}

async function reactivarRepartidor(id) {
    if (!confirm("¿Deseas reincorporar a este repartidor?")) return;

    try {
        const respuesta = await fetch('reactivar_repartidor.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_repartidor: id })
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            cargarRepartidores('inactivos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al reactivar.");
    }
}