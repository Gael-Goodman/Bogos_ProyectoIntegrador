let modalFacturaCFDI;

document.addEventListener("DOMContentLoaded", () => {
    // 1. Configurar fecha en el Header
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    let fecha = new Date().toLocaleDateString('es-MX', opcionesFecha);
    document.getElementById("fechaActual").innerText = "Hoy: " + fecha.charAt(0).toUpperCase() + fecha.slice(1);

    modalFacturaCFDI = new bootstrap.Modal(document.getElementById('modalFacturaCFDI'));

    // 2. Iniciar cargando la primera pestaña
    cargarVentasPendientes();

    // 3. Eventos de Pestañas
    document.getElementById("tabPendientes").addEventListener("click", (e) => cambiarPestaña(e, 'pendientes'));
    document.getElementById("tabEmitidas").addEventListener("click", (e) => cambiarPestaña(e, 'emitidas'));

    // 4. Evento Timbrar Factura
    document.getElementById("btnTimbrarFactura").addEventListener("click", generarFacturaOFICIAL);

    // 5. Cerrar sesión
    document.getElementById("btnCerrarSesion").addEventListener("click", async (e) => {
        e.preventDefault();
        if (confirm("¿Estás seguro de que deseas cerrar sesión?")) {
            await fetch('../config/logout.php');
            window.location.href = '../Inicio/index.html';
        }
    });
});

// ================= PESTAÑAS =================

function cambiarPestaña(e, pestaña) {
    e.preventDefault();
    const tabPendientes = document.getElementById("tabPendientes");
    const tabEmitidas = document.getElementById("tabEmitidas");
    
    [tabPendientes, tabEmitidas].forEach(tab => {
        tab.classList.remove('active', 'fw-bold', 'border-bottom', 'border-3');
        tab.style.color = '#6c757d';
        tab.style.borderColor = 'transparent';
    });

    e.target.classList.add('active', 'fw-bold', 'border-bottom', 'border-3');
    e.target.style.color = '#d11f26';
    e.target.style.borderColor = '#d11f26';

    if (pestaña === 'pendientes') {
        document.getElementById("vistaPendientes").classList.remove('d-none');
        document.getElementById("vistaEmitidas").classList.add('d-none');
        cargarVentasPendientes();
    } else {
        document.getElementById("vistaPendientes").classList.add('d-none');
        document.getElementById("vistaEmitidas").classList.remove('d-none');
        cargarFacturasEmitidas();
    }
}

// ================= CARGAS DE TABLAS =================

async function cargarVentasPendientes() {
    const tbody = document.getElementById("tablaPendientes");
    try {
        const respuesta = await fetch('obtener_pendientes.php');
        const datos = await respuesta.json();

        if (datos.usuario) document.getElementById("nombreAdmin").innerText = datos.usuario.nombre;

        if (!datos.exito || datos.ventas.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted py-4">No hay ventas pendientes de facturar.</td></tr>`;
            return;
        }

        tbody.innerHTML = datos.ventas.map(v => `
            <tr>
                <td class="ps-4 fw-bold">#${v.id_venta}</td>
                <td>${v.fecha_venta}</td>
                <td class="fw-semibold text-dark">
                    ${v.razon_social || v.nombre_negocio} 
                    <br><small class="text-muted">RFC: ${v.rfc || 'XAXX010101000'}</small>
                </td>
                <td>${v.forma_pago || 'Efectivo'}</td>
                <td class="text-success fw-bold">$${parseFloat(v.total).toFixed(2)}</td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm text-white" style="background-color: #0b1a45;" onclick="prepararFactura(${v.id_venta})">
                        <i class="fa-solid fa-file-invoice me-1"></i> Facturar
                    </button>
                </td>
            </tr>
        `).join('');
    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger py-4">Error de conexión.</td></tr>`;
    }
}

async function cargarFacturasEmitidas() {
    const tbody = document.getElementById("tablaEmitidas");
    try {
        const respuesta = await fetch('obtener_facturas.php');
        const datos = await respuesta.json();

        if (!datos.exito || datos.facturas.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted py-4">Aún no se han emitido facturas.</td></tr>`;
            return;
        }

        tbody.innerHTML = datos.facturas.map(f => `
            <tr>
                <td class="ps-4 fw-bold text-danger"><i class="fa-solid fa-file-pdf me-2"></i>${f.serie}-${f.folio}</td>
                <td>${f.fecha_emision}</td>
                <td class="fw-semibold text-dark">${f.razon_social || f.nombre_negocio}</td>
                <td class="text-muted">#${f.id_venta}</td>
                <td class="text-dark fw-bold">$${parseFloat(f.total).toFixed(2)}</td>
                <td class="text-center pe-4">
                    <button class="btn btn-sm btn-outline-primary" onclick="verFacturaOficial(${f.id_venta}, '${f.uuid}')">
                        <i class="fa-solid fa-eye me-1"></i> Ver CFDI
                    </button>
                </td>
            </tr>
        `).join('');
    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger py-4">Error al cargar historial.</td></tr>`;
    }
}

// ================= LÓGICA DEL MODAL CFDI =================

// Esta función reutiliza el endpoint "preparar_factura.php" (que haremos) para llenar el modal
async function llenarModalCFDI(id_venta, modo_vista) {
    try {
        const respuesta = await fetch(`preparar_factura.php?id_venta=${id_venta}`);
        const data = await respuesta.json();

        if (!data.exito) {
            alert(data.mensaje);
            return false;
        }

        const v = data.venta;
        
        // 1. Datos Emisor (Bogos)
        document.getElementById("lblEmisorRFC").innerText = v.emisor_rfc;
        document.getElementById("lblEmisorRegimen").innerText = v.emisor_regimen;
        document.getElementById("lblEmisorCP").innerText = v.emisor_cp;

        // 2. Datos Receptor (Cliente)
        document.getElementById("lblReceptorRazon").innerText = v.cliente_razon || v.cliente_negocio;
        document.getElementById("lblReceptorRFC").innerText = v.cliente_rfc || 'XAXX010101000';
        document.getElementById("lblReceptorUso").innerText = (v.cliente_uso || 'G03') + " - Gastos en general";
        document.getElementById("lblReceptorCP").innerText = v.cliente_cp || '66600';
        
        // 3. Datos de Pago
        let clavePago = v.forma_pago === 'Tarjeta' ? '04' : (v.forma_pago === 'Transferencia' ? '03' : '01');
        document.getElementById("lblFormaPago").innerText = `${clavePago} - ${v.forma_pago || 'Efectivo'}`;

        // 4. Fechas e IDs Ocultos
        document.getElementById("inputIdVenta").value = v.id_venta;
        
        let fechaEmision = modo_vista === 'PREVIA' ? new Date().toLocaleString('es-MX') : v.factura_fecha;
        document.getElementById("lblFechaEmision").innerText = fechaEmision;

        // 5. Rellenar Tabla de Conceptos y Calcular IVA
        // Matemáticas: Subtotal = Total / 1.16 | IVA = Total - Subtotal
        const subtotalGlobal = v.total / 1.16;
        const ivaGlobal = v.total - subtotalGlobal;

        document.getElementById("tablaConceptosFactura").innerHTML = data.conceptos.map(c => {
            let precioUnitarioSinIva = c.precio_unitario / 1.16;
            let importeSinIva = c.subtotal / 1.16;
            return `
                <tr>
                    <td>${c.cantidad}</td>
                    <td>80141628</td>
                    <td class="text-start">${c.nombre}</td>
                    <td>$${precioUnitarioSinIva.toFixed(2)}</td>
                    <td class="fw-bold">$${importeSinIva.toFixed(2)}</td>
                </tr>
            `;
        }).join('');

        // 6. Totales (Footer)
        document.getElementById("lblSubtotalFactura").innerText = `$${subtotalGlobal.toFixed(2)}`;
        document.getElementById("lblIvaFactura").innerText = `$${ivaGlobal.toFixed(2)}`;
        document.getElementById("lblTotalFacturaModal").innerText = `$${parseFloat(v.total).toFixed(2)}`;

        // 7. Configuración de Vista (Pre-Factura vs Factura Emitida)
        const btnTimbrar = document.getElementById("btnTimbrarFactura");
        const btnImprimir = document.getElementById("btnImprimirFactura");
        const areaSellos = document.getElementById("areaSellosSAT");
        const selloAgua = document.getElementById("selloPagado");
        const tituloModal = document.getElementById("tituloModalCFDI");

        if (modo_vista === 'PREVIA') {
            tituloModal.innerHTML = `<i class="fa-solid fa-file-invoice me-2"></i>Vista Previa de Facturación`;
            document.getElementById("lblFolioFactura").innerText = "PRE-FACTURA";
            document.getElementById("lblFolioFactura").className = "fw-bold text-danger mb-1";
            document.getElementById("lblUUID").innerText = "PENDIENTE DE ASIGNAR";
            
            btnTimbrar.classList.remove('d-none');
            btnImprimir.classList.add('d-none');
            areaSellos.classList.add('d-none');
            selloAgua.classList.add('d-none');
        } else {
            tituloModal.innerHTML = `<i class="fa-solid fa-check-circle me-2 text-success"></i>CFDI Emitido Oficialmente`;
            document.getElementById("lblFolioFactura").innerText = `${v.factura_serie}-${v.factura_folio}`;
            document.getElementById("lblFolioFactura").className = "fw-bold text-dark mb-1";
            document.getElementById("lblUUID").innerText = v.factura_uuid;
            
            document.getElementById("lblSelloEmisor").innerText = v.factura_sello_emisor;
            document.getElementById("lblSelloSAT").innerText = v.factura_sello_sat;
            
            btnTimbrar.classList.add('d-none');
            btnImprimir.classList.remove('d-none');
            areaSellos.classList.remove('d-none');
            selloAgua.classList.remove('d-none');
        }

        return true;
    } catch (error) {
        console.error(error);
        alert("Error de red al cargar datos del CFDI.");
        return false;
    }
}

// Botón de "Facturar" desde la tabla de pendientes
async function prepararFactura(id_venta) {
    const exito = await llenarModalCFDI(id_venta, 'PREVIA');
    if (exito) modalFacturaCFDI.show();
}

// Botón de "Ver CFDI" desde el historial
async function verFacturaOficial(id_venta) {
    const exito = await llenarModalCFDI(id_venta, 'FINAL');
    if (exito) modalFacturaCFDI.show();
}

// ================= ACCIÓN DE TIMBRADO (GUARDAR EN BD) =================

async function generarFacturaOFICIAL() {
    const id_venta = document.getElementById("inputIdVenta").value;
    const btn = document.getElementById("btnTimbrarFactura");
    
    btn.disabled = true;
    btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin me-2"></i>Timbrando en SAT...`;

    try {
        const respuesta = await fetch('generar_factura.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_venta: parseInt(id_venta) })
        });
        
        const data = await respuesta.json();
        if (data.exito) {
            // Refresca la tabla de atrás
            cargarVentasPendientes(); 
            
            // Re-abre el mismo modal pero ya en modo "Factura Oficial"
            await llenarModalCFDI(id_venta, 'FINAL');
            alert("¡Factura timbrada exitosamente!");
        } else {
            alert("Error: " + data.mensaje);
        }
    } catch (error) {
        alert("Error de red al generar factura.");
    } finally {
        btn.disabled = false;
        btn.innerHTML = `<i class="fa-solid fa-bell-concierge me-2"></i> Timbrar Factura Oficial`;
    }
}