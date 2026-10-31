document.addEventListener("DOMContentLoaded", () => {
    // 1. Mostrar la fecha actual con formato local (ej. viernes, 23 de octubre de 2026)
    const fechaElement = document.getElementById("fechaActual");
    const opcionesFecha = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    const fechaHoy = new Date().toLocaleDateString('es-MX', opcionesFecha);
    fechaElement.textContent = `Hoy: ${fechaHoy.charAt(0).toUpperCase() + fechaHoy.slice(1)}`;

    // 2. Cargar los datos dinámicos desde el backend PHP
    cargarDatosDashboard();

    // 3. Lógica para el botón de cerrar sesión
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

// Función asíncrona para obtener y pintar los datos
async function cargarDatosDashboard() {
    try {
        const respuesta = await fetch('dashboard.php');
        const datos = await respuesta.json();

        if (datos.exito) {
            // Actualizar el nombre del administrador logueado
            document.getElementById("nombreAdmin").textContent = datos.usuario.nombre;

            // Inyectar los valores en las tarjetas de KPIs (usamos parseFloat por seguridad)
            document.getElementById("kpiVentas").textContent = `$${parseFloat(datos.kpis.ventas_dia).toFixed(2)}`;
            document.getElementById("kpiPendientes").textContent = datos.kpis.pedidos_pendientes;
            document.getElementById("kpiEntregas").textContent = datos.kpis.entregas_hoy;
            document.getElementById("kpiStockBajo").textContent = datos.kpis.stock_bajo;

            // Renderizar la tabla de pedidos recientes
            const tbody = document.getElementById("tablaPedidosRecientes");
            tbody.innerHTML = ""; // Limpiar el mensaje de "Cargando..."

            if (datos.pedidos_recientes.length === 0) {
                tbody.innerHTML = `<tr><td colspan="4" class="text-center text-muted">No hay pedidos registrados recientemente.</td></tr>`;
                return;
            }

            datos.pedidos_recientes.forEach(pedido => {
                // Asignar colores de Bootstrap según el estado exacto de tu ENUM
                let badgeClass = 'bg-secondary';
                if (pedido.estado === 'Pendiente') badgeClass = 'bg-warning text-dark';
                if (pedido.estado === 'En Ruta') badgeClass = 'bg-primary';
                if (pedido.estado === 'Entregada') badgeClass = 'bg-success';
                if (pedido.estado === 'Cancelada' || pedido.estado === 'Rechazada' || pedido.estado === 'No entregada') badgeClass = 'bg-danger';

                const tr = document.createElement("tr");
                tr.innerHTML = `
                    <td class="fw-bold">#${pedido.id_pedido}</td>
                    <td>${pedido.cliente}</td>
                    <td class="text-success fw-bold">$${parseFloat(pedido.total).toFixed(2)}</td>
                    <td><span class="badge ${badgeClass}">${pedido.estado}</span></td>
                `;
                tbody.appendChild(tr);
            });

            // Renderizar la Gráfica de Ventas
            // Renderizar la Gráfica de Ventas (Estilo Barras)
            if (datos.grafica && datos.grafica.length > 0) {
                const fechas = datos.grafica.map(item => {
                    const fechaObj = new Date(item.fecha + 'T00:00:00'); 
                    const nombreDia = fechaObj.toLocaleDateString('es-MX', { weekday: 'short' });
                    return nombreDia.charAt(0).toUpperCase() + nombreDia.slice(1); 
                });
                const totales = datos.grafica.map(item => parseFloat(item.total_dia));

                const ctx = document.getElementById('graficaVentas').getContext('2d');
                new Chart(ctx, {
                    type: 'bar', // Gráfica de barras
                    data: {
                        labels: fechas,
                        datasets: [{
                            label: 'Ventas Diarias ($)',
                            data: totales,
                            backgroundColor: '#0b1a45', // Azul marino sólido de tu marca
                            borderRadius: 4 // Bordes ligeramente redondeados
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: { display: false }
                        },
                        scales: {
                            y: {
                                beginAtZero: true,
                                ticks: {
                                    callback: function(value) { return '$' + value; }
                                }
                            }
                        }
                    }
                });
            }
        } else {
            // Si PHP detecta que no hay sesión activa, expulsa al usuario al login
            if (datos.codigo === 'NO_AUTORIZADO') {
                window.location.href = '../Inicio/index.html';
            } else {
                alert("Error al cargar el panel: " + datos.mensaje);
            }
        }
    } catch (error) {
        console.error("Error en la petición del dashboard:", error);
        document.getElementById("tablaPedidosRecientes").innerHTML = 
            `<tr><td colspan="4" class="text-center text-danger py-4">Ocurrió un error al procesar los datos. Verifica la consola.</td></tr>`;
    }
}