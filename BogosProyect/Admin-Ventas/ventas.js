let pedidosGlobal = [];
let productosCatalogo = [];
let carrito = [];

document.addEventListener("DOMContentLoaded", () => {
    // 1. Mostrar la fecha actual
    const fechaElement = document.getElementById("fechaActual");
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    const fechaHoy = new Date().toLocaleDateString('es-MX', opcionesFecha);
    if (fechaElement) fechaElement.textContent = `Hoy: ${fechaHoy.charAt(0).toUpperCase() + fechaHoy.slice(1)}`;

    // 2. Cargar los pedidos desde PHP
    cargarPedidos();

    // 3. Eventos para filtros de búsqueda
    document.getElementById("buscarPedido").addEventListener("input", aplicarFiltros);
    document.getElementById("filtroTiempo").addEventListener("change", aplicarFiltros);
    document.querySelectorAll('input[name="filtroTipo"]').forEach(radio => {
        radio.addEventListener("change", aplicarFiltros);
    });

    // 4. Eventos para los modales
    document.getElementById("btnNuevoPedido").addEventListener("click", abrirModalNuevoPedido);
    document.getElementById("btnAgregarAlCarrito").addEventListener("click", agregarProductoCarrito);
    document.getElementById("btnGuardarNuevoPedido").addEventListener("click", guardarNuevoPedido);
    document.getElementById("btnGuardarEstado").addEventListener("click", guardarEstado);

    // 5. Lógica para cerrar sesión
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

async function cargarPedidos() {
    try {
        const respuesta = await fetch('ventas.php');
        const datos = await respuesta.json();

        if (datos.exito) {
            document.getElementById("nombreAdmin").textContent = datos.usuario.nombre;
            pedidosGlobal = datos.pedidos;
            aplicarFiltros();
        } else {
            if (datos.codigo === 'NO_AUTORIZADO') window.location.href = '../Inicio/index.html';
            else alert("Error: " + datos.mensaje);
        }
    } catch (error) {
        document.getElementById("tablaVentas").innerHTML = `<tr><td colspan="7" class="text-center text-danger py-4">Error al conectar con el servidor.</td></tr>`;
    }
}

function renderizarTabla(pedidos) {
    const tbody = document.getElementById("tablaVentas");
    tbody.innerHTML = "";

    if (pedidos.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-muted py-4">No hay registros en esta categoría.</td></tr>`;
        return;
    }

    pedidos.forEach(pedido => {
        let badgeClass = 'bg-secondary';
        if (pedido.estado === 'Pendiente') badgeClass = 'bg-warning text-dark';
        if (pedido.estado === 'En Ruta') badgeClass = 'bg-primary';
        if (pedido.estado === 'Entregada') badgeClass = 'bg-success';
        if (pedido.estado === 'Cancelada' || pedido.estado === 'Rechazada' || pedido.estado === 'No entregada') badgeClass = 'bg-danger';

        const botonesAccion = `
            <button class="btn btn-sm btn-outline-primary me-1" title="Ver Detalle" onclick="verDetalle(${pedido.id_pedido})"><i class="fa-solid fa-eye"></i></button>
            <button class="btn btn-sm btn-outline-secondary me-1" title="Editar Estado" onclick="abrirModalEstado(${pedido.id_pedido}, '${pedido.estado}')"><i class="fa-solid fa-pen"></i></button>
        `;

        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td class="ps-4 fw-bold">#${pedido.id_pedido}</td>
            <td>${pedido.cliente}</td>
            <td>${pedido.repartidor}</td>
            <td>${pedido.fecha_registro}</td>
            <td class="text-success fw-bold">$${parseFloat(pedido.total).toFixed(2)}</td>
            <td><span class="badge ${badgeClass}">${pedido.estado}</span></td>
            <td class="text-center pe-4">${botonesAccion}</td>
        `;
        tbody.appendChild(tr);
    });
}

function aplicarFiltros() {
    const textoBusqueda = document.getElementById("buscarPedido").value.toLowerCase();
    const verPedidosActivos = document.getElementById("btnPedidos").checked;
    const verVentas = document.getElementById("btnVentas").checked;
    const verCancelados = document.getElementById("btnCancelados").checked;
    const filtroTiempo = document.getElementById("filtroTiempo").value;

    const ahora = new Date();
    const inicioHoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
    
    const diaSemana = ahora.getDay() || 7; 
    const inicioSemana = new Date(inicioHoy);
    inicioSemana.setDate(inicioHoy.getDate() - diaSemana + 1);
    
    const inicioMes = new Date(ahora.getFullYear(), ahora.getMonth(), 1);

    const pedidosFiltrados = pedidosGlobal.filter(pedido => {
        const coincideTexto = pedido.cliente.toLowerCase().includes(textoBusqueda) || pedido.id_pedido.toString().includes(textoBusqueda);
        
        let coincideCategoria = false;
        if (verPedidosActivos && (pedido.estado === 'Pendiente' || pedido.estado === 'En Ruta')) coincideCategoria = true;
        else if (verVentas && pedido.estado === 'Entregada') coincideCategoria = true;
        else if (verCancelados && (pedido.estado === 'Cancelada' || pedido.estado === 'Rechazada' || pedido.estado === 'No entregada')) coincideCategoria = true;

        let coincideTiempo = true;
        if (filtroTiempo !== 'todos') {
            const fechaTexto = pedido.fecha_registro.split(' ')[0]; 
            let fechaPedido;

            if (fechaTexto.includes('/')) {
                const partes = fechaTexto.split('/');
                fechaPedido = new Date(partes[2], partes[1] - 1, partes[0]);
            } else {
                const partes = fechaTexto.split('-');
                fechaPedido = new Date(partes[0], partes[1] - 1, partes[2]);
            }
            
            if (filtroTiempo === 'hoy') coincideTiempo = fechaPedido >= inicioHoy;
            else if (filtroTiempo === 'semana') coincideTiempo = fechaPedido >= inicioSemana;
            else if (filtroTiempo === 'mes') coincideTiempo = fechaPedido >= inicioMes;
        }
        
        return coincideTexto && coincideCategoria && coincideTiempo;
    });

    renderizarTabla(pedidosFiltrados);
}

// ================= LÓGICA DEL CARRITO Y NUEVO PEDIDO =================

async function abrirModalNuevoPedido() {
    carrito = []; 
    renderizarCarrito();
    document.getElementById("inputCantidadProducto").value = 1;
    document.getElementById("selectFormaPago").value = "Efectivo"; 
    
    try {
        const respuesta = await fetch('catalogos_pedido.php');
        const data = await respuesta.json();
        
        if (data.exito) {
            productosCatalogo = data.productos;
            
            document.getElementById("selectNuevoCliente").innerHTML = `<option value="">Seleccione un cliente...</option>` + 
                data.clientes.map(c => `<option value="${c.id_cliente}">${c.nombre_negocio}</option>`).join('');
                
            document.getElementById("selectNuevoRepartidor").innerHTML = `<option value="NULL">Sin asignar (Pendiente)</option>` + 
                data.repartidores.map(r => `<option value="${r.id_repartidor}">${r.nombre_completo}</option>`).join('');
                
            document.getElementById("selectNuevoProducto").innerHTML = `<option value="">Seleccione un producto...</option>` + 
                data.productos.map(p => `<option value="${p.id_producto}">${p.nombre} ($${parseFloat(p.precio_venta).toFixed(2)} - Disp: ${p.stock_actual})</option>`).join('');
        } else {
            alert("Error de base de datos: " + data.mensaje);
        }
    } catch (error) {
        console.error("Error al cargar catálogos:", error);
    }

    const modal = new bootstrap.Modal(document.getElementById('modalNuevoPedido'));
    modal.show();
}

function agregarProductoCarrito() {
    const select = document.getElementById("selectNuevoProducto");
    const id_producto = parseInt(select.value);
    const cantidad = parseInt(document.getElementById("inputCantidadProducto").value);

    if (!id_producto || isNaN(cantidad) || cantidad <= 0) {
        alert("Seleccione un producto válido y una cantidad mayor a 0.");
        return;
    }

    const producto = productosCatalogo.find(p => p.id_producto === id_producto);
    
    const itemExistente = carrito.find(item => item.id_producto === id_producto);
    const cantidadTotal = itemExistente ? itemExistente.cantidad + cantidad : cantidad;
    
    if (cantidadTotal > producto.stock_actual) {
        alert(`No hay suficiente stock. Disponible: ${producto.stock_actual}`);
        return;
    }

    if (itemExistente) {
        itemExistente.cantidad += cantidad;
        itemExistente.subtotal = itemExistente.cantidad * itemExistente.precio_unitario;
    } else {
        carrito.push({
            id_producto: producto.id_producto,
            nombre: producto.nombre,
            cantidad: cantidad,
            precio_unitario: parseFloat(producto.precio_venta),
            subtotal: cantidad * parseFloat(producto.precio_venta)
        });
    }

    renderizarCarrito();
    select.value = "";
    document.getElementById("inputCantidadProducto").value = 1;
}

function renderizarCarrito() {
    const tbody = document.getElementById("tablaCarrito");
    const lblTotal = document.getElementById("lblTotalCarrito");
    
    if (carrito.length === 0) {
        tbody.innerHTML = `<tr><td colspan="5" class="text-center text-muted py-3">El carrito está vacío. Agrega productos arriba.</td></tr>`;
        lblTotal.textContent = "0.00";
        return;
    }

    let total = 0;
    tbody.innerHTML = carrito.map((item, index) => {
        total += item.subtotal;
        return `
            <tr>
                <td class="ps-3">${item.nombre}</td>
                <td class="text-center">${item.cantidad}</td>
                <td class="text-end">$${item.precio_unitario.toFixed(2)}</td>
                <td class="text-end fw-bold">$${item.subtotal.toFixed(2)}</td>
                <td class="text-center pe-3">
                    <button class="btn btn-sm btn-outline-danger" onclick="quitarDelCarrito(${index})"><i class="fa-solid fa-xmark"></i></button>
                </td>
            </tr>
        `;
    }).join('');
    
    lblTotal.textContent = total.toFixed(2);
}

function quitarDelCarrito(index) {
    carrito.splice(index, 1);
    renderizarCarrito();
}

async function guardarNuevoPedido() {
    const id_cliente = document.getElementById("selectNuevoCliente").value;
    const id_repartidor = document.getElementById("selectNuevoRepartidor").value;
    const forma_pago = document.getElementById("selectFormaPago").value;

    if (!id_cliente) {
        alert("Debes seleccionar un cliente.");
        return;
    }
    if (carrito.length === 0) {
        alert("Debes agregar al menos un producto al pedido.");
        return;
    }

    const payload = {
        id_cliente: id_cliente,
        id_repartidor: id_repartidor === "NULL" ? null : id_repartidor,
        forma_pago: forma_pago,
        productos: carrito
    };

    try {
        const respuesta = await fetch('guardar_pedido.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        const data = await respuesta.json();
        if (data.exito) {
            bootstrap.Modal.getInstance(document.getElementById('modalNuevoPedido')).hide();
            cargarPedidos(); 
        } else {
            alert("Error: " + data.mensaje);
        }
    } catch (error) {
        alert("Error de conexión al guardar el pedido.");
    }
}

// ================= LÓGICA DE DETALLE Y ESTADO =================

async function verDetalle(id_pedido) {
    const pedido = pedidosGlobal.find(p => p.id_pedido === id_pedido);
    if (!pedido) return;

    document.getElementById("lblDetalleFolio").textContent = `#${pedido.id_pedido}`;
    document.getElementById("lblDetalleCliente").textContent = pedido.cliente;
    document.getElementById("lblDetalleRepartidor").textContent = pedido.repartidor;
    document.getElementById("lblDetalleFecha").textContent = pedido.fecha_registro;
    document.getElementById("lblDetalleTotal").textContent = `$${parseFloat(pedido.total).toFixed(2)}`;
    
    const badge = document.getElementById("lblDetalleEstado");
    badge.textContent = pedido.estado;
    badge.className = 'badge ' + obtenerClaseEstado(pedido.estado);

    document.getElementById("lblDetalleDireccion").textContent = 'Cargando...';
    document.getElementById("lblDetallePago").textContent = 'Cargando...';
    document.getElementById("tablaDetalleProductos").innerHTML = `<tr><td colspan="4" class="text-center text-muted">Cargando productos...</td></tr>`;

    try {
        const respuesta = await fetch(`detalle_pedido.php?id=${id_pedido}`);
        const data = await respuesta.json();
        
        if (data.exito) {
            document.getElementById("lblDetalleDireccion").textContent = data.direccion || 'Sin dirección registrada';
            
            let pagoMostrado = data.forma_pago || pedido.forma_pago || 'No especificado';
            let iconoPago = '💵';
            if (pagoMostrado === 'Tarjeta') iconoPago = '💳';
            if (pagoMostrado === 'Transferencia') iconoPago = '📱';
            
            document.getElementById("lblDetallePago").textContent = `${iconoPago} ${pagoMostrado}`;
            
            document.getElementById("tablaDetalleProductos").innerHTML = data.productos.map(p => `
                <tr>
                    <td>${p.nombre}</td>
                    <td class="text-center">${p.cantidad}</td>
                    <td class="text-end">$${parseFloat(p.precio_unitario).toFixed(2)}</td>
                    <td class="text-end fw-bold">$${parseFloat(p.subtotal).toFixed(2)}</td>
                </tr>
            `).join('');
        }
    } catch (error) {
        console.error("Error al obtener detalles:", error);
    }

    const modal = new bootstrap.Modal(document.getElementById('modalDetalle'));
    modal.show();
}

function obtenerClaseEstado(estado) {
    if (estado === 'Pendiente') return 'bg-warning text-dark';
    if (estado === 'En Ruta') return 'bg-primary';
    if (estado === 'Entregada') return 'bg-success';
    return 'bg-danger';
}

async function abrirModalEstado(id_pedido, estadoActual) {
    const pedido = pedidosGlobal.find(p => p.id_pedido === id_pedido);
    if (!pedido) return;

    document.getElementById("lblEstadoFolio").textContent = id_pedido;
    document.getElementById("inputIdPedidoEstado").value = id_pedido;
    
    const selectEstado = document.getElementById("selectNuevoEstado");
    const selectPago = document.getElementById("selectEditarFormaPago");
    const selectRep = document.getElementById("selectEditarRepartidor");

    selectEstado.value = estadoActual;
    selectPago.value = pedido.forma_pago || "Efectivo";

    const actualizarBloqueos = () => {
        const estadoSeleccionado = selectEstado.value;
        const estadosTerminales = ['Entregada', 'Cancelada', 'Rechazada', 'No entregada'];
        
        if (estadosTerminales.includes(estadoSeleccionado)) {
            selectPago.disabled = true;
            selectRep.disabled = true;
        } else {
            selectPago.disabled = false;
            selectRep.disabled = false;
            
            const opcionSeleccionada = selectRep.options[selectRep.selectedIndex];
            if (opcionSeleccionada && opcionSeleccionada.dataset.inactivo === "true") {
                selectRep.value = "NULL";
            }
        }
    };

    try {
        const respuesta = await fetch('catalogos_pedido.php');
        const data = await respuesta.json();
        if (data.exito) {
            selectRep.innerHTML = `<option value="NULL">Sin asignar (Pendiente)</option>` + 
                data.repartidores.map(r => `<option value="${r.id_repartidor}">${r.nombre_completo}</option>`).join('');
            
            if (pedido.id_repartidor) {
                let repartidorExiste = Array.from(selectRep.options).some(opt => opt.value == pedido.id_repartidor);
                if (!repartidorExiste) {
                    selectRep.innerHTML += `<option value="${pedido.id_repartidor}" data-inactivo="true">${pedido.repartidor} (Inactivo)</option>`;
                }
                selectRep.value = pedido.id_repartidor;
            } else {
                selectRep.value = "NULL";
            }
        }
    } catch (error) {
        console.error("Error al cargar repartidores:", error);
    }

    actualizarBloqueos();
    selectEstado.onchange = actualizarBloqueos;

    const modal = new bootstrap.Modal(document.getElementById('modalEstado'));
    modal.show();
}

async function guardarEstado() {
    const id_pedido = document.getElementById("inputIdPedidoEstado").value;
    const nuevo_estado = document.getElementById("selectNuevoEstado").value;
    const id_repartidor = document.getElementById("selectEditarRepartidor").value;
    const nueva_forma_pago = document.getElementById("selectEditarFormaPago").value;

    // CANDADO JS: Evita poner en ruta o entregado si no hay repartidor asignado
    if ((nuevo_estado === 'En Ruta' || nuevo_estado === 'Entregada') && id_repartidor === "NULL") {
        alert("⚠️ No puedes marcar el pedido como 'En Ruta' o 'Entregada' si no has asignado un repartidor.");
        return; 
    }

    try {
        const respuesta = await fetch('actualizar_estado.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                id_pedido: id_pedido, 
                estado: nuevo_estado,
                id_repartidor: id_repartidor === "NULL" ? null : id_repartidor,
                forma_pago: nueva_forma_pago 
            })
        });
        
        const data = await respuesta.json();
        if (data.exito) {
            bootstrap.Modal.getInstance(document.getElementById('modalEstado')).hide();
            cargarPedidos(); 
        } else {
            alert("Error: " + data.mensaje);
        }
    } catch (error) {
        alert("Error de conexión al actualizar el pedido.");
    }
}