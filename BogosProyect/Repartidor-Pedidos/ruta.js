let pedidosRutaGlobal = [];

document.addEventListener("DOMContentLoaded", () => {
    // 1. Cargar los pedidos al iniciar
    cargarRuta();

    // 2. Evento para confirmar un problema (Rechazado, Cancelado, No entregado)
    document.getElementById("btnConfirmarProblema").addEventListener("click", confirmarProblema);

    // 3. Evento para cerrar sesión
    document.getElementById("btnCerrarSesion").addEventListener("click", async (e) => {
        e.preventDefault();
        if (confirm("¿Estás seguro de que deseas salir de tu ruta?")) {
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

// ================= 1. CARGA Y RENDERIZADO DE LA RUTA =================

async function cargarRuta() {
    const contenedor = document.getElementById("contenedorPedidos");
    
    // Animación de carga nativa
    contenedor.innerHTML = `
        <div class="text-center mt-5">
            <div class="spinner-border text-primary" role="status"></div>
            <p class="text-muted mt-2 fw-semibold">Sincronizando ruta...</p>
        </div>
    `;

    try {
        const respuesta = await fetch('obtener_ruta.php');
        const datos = await respuesta.json();

        if (datos.exito) {
            document.getElementById("lblNombreRepartidor").textContent = `Hola, ${datos.repartidor}`;
            
            pedidosRutaGlobal = datos.pedidos;
            
            if (pedidosRutaGlobal.length > 0) {
                document.getElementById("lblResumenRuta").textContent = `Tienes ${pedidosRutaGlobal.length} paquete(s) por entregar`;
            } else {
                document.getElementById("lblResumenRuta").textContent = `Has terminado tu ruta de hoy`;
            }

            renderizarTarjetas(pedidosRutaGlobal);
        } else {
            if (datos.codigo === 'NO_AUTORIZADO') window.location.href = '../Inicio/index.html';
            contenedor.innerHTML = `<div class="alert alert-danger m-3 border-0 shadow-sm">${datos.mensaje}</div>`;
        }
    } catch (error) {
        contenedor.innerHTML = `
            <div class="text-center mt-5">
                <i class="fa-solid fa-wifi text-danger fs-1 mb-2"></i>
                <p class="text-muted fw-bold">Sin conexión al servidor.</p>
            </div>`;
    }
}

function renderizarTarjetas(pedidos) {
    const contenedor = document.getElementById("contenedorPedidos");
    contenedor.innerHTML = "";

    if (pedidos.length === 0) {
        contenedor.innerHTML = `
            <div class="text-center mt-5 pt-4">
                <i class="fa-solid fa-mug-hot fs-1 text-secondary mb-3 opacity-50"></i>
                <h4 class="text-muted fw-bold">Ruta Limpia</h4>
                <p class="text-muted small">No tienes pedidos pendientes por entregar.<br>¡Buen trabajo!</p>
            </div>
        `;
        return;
    }

    pedidos.forEach(p => {
        // Iconos dinámicos de pago
        let iconoPago = '💵';
        let clasePago = 'text-success';
        if (p.forma_pago === 'Tarjeta') { iconoPago = '💳'; clasePago = 'text-primary'; }
        if (p.forma_pago === 'Transferencia') { iconoPago = '📱'; clasePago = 'text-info'; }

        // Creación de la tarjeta móvil
        const card = document.createElement("div");
        card.className = "card card-pedido shadow-sm mb-4 border-0";
        card.innerHTML = `
            <div class="card-body p-3">
                
                <!-- Encabezado Tarjeta -->
                <div class="d-flex justify-content-between align-items-start mb-2">
                    <div>
                        <span class="badge bg-dark mb-1">Folio #${p.id_pedido}</span>
                        <h5 class="fw-bold mb-0 text-dark lh-sm" style="font-size: 1.15rem;">${p.cliente}</h5>
                    </div>
                    <h5 class="fw-bold text-success mb-0">$${parseFloat(p.total).toFixed(2)}</h5>
                </div>
                
                <!-- Dirección -->
                <p class="text-muted small mb-2 lh-sm border-bottom pb-2">
                    <i class="fa-solid fa-location-dot me-1 text-danger"></i> ${p.direccion}
                </p>
                
                <!-- Método de cobro -->
                <p class="small fw-bold mb-3 ${clasePago}">
                    ${iconoPago} Cobro en ${p.forma_pago}
                </p>
                
                <!-- Botones Superiores (Mapa y Detalle) -->
                <div class="d-flex gap-2 mb-2">
                    <button class="btn btn-light text-primary flex-fill btn-accion-movil border shadow-sm" onclick="abrirMapa('${p.direccion}')">
                        <i class="fa-solid fa-map-location-dot fs-5 d-block mb-1"></i> Mapa
                    </button>
                    <button class="btn btn-light text-dark flex-fill btn-accion-movil border shadow-sm" onclick="verDetallesPedido(${p.id_pedido}, ${p.total}, '${p.forma_pago}')">
                        <i class="fa-solid fa-box-open fs-5 d-block mb-1 text-secondary"></i> Ver Cajas
                    </button>
                </div>
                
                <!-- Botones Inferiores (Problema y Entregado) -->
                <div class="d-flex gap-2">
                    <button class="btn btn-outline-danger btn-accion-movil px-3 shadow-sm" onclick="abrirModalProblema(${p.id_pedido})" title="Reportar Problema">
                        <i class="fa-solid fa-triangle-exclamation"></i>
                    </button>
                    <button class="btn btn-success flex-fill btn-accion-movil text-white shadow-sm fw-bold fs-5" onclick="marcarEntregado(${p.id_pedido})">
                        <i class="fa-solid fa-check-double me-1"></i> Entregado
                    </button>
                </div>
            </div>
        `;
        contenedor.appendChild(card);
    });
}

// ================= 2. HERRAMIENTAS DEL REPARTIDOR =================

function abrirMapa(direccion) {
    // Codifica la dirección y abre la app de Google Maps en el celular o nueva pestaña
    const direccionCodificada = encodeURIComponent(direccion);
    const urlMaps = `https://www.google.com/maps/search/?api=1&query=${direccionCodificada}`;
    window.open(urlMaps, '_blank');
}

async function verDetallesPedido(id_pedido, total, forma_pago) {
    // Prepara el modal con los montos a cobrar
    document.getElementById("lblModalFolio").textContent = id_pedido;
    document.getElementById("lblModalTotal").textContent = `$${parseFloat(total).toFixed(2)}`;
    
    let iconoPago = forma_pago === 'Tarjeta' ? '💳' : (forma_pago === 'Transferencia' ? '📱' : '💵');
    document.getElementById("lblModalPago").innerHTML = `${iconoPago} Pago en <b>${forma_pago}</b>`;
    
    const lista = document.getElementById("listaProductosModal");
    lista.innerHTML = `<div class="text-center text-muted py-3"><div class="spinner-border spinner-border-sm me-2"></div>Buscando productos...</div>`;
    
    const modal = new bootstrap.Modal(document.getElementById('modalDetalleProductos'));
    modal.show();

    // Consulta los productos específicos de ese paquete
    try {
        const respuesta = await fetch(`obtener_detalle_ruta.php?id_pedido=${id_pedido}`);
        const data = await respuesta.json();
        
        if (data.exito) {
            lista.innerHTML = data.productos.map(p => `
                <li class="list-group-item d-flex justify-content-between align-items-center px-2 py-3 border-bottom">
                    <div>
                        <span class="badge bg-secondary rounded-pill fs-6 me-2">${p.cantidad}</span> 
                        <span class="fw-semibold text-dark fs-6">${p.nombre}</span>
                    </div>
                </li>
            `).join('');
        } else {
            lista.innerHTML = `<div class="alert alert-danger m-2">Error: ${data.mensaje}</div>`;
        }
    } catch (error) {
        lista.innerHTML = `<div class="alert alert-danger m-2">Error de conexión.</div>`;
    }
}

// ================= 3. ACCIONES DE ENTREGA (EL DISPARADOR) =================

function marcarEntregado(id_pedido) {
    if (confirm("✅ ¿Confirmas que entregaste los productos y realizaste el cobro correctamente?")) {
        procesarEstadoPedido(id_pedido, 'Entregada');
    }
}

function abrirModalProblema(id_pedido) {
    document.getElementById("lblModalProblemaFolio").textContent = id_pedido;
    document.getElementById("inputProblemaIdPedido").value = id_pedido;
    const modal = new bootstrap.Modal(document.getElementById('modalProblema'));
    modal.show();
}

function confirmarProblema() {
    const id_pedido = document.getElementById("inputProblemaIdPedido").value;
    const nuevo_estado = document.getElementById("selectMotivoProblema").value;
    
    procesarEstadoPedido(id_pedido, nuevo_estado);
    bootstrap.Modal.getInstance(document.getElementById('modalProblema')).hide();
}

async function procesarEstadoPedido(id_pedido, nuevo_estado) {
    // Nota: El backend del repartidor detectará automáticamente el ID del repartidor por su sesión
    try {
        const respuesta = await fetch('actualizar_estado_repartidor.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                id_pedido: id_pedido, 
                estado: nuevo_estado 
            })
        });
        
        const data = await respuesta.json();
        if (data.exito) {
            cargarRuta(); // Refresca la ruta, quitando el pedido entregado de la pantalla
        } else {
            alert("Error: " + data.mensaje);
        }
    } catch (error) {
        alert("Error de red. Revisa tu conexión a internet e intenta de nuevo.");
    }
}