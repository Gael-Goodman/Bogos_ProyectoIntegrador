let ventasDiaGlobal = [];
let historialCortesGlobal = [];
let estadoCorteActual = {
    corte_existente: false,
    totales: { efectivo: 0, tarjeta: 0, transferencia: 0, total_general: 0 },
    cantidades: { efectivo: 0, tarjeta: 0, transferencia: 0, total_ventas: 0 }
};

document.addEventListener("DOMContentLoaded", () => {
    // 1. Mostrar la fecha actual en el encabezado
    const fechaElement = document.getElementById("fechaActual");
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    const fechaHoyObj = new Date();
    const fechaHoyTexto = fechaHoyObj.toLocaleDateString('es-MX', opcionesFecha);
    if (fechaElement) {
        fechaElement.textContent = `Hoy: ${fechaHoyTexto.charAt(0).toUpperCase() + fechaHoyTexto.slice(1)}`;
    }

    // 2. Inicializar el campo date picker con la fecha de hoy (YYYY-MM-DD)
    const inputFecha = document.getElementById("fechaConsulta");
    const hoyISO = fechaHoyObj.toISOString().split('T')[0];
    inputFecha.value = hoyISO;

    // 3. Cargar datos iniciales
    cargarCorteFecha(hoyISO);
    cargarHistorialCortes();

    // 4. Event Listeners
    document.getElementById("btnConsultarFecha").addEventListener("click", () => {
        const fechaSeleccionada = document.getElementById("fechaConsulta").value;
        if (fechaSeleccionada) {
            cargarCorteFecha(fechaSeleccionada);
        } else {
            alert("Por favor seleccione una fecha válida.");
        }
    });

    document.getElementById("btnRealizarCorte").addEventListener("click", realizarCorteCaja);

    // Pestañas
    document.getElementById("tabVentasDia").addEventListener("click", (e) => cambiarPestaña(e, 'ventas'));
    document.getElementById("tabHistorialCortes").addEventListener("click", (e) => cambiarPestaña(e, 'historial'));

    // Cerrar sesión
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

function cambiarPestaña(e, vista) {
    e.preventDefault();
    const tabVentas = document.getElementById("tabVentasDia");
    const tabHistorial = document.getElementById("tabHistorialCortes");
    const vistaVentas = document.getElementById("vistaVentasDia");
    const vistaHistorial = document.getElementById("vistaHistorialCortes");

    // Limpiar estilos activos
    [tabVentas, tabHistorial].forEach(tab => {
        tab.classList.remove('active', 'fw-bold', 'border-bottom', 'border-3');
        tab.style.color = '#6c757d';
        tab.style.borderColor = 'transparent';
    });

    if (vista === 'ventas') {
        tabVentas.classList.add('active', 'fw-bold', 'border-bottom', 'border-3');
        tabVentas.style.color = '#d11f26';
        tabVentas.style.borderColor = '#d11f26';
        vistaVentas.classList.remove('d-none');
        vistaHistorial.classList.add('d-none');
    } else {
        tabHistorial.classList.add('active', 'fw-bold', 'border-bottom', 'border-3');
        tabHistorial.style.color = '#d11f26';
        tabHistorial.style.borderColor = '#d11f26';
        vistaHistorial.classList.remove('d-none');
        vistaVentas.classList.add('d-none');
        cargarHistorialCortes(); // Recargar historial por si hubo un nuevo cierre
    }
}

// ================= OBTENER Y RENDERIZAR VISTA DE HOY / FECHA =================

async function cargarCorteFecha(fecha) {
    const tbody = document.getElementById("tablaVentasDia");
    tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted py-4"><i class="fa-solid fa-spinner fa-spin me-2"></i>Cargando ventas del día...</td></tr>`;

    try {
        const respuesta = await fetch(`obtener_corte_actual.php?fecha=${fecha}`);
        const datos = await respuesta.json();

        if (!datos.exito) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger py-4">${datos.mensaje}</td></tr>`;
            return;
        }

        // Mostrar usuario en el encabezado
        if (datos.usuario && datos.usuario.nombre) {
            document.getElementById("nombreAdmin").innerText = datos.usuario.nombre;
        }

        ventasDiaGlobal = datos.ventas || [];
        estadoCorteActual.corte_existente = datos.corte_cerrado || false;

        // Calcular y actualizar tarjetas financieras
        calcularYRenderizarTotales(ventasDiaGlobal, datos.corte_data);

        // Renderizar tabla de ventas
        renderizarVentasDia(ventasDiaGlobal);

        // Actualizar estado del botón de cierre de caja
        const btnCorte = document.getElementById("btnRealizarCorte");
        if (estadoCorteActual.corte_existente) {
            btnCorte.innerHTML = `<i class="fa-solid fa-lock me-2"></i> Caja Cerrada`;
            btnCorte.classList.remove('btn-danger');
            btnCorte.classList.add('btn-secondary');
            btnCorte.disabled = true;
        } else {
            btnCorte.innerHTML = `<i class="fa-solid fa-lock me-2"></i> Cerrar Caja del Día`;
            btnCorte.style.backgroundColor = '#d11f26';
            btnCorte.classList.remove('btn-secondary');
            btnCorte.disabled = false;
        }

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger py-4">Error al conectar con el servidor.</td></tr>`;
    }
}

function calcularYRenderizarTotales(ventas, corteData) {
    let totEfectivo = 0, cantEfectivo = 0;
    let totTarjeta = 0, cantTarjeta = 0;
    let totTransferencia = 0, cantTransferencia = 0;
    let totalGeneral = 0;

    if (corteData) {
        // Si el corte ya fue registrado oficialmente en la BD
        totEfectivo = parseFloat(corteData.total_efectivo) || 0;
        totTarjeta = parseFloat(corteData.total_tarjeta) || 0;
        totTransferencia = parseFloat(corteData.total_transferencia) || 0;
        totalGeneral = parseFloat(corteData.total_general) || 0;
        
        cantEfectivo = ventas.filter(v => v.forma_pago === 'Efectivo').length;
        cantTarjeta = ventas.filter(v => v.forma_pago === 'Tarjeta').length;
        cantTransferencia = ventas.filter(v => v.forma_pago === 'Transferencia').length;
    } else {
        // Cálculo dinámico en tiempo real basado en ventas entregadas
        ventas.forEach(v => {
            const monto = parseFloat(v.total) || 0;
            const pago = (v.forma_pago || '').trim();

            if (pago === 'Efectivo') {
                totEfectivo += monto;
                cantEfectivo++;
            } else if (pago === 'Tarjeta') {
                totTarjeta += monto;
                cantTarjeta++;
            } else if (pago === 'Transferencia') {
                totTransferencia += monto;
                cantTransferencia++;
            }
        });
        totalGeneral = totEfectivo + totTarjeta + totTransferencia;
    }

    // Guardar estado global para enviar al servidor
    estadoCorteActual.totales = {
        efectivo: totEfectivo,
        tarjeta: totTarjeta,
        transferencia: totTransferencia,
        total_general: totalGeneral
    };
    estadoCorteActual.cantidades = {
        efectivo: cantEfectivo,
        tarjeta: cantTarjeta,
        transferencia: cantTransferencia,
        total_ventas: ventas.length
    };

    // Renderizar en las tarjetas HTML
    document.getElementById("lblEfectivo").innerText = `$${totEfectivo.toFixed(2)}`;
    document.getElementById("lblCantEfectivo").innerText = `${cantEfectivo} venta(s)`;

    document.getElementById("lblTarjeta").innerText = `$${totTarjeta.toFixed(2)}`;
    document.getElementById("lblCantTarjeta").innerText = `${cantTarjeta} venta(s)`;

    document.getElementById("lblTransferencia").innerText = `$${totTransferencia.toFixed(2)}`;
    document.getElementById("lblCantTransferencia").innerText = `${cantTransferencia} venta(s)`;

    document.getElementById("lblTotalGeneral").innerText = `$${totalGeneral.toFixed(2)}`;
    document.getElementById("lblTotalVentasCant").innerText = `${ventas.length} entregas totales`;
}

function renderizarVentasDia(ventas) {
    const tbody = document.getElementById("tablaVentasDia");
    tbody.innerHTML = "";

    if (ventas.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted py-4">No hay ventas concretadas en esta fecha.</td></tr>`;
        return;
    }

    ventas.forEach(v => {
        let iconoPago = '💵';
        if (v.forma_pago === 'Tarjeta') iconoPago = '💳';
        if (v.forma_pago === 'Transferencia') iconoPago = '📱';

        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td class="ps-4 fw-bold text-dark">#${v.id_venta}</td>
            <td><span class="badge bg-light text-dark border">Pedido #${v.id_pedido}</span></td>
            <td>${v.cliente}</td>
            <td><span class="fw-semibold">${iconoPago} ${v.forma_pago || 'No esp.'}</span></td>
            <td><small class="text-muted">${v.fecha_venta || v.hora || '-'}</small></td>
            <td class="text-end pe-4 fw-bold text-success">$${parseFloat(v.total).toFixed(2)}</td>
        `;
        tbody.appendChild(tr);
    });
}

// ================= HISTORIAL DE CORTES CERRADOS =================

async function cargarHistorialCortes() {
    const tbody = document.getElementById("tablaHistorialCortes");
    
    try {
        const respuesta = await fetch('obtener_historial_cortes.php');
        const datos = await respuesta.json();

        if (!datos.exito) {
            tbody.innerHTML = `<tr><td colspan="7" class="text-center text-danger py-4">${datos.mensaje}</td></tr>`;
            return;
        }

        historialCortesGlobal = datos.cortes || [];
        renderizarHistorialCortes(historialCortesGlobal);

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-danger py-4">Error al cargar historial de cortes.</td></tr>`;
    }
}

function renderizarHistorialCortes(cortes) {
    const tbody = document.getElementById("tablaHistorialCortes");
    tbody.innerHTML = "";

    if (cortes.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-muted py-4">No se han registrado cierres de caja aún.</td></tr>`;
        return;
    }

    cortes.forEach(c => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td class="ps-4 fw-bold text-dark">#${c.id_corte}</td>
            <td class="fw-semibold">${c.fecha_corte}</td>
            <td class="text-success">$${parseFloat(c.total_efectivo).toFixed(2)}</td>
            <td class="text-primary">$${parseFloat(c.total_tarjeta).toFixed(2)}</td>
            <td class="text-info">$${parseFloat(c.total_transferencia).toFixed(2)}</td>
            <td class="fw-bold text-dark">$${parseFloat(c.total_general).toFixed(2)}</td>
            <td><small class="text-muted">${c.usuario_cierre || 'Administrador'}</small></td>
        `;
        tbody.appendChild(tr);
    });
}

// ================= ACCIÓN: CERRA CAJA / GUARDAR CORTE =================

async function realizarCorteCaja() {
    const fechaSeleccionada = document.getElementById("fechaConsulta").value;
    
    if (estadoCorteActual.corte_existente) {
        alert("El corte para esta fecha ya fue cerrado previamente.");
        return;
    }

    if (estadoCorteActual.totales.total_general <= 0) {
        if (!confirm("El total vendido en la fecha seleccionada es $0.00. ¿Deseas realizar el cierre de caja de todos modos?")) {
            return;
        }
    } else {
        const mensajeConfirm = `¿Confirmas el cierre de caja para el día ${fechaSeleccionada}?\n\n` +
            `• Efectivo: $${estadoCorteActual.totales.efectivo.toFixed(2)}\n` +
            `• Tarjeta: $${estadoCorteActual.totales.tarjeta.toFixed(2)}\n` +
            `• Transferencia: $${estadoCorteActual.totales.transferencia.toFixed(2)}\n` +
            `-----------------------------------\n` +
            `TOTAL CORTE: $${estadoCorteActual.totales.total_general.toFixed(2)}`;

        if (!confirm(mensajeConfirm)) return;
    }

    const payload = {
        fecha: fechaSeleccionada,
        total_efectivo: estadoCorteActual.totales.efectivo,
        total_tarjeta: estadoCorteActual.totales.tarjeta,
        total_transferencia: estadoCorteActual.totales.transferencia,
        total_general: estadoCorteActual.totales.total_general,
        total_ventas: estadoCorteActual.cantidades.total_ventas
    };

    try {
        const respuesta = await fetch('guardar_corte.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const resultado = await respuesta.json();

        if (resultado.exito) {
            alert("¡Cierre de caja registrado exitosamente!");
            cargarCorteFecha(fechaSeleccionada);
            cargarHistorialCortes();
        } else {
            alert("Error al realizar el corte: " + resultado.mensaje);
        }
    } catch (error) {
        alert("Error de conexión al guardar el corte de caja.");
    }
}