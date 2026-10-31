let clientesGlobal = [];
let modalCliente;

document.addEventListener("DOMContentLoaded", () => {
    // Inicializar modal de Bootstrap
    modalCliente = new bootstrap.Modal(document.getElementById('modalCliente'));

    // Configurar fecha actual con mayúscula y prefijo
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    let fecha = new Date().toLocaleDateString('es-ES', opcionesFecha);
    fecha = fecha.charAt(0).toUpperCase() + fecha.slice(1);
    document.getElementById("fechaActual").innerText = "Hoy: " + fecha;
    
    // Cargar datos iniciales
    cargarClientes('activos');

    // Event Listeners
    document.getElementById("btnNuevoCliente").addEventListener("click", abrirModalNuevo);
    document.getElementById("btnGuardarCliente").addEventListener("click", guardarCliente);
    document.getElementById("buscarCliente").addEventListener("input", filtrarClientes);

    // Pestañas
    document.getElementById("tabActivos").addEventListener("click", (e) => cambiarPestaña(e, 'activos'));
    document.getElementById("tabInactivos").addEventListener("click", (e) => cambiarPestaña(e, 'inactivos'));

    // Lógica para cerrar sesión
    document.getElementById("btnCerrarSesion").addEventListener("click", async (e) => {
        e.preventDefault();
        if (confirm("¿Estás seguro de que deseas cerrar sesión?")) {
            try {
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

    // Limpiar estilos
    [tabActivos, tabInactivos].forEach(tab => {
        tab.classList.remove('active', 'fw-bold', 'border-bottom', 'border-3');
        tab.style.color = '#6c757d';
        tab.style.borderColor = 'transparent';
    });

    // Activar pestaña actual
    e.target.classList.add('active', 'fw-bold', 'border-bottom', 'border-3');
    e.target.style.color = '#d11f26';
    e.target.style.borderColor = '#d11f26';

    // Alternar vistas
    if (estado === 'activos') {
        vistaActivos.classList.remove('d-none');
        vistaInactivos.classList.add('d-none');
        cargarClientes('activos');
    } else {
        vistaActivos.classList.add('d-none');
        vistaInactivos.classList.remove('d-none');
        cargarClientes('inactivos');
    }
}

// ================= OBTENER Y RENDERIZAR =================

async function cargarClientes(estado) {
    const url = estado === 'activos' ? 'obtener_clientes.php' : 'obtener_inactivos.php';
    const tbodyId = estado === 'activos' ? 'tablaClientesActivos' : 'tablaClientesInactivos';
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
            clientesGlobal = datos.clientes;
            renderizarClientes(clientesGlobal, estado);
        } else {
            renderizarClientes(datos.clientes, estado);
        }

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="5" class="text-center text-danger py-4">Error al conectar con el servidor.</td></tr>`;
    }
}

function renderizarClientes(lista, estado) {
    const tbodyId = estado === 'activos' ? 'tablaClientesActivos' : 'tablaClientesInactivos';
    const tbody = document.getElementById(tbodyId);
    tbody.innerHTML = "";

    if (lista.length === 0) {
        const cols = estado === 'activos' ? 5 : 4;
        tbody.innerHTML = `<tr><td colspan="${cols}" class="text-center text-muted py-4">No se encontraron clientes.</td></tr>`;
        return;
    }

    lista.forEach(cliente => {
        const tr = document.createElement("tr");

        if (estado === 'activos') {
            tr.innerHTML = `
                <td class="ps-4 fw-bold text-dark">${cliente.nombre_negocio}</td>
                <td>${cliente.nombre_contacto || '<span class="text-muted fst-italic">Sin contacto</span>'}</td>
                <td>${cliente.telefono || '<span class="text-muted fst-italic">N/A</span>'}</td>
                <td><small>${cliente.direccion}</small></td>
                <td class="text-center pe-4">
                    <!-- AHORA SOLO PASAMOS EL ID PARA EVITAR ERRORES DE COMILLAS -->
                    <button class="btn btn-sm btn-outline-primary me-1" onclick="abrirModalEditar(${cliente.id_cliente})" title="Editar">
                        <i class="fa-solid fa-pen-to-square"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="desactivarCliente(${cliente.id_cliente})" title="Eliminar">
                        <i class="fa-solid fa-trash-can"></i>
                    </button>
                </td>
            `;
        } else {
            tr.innerHTML = `
                <td class="ps-4 fw-bold text-muted">${cliente.nombre_negocio}</td>
                <td class="text-muted">${cliente.nombre_contacto || '-'}</td>
                <td class="text-muted"><small>${cliente.direccion}</small></td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm btn-success fw-bold" onclick="reactivarCliente(${cliente.id_cliente})">
                        <i class="fa-solid fa-rotate-left me-1"></i> Reactivar
                    </button>
                </td>
            `;
        }
        tbody.appendChild(tr);
    });
}

function filtrarClientes() {
    const termino = document.getElementById("buscarCliente").value.toLowerCase();
    const filtrados = clientesGlobal.filter(c => 
        c.nombre_negocio.toLowerCase().includes(termino) || 
        (c.nombre_contacto && c.nombre_contacto.toLowerCase().includes(termino)) || 
        (c.telefono && c.telefono.toLowerCase().includes(termino))
    );
    renderizarClientes(filtrados, 'activos');
}

// ================= MODAL Y GUARDADO =================

function abrirModalNuevo() {
    document.getElementById("formCliente").reset();
    document.getElementById("inputIdCliente").value = "";
    document.getElementById("tituloModalCliente").innerText = "Nueva Tiendita";
    modalCliente.show();
}

function abrirModalEditar(id_cliente) {
    // BUSCAMOS EL CLIENTE DIRECTAMENTE EN EL ARREGLO GLOBAL
    const cliente = clientesGlobal.find(c => c.id_cliente === id_cliente);
    if (!cliente) return;

    document.getElementById("inputIdCliente").value = cliente.id_cliente;
    document.getElementById("inputNegocio").value = cliente.nombre_negocio;
    document.getElementById("inputContacto").value = cliente.nombre_contacto || "";
    document.getElementById("inputTelefono").value = cliente.telefono || "";
    document.getElementById("inputDireccion").value = cliente.direccion;
    document.getElementById("inputReferencias").value = cliente.referencias || "";
    document.getElementById("inputLatitud").value = cliente.latitud || "";
    document.getElementById("inputLongitud").value = cliente.longitud || "";
    
    // DATOS FISCALES
    document.getElementById("inputRfc").value = cliente.rfc || "";
    document.getElementById("inputRazonSocial").value = cliente.razon_social || "";
    document.getElementById("inputCpFiscal").value = cliente.codigo_postal_fiscal || "";
    document.getElementById("selectRegimen").value = cliente.regimen_fiscal || "";
    document.getElementById("selectUsoCfdi").value = cliente.uso_cfdi || "";
    document.getElementById("inputCorreoFactura").value = cliente.correo_facturacion || "";
    
    document.getElementById("tituloModalCliente").innerText = "Editar Tiendita";
    modalCliente.show();
}

async function guardarCliente() {
    const id = document.getElementById("inputIdCliente").value;
    const datos = {
        id_cliente: id ? parseInt(id) : null,
        nombre_negocio: document.getElementById("inputNegocio").value.trim(),
        nombre_contacto: document.getElementById("inputContacto").value.trim(),
        telefono: document.getElementById("inputTelefono").value.trim(),
        direccion: document.getElementById("inputDireccion").value.trim(),
        referencias: document.getElementById("inputReferencias").value.trim(),
        latitud: document.getElementById("inputLatitud").value ? parseFloat(document.getElementById("inputLatitud").value) : null,
        longitud: document.getElementById("inputLongitud").value ? parseFloat(document.getElementById("inputLongitud").value) : null,
        
        // DATOS FISCALES
        rfc: document.getElementById("inputRfc").value.trim(),
        razon_social: document.getElementById("inputRazonSocial").value.trim(),
        codigo_postal_fiscal: document.getElementById("inputCpFiscal").value.trim(),
        regimen_fiscal: document.getElementById("selectRegimen").value,
        uso_cfdi: document.getElementById("selectUsoCfdi").value,
        correo_facturacion: document.getElementById("inputCorreoFactura").value.trim()
    };

    if (!datos.nombre_negocio || !datos.direccion) {
        alert("El nombre del negocio y la dirección son obligatorios.");
        return;
    }

    try {
        const respuesta = await fetch('guardar_cliente.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            modalCliente.hide();
            cargarClientes('activos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al guardar el cliente.");
    }
}

// ================= BORRADO LÓGICO Y REACTIVACIÓN =================

async function desactivarCliente(id) {
    if (!confirm("¿Seguro que deseas enviar esta tiendita a la papelera?")) return;

    try {
        const respuesta = await fetch('desactivar_cliente.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_cliente: id })
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            cargarClientes('activos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al desactivar el cliente.");
    }
}

async function reactivarCliente(id) {
    if (!confirm("¿Deseas restaurar esta tiendita?")) return;

    try {
        const respuesta = await fetch('reactivar_cliente.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_cliente: id })
        });
        const resultado = await respuesta.json();
        
        if (resultado.exito) {
            cargarClientes('inactivos');
        } else {
            alert(resultado.mensaje);
        }
    } catch (error) {
        alert("Error al reactivar el cliente.");
    }
}