document.addEventListener("DOMContentLoaded", () => {
    cargarHistorial();

    document.getElementById("btnCerrarSesion").addEventListener("click", async (e) => {
        e.preventDefault();
        if (confirm("¿Estás seguro de que deseas salir?")) {
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

async function cargarHistorial() {
    const contenedor = document.getElementById("contenedorHistorial");

    try {
        const respuesta = await fetch('obtener_historial_repartidor.php');
        const datos = await respuesta.json();

        if (datos.exito) {
            calcularTotales(datos.pedidos);
            renderizarHistorial(datos.pedidos);
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

function calcularTotales(pedidos) {
    let totalEfectivo = 0;
    let totalDigital = 0;
    let entregasExitosas = 0;

    pedidos.forEach(p => {
        // Solo sumamos el dinero si el paquete fue Entregado con éxito
        if (p.estado === 'Entregada') {
            entregasExitosas++;
            const monto = parseFloat(p.total) || 0;
            
            if (p.forma_pago === 'Efectivo') {
                totalEfectivo += monto;
            } else {
                totalDigital += monto;
            }
        }
    });

    document.getElementById("lblTotalEfectivo").textContent = `$${totalEfectivo.toFixed(2)}`;
    document.getElementById("lblTotalDigital").textContent = `$${totalDigital.toFixed(2)}`;
    document.getElementById("lblTotalEntregas").textContent = `${entregasExitosas} Entregas`;
}

function renderizarHistorial(pedidos) {
    const contenedor = document.getElementById("contenedorHistorial");
    contenedor.innerHTML = "";

    if (pedidos.length === 0) {
        contenedor.innerHTML = `
            <div class="text-center mt-5 pt-4">
                <i class="fa-solid fa-box-open fs-1 text-secondary mb-3 opacity-50"></i>
                <h5 class="text-muted fw-bold">Sin historial reciente</h5>
                <p class="text-muted small">No hay entregas o reportes registrados en los últimos días.</p>
            </div>
        `;
        return;
    }

    pedidos.forEach(p => {
        // Estilos según el estado final
        let borderClass = 'border-success';
        let badgeClass = 'bg-success';
        let iconClass = 'fa-check-double text-success';
        let textColor = 'text-success';
        
        if (p.estado !== 'Entregada') {
            borderClass = 'border-danger';
            badgeClass = 'bg-danger';
            iconClass = 'fa-triangle-exclamation text-danger';
            textColor = 'text-danger';
        }

        const card = document.createElement("div");
        card.className = `card card-historial shadow-sm mb-3 border-0 border-start border-4 ${borderClass}`;
        card.innerHTML = `
            <div class="card-body p-3">
                <div class="d-flex justify-content-between align-items-center mb-1">
                    <span class="badge bg-light text-dark border">Folio #${p.id_pedido}</span>
                    <span class="badge ${badgeClass}">${p.estado}</span>
                </div>
                <h6 class="fw-bold text-dark lh-sm mb-1">${p.cliente}</h6>
                <div class="d-flex justify-content-between align-items-end mt-2">
                    <small class="text-muted"><i class="fa-regular fa-clock me-1"></i>${p.fecha_corta}</small>
                    <span class="fw-bold ${textColor}"><i class="fa-solid ${iconClass} me-1"></i>$${parseFloat(p.total).toFixed(2)}</span>
                </div>
            </div>
        `;
        contenedor.appendChild(card);
    });
}