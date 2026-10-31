let productosGlobal = [];

document.addEventListener("DOMContentLoaded", () => {
    // 1. Mostrar la fecha actual
    const fechaElement = document.getElementById("fechaActual");
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    const fechaHoy = new Date().toLocaleDateString('es-MX', opcionesFecha);
    if (fechaElement) fechaElement.textContent = `Hoy: ${fechaHoy.charAt(0).toUpperCase() + fechaHoy.slice(1)}`;

    // 2. Cargar los productos desde PHP
    cargarProductos();

    // 3. Eventos para filtros de búsqueda
    document.getElementById("buscarProducto").addEventListener("input", aplicarFiltros);
    document.getElementById("filtroCategoria").addEventListener("change", aplicarFiltros);
    document.getElementById("filtroEstado").addEventListener("change", aplicarFiltros);

    // 4. Eventos para los modales y acciones
    document.getElementById("btnNuevoProducto").addEventListener("click", abrirModalNuevo);
    document.getElementById("btnGuardarProducto").addEventListener("click", guardarProducto);

    // 5. Lógica para cerrar sesión
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
    
    // 6. Lógica de Pestañas
    document.getElementById("tabProductos").addEventListener("click", (e) => cambiarPestaña(e, 'productos'));
    document.getElementById("tabMovimientos").addEventListener("click", (e) => cambiarPestaña(e, 'movimientos'));
    document.getElementById("tabInactivos").addEventListener("click", (e) => cambiarPestaña(e, 'inactivos'));
});

async function cargarProductos() {
    try {
        const respuesta = await fetch('inventario.php');
        const datos = await respuesta.json();

        if (datos.exito) {
            document.getElementById("nombreAdmin").textContent = datos.usuario.nombre;
            productosGlobal = datos.productos;
            aplicarFiltros();
        } else {
            if (datos.codigo === 'NO_AUTORIZADO') window.location.href = '../Inicio/index.html';
            else alert("Error: " + datos.mensaje);
        }
    } catch (error) {
        document.getElementById("tablaProductos").innerHTML = `<tr><td colspan="7" class="text-center text-danger py-4">Error al conectar con el servidor.</td></tr>`;
    }
}

function renderizarTabla(productos) {
    const tbody = document.getElementById("tablaProductos");
    tbody.innerHTML = "";

    if (productos.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-muted py-4">No se encontraron productos.</td></tr>`;
        return;
    }

    productos.forEach(prod => {
        // Lógica visual de las etiquetas de stock
        let badgeClass = '';
        let badgeText = '';
        const stockActual = parseInt(prod.stock_actual);
        const stockMinimo = parseInt(prod.stock_minimo);

        if (stockActual === 0) {
            badgeClass = 'bg-danger text-white';
            badgeText = 'Sin stock';
        } else if (stockActual <= stockMinimo) {
            badgeClass = 'bg-warning text-dark';
            badgeText = 'Stock bajo';
        } else {
            badgeClass = 'bg-success text-white';
            badgeText = 'Disponible';
        }

        const botonesAccion = `
            <button class="btn btn-sm btn-outline-secondary me-1" title="Editar Producto" onclick="abrirModalEditar(${prod.id_producto})"><i class="fa-solid fa-pen"></i></button>
            <button class="btn btn-sm btn-outline-danger" title="Desactivar Producto" onclick="eliminarProducto(${prod.id_producto})"><i class="fa-solid fa-trash"></i></button>
        `;

        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td class="ps-4 fw-bold text-muted">${prod.codigo}</td>
            <td class="fw-semibold">${prod.nombre}</td>
            <td class="text-success fw-bold">$${parseFloat(prod.precio_venta).toFixed(2)}</td>
            <td class="text-center ${stockActual === 0 ? 'text-danger fw-bold' : ''}">${stockActual}</td>
            <td class="text-center text-muted">${stockMinimo}</td>
            <td class="text-center"><span class="badge ${badgeClass} px-2 py-1">${badgeText}</span></td>
            <td class="text-center pe-4">${botonesAccion}</td>
        `;
        tbody.appendChild(tr);
    });
}

function aplicarFiltros() {
    const textoBusqueda = document.getElementById("buscarProducto").value.toLowerCase();
    const filtroCategoria = document.getElementById("filtroCategoria").value;
    const filtroEstado = document.getElementById("filtroEstado").value;

    const productosFiltrados = productosGlobal.filter(prod => {
        // 1. Filtro de Texto (busca por código o nombre)
        const coincideTexto = prod.codigo.toLowerCase().includes(textoBusqueda) || prod.nombre.toLowerCase().includes(textoBusqueda);
        
        // 2. Filtro de Categoría
        const coincideCategoria = filtroCategoria === 'todas' || prod.categoria === filtroCategoria;

        // 3. Filtro de Estado
        const stockActual = parseInt(prod.stock_actual);
        const stockMinimo = parseInt(prod.stock_minimo);
        let estadoProducto = 'disponible';
        
        if (stockActual === 0) estadoProducto = 'sin_stock';
        else if (stockActual <= stockMinimo) estadoProducto = 'bajo';

        const coincideEstado = filtroEstado === 'todos' || estadoProducto === filtroEstado;
        
        return coincideTexto && coincideCategoria && coincideEstado;
    });

    renderizarTabla(productosFiltrados);
}

// ================= LÓGICA DE FORMULARIO (NUEVO Y EDITAR) =================

function abrirModalNuevo() {
    document.getElementById("formProducto").reset();
    document.getElementById("inputIdProducto").value = "";
    document.getElementById("tituloModalProducto").textContent = "Nuevo Producto";
    
    const modal = new bootstrap.Modal(document.getElementById('modalProducto'));
    modal.show();
}

function abrirModalEditar(id_producto) {
    const prod = productosGlobal.find(p => p.id_producto === id_producto);
    if (!prod) return;

    document.getElementById("inputIdProducto").value = prod.id_producto;
    document.getElementById("inputCodigo").value = prod.codigo;
    document.getElementById("selectCategoria").value = prod.categoria;
    document.getElementById("inputNombre").value = prod.nombre;
    document.getElementById("inputPrecio").value = prod.precio_venta;
    document.getElementById("inputStockActual").value = prod.stock_actual;
    document.getElementById("inputStockMinimo").value = prod.stock_minimo;

    document.getElementById("tituloModalProducto").textContent = "Editar Producto";
    
    const modal = new bootstrap.Modal(document.getElementById('modalProducto'));
    modal.show();
}

async function guardarProducto() {
    const id_producto = document.getElementById("inputIdProducto").value;
    const payload = {
        id_producto: id_producto ? id_producto : null,
        codigo: document.getElementById("inputCodigo").value.trim(),
        categoria: document.getElementById("selectCategoria").value,
        nombre: document.getElementById("inputNombre").value.trim(),
        precio_venta: document.getElementById("inputPrecio").value,
        stock_actual: document.getElementById("inputStockActual").value,
        stock_minimo: document.getElementById("inputStockMinimo").value
    };

    if (!payload.codigo || !payload.nombre || payload.precio_venta === "" || payload.stock_actual === "" || payload.stock_minimo === "") {
        alert("Por favor, completa todos los campos del producto.");
        return;
    }

    try {
        const respuesta = await fetch('guardar_producto.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        const data = await respuesta.json();
        if (data.exito) {
            bootstrap.Modal.getInstance(document.getElementById('modalProducto')).hide();
            cargarProductos(); // Recargar la tabla con los datos actualizados
        } else {
            alert("Error: " + data.mensaje);
        }
    } catch (error) {
        alert("Error de conexión al guardar el producto.");
    }
}

async function eliminarProducto(id_producto) {
    if (confirm(`¿Estás seguro de que deseas desactivar este producto? No se eliminará del historial de ventas, pero ya no aparecerá disponible para nuevos pedidos.`)) {
        try {
            const respuesta = await fetch('eliminar_producto.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id_producto: id_producto })
            });
            
            const data = await respuesta.json();
            if (data.exito) {
                cargarProductos(); // Recargar la tabla
            } else {
                alert("Error: " + data.mensaje);
            }
        } catch (error) {
            alert("Error de conexión al desactivar el producto.");
        }
    }
}

// ================= LÓGICA DE PESTAÑAS Y MOVIMIENTOS =================

function cambiarPestaña(e, pestaña) {
    e.preventDefault();
    const tabs = [document.getElementById("tabProductos"), document.getElementById("tabMovimientos"), document.getElementById("tabInactivos")];
    const vistas = {
        productos: document.getElementById("vistaProductos"),
        movimientos: document.getElementById("vistaMovimientos"),
        inactivos: document.getElementById("vistaInactivos")
    };

    tabs.forEach(tab => {
        tab.classList.remove('active', 'fw-bold', 'border-bottom', 'border-3');
        tab.style.color = '#6c757d';
        tab.style.borderColor = 'transparent';
    });

    e.target.classList.add('active', 'fw-bold', 'border-bottom', 'border-3');
    e.target.style.color = '#d11f26';
    e.target.style.borderColor = '#d11f26';

    Object.values(vistas).forEach(v => v.classList.add('d-none'));
    vistas[pestaña].classList.remove('d-none');

    if (pestaña === 'movimientos') cargarMovimientos();
    if (pestaña === 'inactivos') cargarInactivos();
}

async function cargarMovimientos() {
    try {
        const respuesta = await fetch('obtener_movimientos.php');
        const datos = await respuesta.json();
        
        const tbody = document.getElementById("tablaMovimientos");
        tbody.innerHTML = "";

        if (!datos.exito || datos.movimientos.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted py-4">No hay movimientos registrados.</td></tr>`;
            return;
        }

        datos.movimientos.forEach(mov => {
            const esEntrada = mov.tipo === 'Cancelacion' || mov.cantidad > 0;
            const badgeClass = esEntrada ? 'bg-success' : 'bg-danger';
            const signo = esEntrada && mov.cantidad > 0 ? '+' : '';

            const tr = document.createElement("tr");
            tr.innerHTML = `
                <td class="ps-4 text-muted small">${mov.fecha_formateada}</td>
                <td class="fw-semibold">${mov.producto_nombre}</td>
                <td><span class="badge ${badgeClass} bg-opacity-75">${mov.tipo}</span></td>
                <td class="text-center fw-bold ${esEntrada ? 'text-success' : 'text-danger'}">${signo}${mov.cantidad}</td>
                <td class="text-center fw-bold text-dark">${mov.stock_resultante}</td>
                <td class="text-muted small">${mov.motivo}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        document.getElementById("tablaMovimientos").innerHTML = `<tr><td colspan="6" class="text-center text-danger py-4">Error al cargar historial.</td></tr>`;
    }
}

async function cargarInactivos() {
    try {
        const respuesta = await fetch('obtener_inactivos.php');
        const datos = await respuesta.json();
        const tbody = document.getElementById("tablaInactivos");
        tbody.innerHTML = "";

        if (!datos.exito || datos.productos.length === 0) {
            tbody.innerHTML = `<tr><td colspan="4" class="text-center text-muted py-4">No hay productos en la papelera.</td></tr>`;
            return;
        }

        datos.productos.forEach(prod => {
            const tr = document.createElement("tr");
            tr.innerHTML = `
                <td class="ps-4 fw-bold text-muted">${prod.codigo}</td>
                <td class="text-decoration-line-through text-muted">${prod.nombre}</td>
                <td>${prod.categoria}</td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm btn-success fw-bold" onclick="reactivarProducto(${prod.id_producto})">
                        <i class="fa-solid fa-rotate-left me-1"></i> Reactivar
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        console.error("Error al cargar inactivos");
    }
}

async function reactivarProducto(id_producto) {
    if (confirm("¿Deseas restaurar este producto al catálogo activo?")) {
        try {
            const respuesta = await fetch('reactivar_producto.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id_producto: id_producto })
            });
            const data = await respuesta.json();
            if (data.exito) {
                cargarInactivos();
                cargarProductos(); // Actualiza el arreglo global
            }
        } catch (error) {
            alert("Error de conexión.");
        }
    }
}