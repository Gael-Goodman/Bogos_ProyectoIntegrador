-- =====================================================================
--  BASE DE DATOS: botanas_bogos  (VERSIÓN 3.1 - DATOS PARA LA EXPOSICIÓN)
--  Proyecto Integrador 1 - Equipo 9
--
--  La ESTRUCTURA es idéntica a la versión 3.0 (no cambia ninguna tabla).
--  Lo que cambia son los DATOS DE PRUEBA:
--   - La operación arranca el domingo 8 de noviembre de 2026 y hay
--     movimiento todos los días, con la mayor carga del 16 al 18.
--   - El script trae datos hasta el viernes 20, pero al ejecutarse SOLO
--     deja lo que ya "ocurrió" a esa hora: lo que tenía entrega más tarde
--     queda como pedido Pendiente / En Ruta y lo que aún no se levantaba
--     no se carga. Así nunca verás ventas con fecha futura.
--   - Todos los días anteriores a hoy quedan con su corte de caja cerrado;
--     el día de HOY queda abierto para cerrarlo en vivo.
--
--  >>> EJECÚTALO EL MISMO DÍA DE LA EXPOSICIÓN (antes de presentar) <<<
--  para que el día de hoy tenga ventas, pedidos en ruta y pendientes.
--  OJO: borra y vuelve a crear la base de datos completa.
--
--  Requiere MySQL 8.0.16 o superior (CHECK y funciones de ventana).
--  Contraseñas en texto plano SOLO para pruebas locales.
--  Se ejecuta completo, de principio a fin, sin pasos extra.
-- =====================================================================

DROP DATABASE IF EXISTS botanas_bogos;
CREATE DATABASE IF NOT EXISTS botanas_bogos
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE botanas_bogos;

-- =====================================================================
--  1. ESTRUCTURA
-- =====================================================================

-- usuarios: cuentas de acceso internas (solo Administrador y Repartidor)
CREATE TABLE usuarios (
  id_usuario       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre_completo  VARCHAR(100) NOT NULL,
  usuario          VARCHAR(30)  NOT NULL,
  contrasena_hash  VARCHAR(255) NOT NULL, -- Se mantiene el nombre, pero guarda texto plano
  rol              ENUM('Administrador','Repartidor') NOT NULL,
  activo           TINYINT(1)   NOT NULL DEFAULT 1,
  fecha_creacion   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uq_usuarios_usuario (usuario)
) ENGINE=InnoDB;

-- repartidores: perfil logístico del usuario
CREATE TABLE repartidores (
  id_repartidor  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario     INT UNSIGNED NOT NULL,
  telefono       VARCHAR(20)  NULL,
  vehiculo       VARCHAR(100) NULL,
  placas         VARCHAR(20)  NULL,
  activo         TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id_repartidor),
  UNIQUE KEY uq_repartidores_usuario (id_usuario),
  CONSTRAINT fk_repartidores_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
) ENGINE=InnoDB;

-- clientes: directorio interno de tienditas/sucursales (con datos fiscales CFDI 4.0)
CREATE TABLE clientes (
  id_cliente            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre_negocio        VARCHAR(100) NOT NULL,
  nombre_contacto       VARCHAR(100) NULL,
  telefono              VARCHAR(20)  NULL,
  rfc                   VARCHAR(13)  NULL,
  razon_social          VARCHAR(150) NULL,
  codigo_postal_fiscal  VARCHAR(5)   NULL,
  regimen_fiscal        VARCHAR(3)   NULL,
  uso_cfdi              VARCHAR(3)   NULL,
  correo_facturacion    VARCHAR(150) NULL,
  direccion             VARCHAR(255) NOT NULL,
  referencias           VARCHAR(255) NULL,
  latitud               DECIMAL(10,7) NULL,
  longitud              DECIMAL(10,7) NULL,
  activo                TINYINT(1)   NOT NULL DEFAULT 1,
  fecha_registro        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_cliente),
  KEY idx_clientes_nombre (nombre_negocio)
) ENGINE=InnoDB;

-- empresa_emisor: configuración fiscal de la empresa que emite facturas
CREATE TABLE empresa_emisor (
  id_empresa       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  rfc              VARCHAR(13)  NOT NULL,
  razon_social     VARCHAR(150) NOT NULL,
  regimen_fiscal   VARCHAR(3)   NOT NULL,
  codigo_postal    VARCHAR(5)   NOT NULL,
  serie_factura    VARCHAR(5)   DEFAULT 'F',
  folio_siguiente  INT UNSIGNED DEFAULT 1,
  logo_url         VARCHAR(255) NULL,
  PRIMARY KEY (id_empresa)
) ENGINE=InnoDB;

-- productos: catálogo de botanas
CREATE TABLE productos (
  id_producto      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo           VARCHAR(20)  NOT NULL,
  categoria        VARCHAR(50)  NULL,
  nombre           VARCHAR(100) NOT NULL,
  descripcion      VARCHAR(255) NULL,
  precio_unitario  DECIMAL(10,2) NOT NULL,
  stock_actual     INT NOT NULL DEFAULT 0,
  stock_minimo     INT NOT NULL DEFAULT 10,
  activo           TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id_producto),
  UNIQUE KEY uq_productos_codigo (codigo),
  CONSTRAINT chk_productos_precio CHECK (precio_unitario >= 0),
  CONSTRAINT chk_productos_stock  CHECK (stock_actual >= 0),
  CONSTRAINT chk_productos_minimo CHECK (stock_minimo >= 0)
) ENGINE=InnoDB;

-- pedidos: cabecera de las órdenes de entrega
CREATE TABLE pedidos (
  id_pedido            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente           INT UNSIGNED NOT NULL,
  id_repartidor        INT UNSIGNED NULL,
  id_usuario_registro  INT UNSIGNED NOT NULL,
  fecha_registro       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_programada     DATE NULL,
  urgencia             ENUM('Baja','Media','Alta') NOT NULL DEFAULT 'Media',
  estado               ENUM('Pendiente','En Ruta','Entregada','No entregada','Rechazada','Cancelada') NOT NULL DEFAULT 'Pendiente',
  total                DECIMAL(12,2) NOT NULL DEFAULT 0,
  forma_pago           ENUM('Efectivo','Tarjeta','Transferencia') NOT NULL DEFAULT 'Efectivo',
  observaciones        VARCHAR(255) NULL,
  motivo_no_entrega    VARCHAR(255) NULL,
  fecha_entrega        DATETIME NULL,
  fecha_actualizacion  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pedido),
  KEY idx_pedidos_cliente (id_cliente),
  KEY idx_pedidos_repartidor_estado (id_repartidor, estado),
  KEY idx_pedidos_estado (estado),
  CONSTRAINT fk_pedidos_cliente    FOREIGN KEY (id_cliente)          REFERENCES clientes (id_cliente),
  CONSTRAINT fk_pedidos_repartidor FOREIGN KEY (id_repartidor)       REFERENCES repartidores (id_repartidor),
  CONSTRAINT fk_pedidos_usuario    FOREIGN KEY (id_usuario_registro) REFERENCES usuarios (id_usuario)
) ENGINE=InnoDB;

-- detalle_pedido: productos de cada pedido
CREATE TABLE detalle_pedido (
  id_detalle       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pedido        INT UNSIGNED NOT NULL,
  id_producto      INT UNSIGNED NOT NULL,
  cantidad         INT NOT NULL,
  precio_unitario  DECIMAL(10,2) NOT NULL,
  subtotal         DECIMAL(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
  PRIMARY KEY (id_detalle),
  UNIQUE KEY uq_detalle_pedido_producto (id_pedido, id_producto),
  CONSTRAINT chk_detalle_pedido_cant CHECK (cantidad > 0),
  CONSTRAINT fk_detalle_pedido_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedidos (id_pedido) ON DELETE CASCADE,
  CONSTRAINT fk_detalle_pedido_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto)
) ENGINE=InnoDB;

-- ventas: registro de ventas concretadas
CREATE TABLE ventas (
  id_venta     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pedido    INT UNSIGNED NULL,
  id_cliente   INT UNSIGNED NOT NULL,
  id_usuario   INT UNSIGNED NOT NULL,
  fecha_venta  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total        DECIMAL(12,2) NOT NULL DEFAULT 0,
  forma_pago   ENUM('Efectivo','Tarjeta','Transferencia') NOT NULL DEFAULT 'Efectivo',
  PRIMARY KEY (id_venta),
  UNIQUE KEY uq_ventas_pedido (id_pedido),
  KEY idx_ventas_fecha (fecha_venta),
  KEY idx_ventas_cliente (id_cliente),
  CONSTRAINT fk_ventas_pedido  FOREIGN KEY (id_pedido)  REFERENCES pedidos (id_pedido),
  CONSTRAINT fk_ventas_cliente FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente),
  CONSTRAINT fk_ventas_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
) ENGINE=InnoDB;

-- detalle_venta: productos de la venta
CREATE TABLE detalle_venta (
  id_detalle       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_venta         INT UNSIGNED NOT NULL,
  id_producto      INT UNSIGNED NOT NULL,
  cantidad         INT NOT NULL,
  precio_unitario  DECIMAL(10,2) NOT NULL,
  subtotal         DECIMAL(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
  PRIMARY KEY (id_detalle),
  UNIQUE KEY uq_detalle_venta_producto (id_venta, id_producto),
  CONSTRAINT chk_detalle_venta_cant CHECK (cantidad > 0),
  CONSTRAINT fk_detalle_venta_venta    FOREIGN KEY (id_venta)    REFERENCES ventas (id_venta) ON DELETE CASCADE,
  CONSTRAINT fk_detalle_venta_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto)
) ENGINE=InnoDB;

-- facturas: comprobantes de venta (con timbrado simulado SAT)
CREATE TABLE facturas (
  id_factura     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  serie          VARCHAR(5)   NULL,
  folio          VARCHAR(20)  NULL,
  uuid           VARCHAR(36)  NULL,
  sello_emisor   TEXT         NULL,
  sello_sat      TEXT         NULL,
  id_venta       INT UNSIGNED NOT NULL,
  id_cliente     INT UNSIGNED NOT NULL,
  fecha_emision  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total          DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id_factura),
  UNIQUE KEY uq_facturas_folio (folio),
  UNIQUE KEY uq_facturas_uuid (uuid),
  UNIQUE KEY uq_facturas_venta (id_venta),
  KEY idx_facturas_fecha (fecha_emision),
  CONSTRAINT fk_facturas_venta   FOREIGN KEY (id_venta)   REFERENCES ventas (id_venta),
  CONSTRAINT fk_facturas_cliente FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente)
) ENGINE=InnoDB;

-- movimientos_inventario: bitácora de stock
CREATE TABLE movimientos_inventario (
  id_movimiento     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_producto       INT UNSIGNED NOT NULL,
  tipo              ENUM('Entrada','Pedido','Venta','Cancelacion','Devolucion','Merma','Ajuste') NOT NULL,
  cantidad          INT NOT NULL,
  stock_resultante  INT NOT NULL,
  id_pedido         INT UNSIGNED NULL,
  id_venta          INT UNSIGNED NULL,
  id_usuario        INT UNSIGNED NULL,
  motivo            VARCHAR(255) NULL,
  fecha_movimiento  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_movimiento),
  KEY idx_mov_producto_fecha (id_producto, fecha_movimiento),
  CONSTRAINT fk_mov_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto),
  CONSTRAINT fk_mov_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedidos (id_pedido),
  CONSTRAINT fk_mov_venta    FOREIGN KEY (id_venta)    REFERENCES ventas (id_venta),
  CONSTRAINT fk_mov_usuario  FOREIGN KEY (id_usuario)  REFERENCES usuarios (id_usuario)
) ENGINE=InnoDB;

-- cortes_diarios: consolidado financiero (con desglose por forma de pago)
CREATE TABLE cortes_diarios (
  id_corte               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  fecha_corte            DATE NOT NULL,
  total_efectivo         DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_tarjeta          DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_transferencia    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  num_ventas             INT NOT NULL DEFAULT 0,
  total_ventas           DECIMAL(12,2) NOT NULL DEFAULT 0,
  num_facturas           INT NOT NULL DEFAULT 0,
  pedidos_entregados     INT NOT NULL DEFAULT 0,
  pedidos_no_entregados  INT NOT NULL DEFAULT 0,
  id_usuario_genera      INT UNSIGNED NULL,
  fecha_generacion       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_corte),
  UNIQUE KEY uq_corte_fecha (fecha_corte),
  CONSTRAINT fk_corte_usuario FOREIGN KEY (id_usuario_genera) REFERENCES usuarios (id_usuario)
) ENGINE=InnoDB;


-- =====================================================================
--  2. DATOS DE PRUEBA
-- =====================================================================

SET SQL_SAFE_UPDATES = 0;

-- Momento de ejecución: todo lo posterior a @ahora se descarta o queda en proceso.
-- OPCIONAL: si presentas temprano y quieres que el día ya se vea "lleno" (más ventas
-- de hoy para el corte de caja), cambia NOW() por una hora fija de ese mismo día,
-- por ejemplo:   SET @ahora = '2026-11-18 17:00:00';
SET @ahora = NOW();
SET @hoy = DATE(@ahora);
SET @hace90 = TIMESTAMPADD(MINUTE, -90, @ahora);

-- ---------------------------------------------------------------------
-- Usuarios (contraseñas en texto plano, solo desarrollo) - sin cambios
-- ---------------------------------------------------------------------
INSERT INTO usuarios (nombre_completo, usuario, contrasena_hash, rol, activo, fecha_creacion) VALUES
('Adolfo Colunga',    'admin@bogos.com',       'Admin123', 'Administrador', 1, '2026-11-08 07:00:00'),
('Angel Gonzalez',    'repartidor1@bogos.com', 'Rep123',   'Repartidor',    1, '2026-11-08 07:05:00'),
('Cristian Alday',    'repartidor2@bogos.com', 'Rep123',   'Repartidor',    1, '2026-11-08 07:05:00'),
('Mariana Treviño',   'admin2@bogos.com',      'Admin123', 'Administrador', 1, '2026-11-08 07:10:00'),
('Luis Ramírez',      'repartidor3@bogos.com', 'Rep123',   'Repartidor',    1, '2026-11-08 07:15:00'),
('Jesús Hernández',   'repartidor4@bogos.com', 'Rep123',   'Repartidor',    1, '2026-11-08 07:15:00'),
('Roberto Salinas',   'repartidor5@bogos.com', 'Rep123',   'Repartidor',    0, '2026-11-08 07:20:00');

-- ---------------------------------------------------------------------
-- Repartidores (el 5 trabajó el 8 y 9 de noviembre y después se dio de baja)
-- ---------------------------------------------------------------------
INSERT INTO repartidores (id_usuario, telefono, vehiculo, placas, activo) VALUES
(2, '8111111111', 'Nissan NP300',       'RJ-12-345', 1),
(3, '8122222222', 'Chevrolet Tornado',  'XY-98-765', 1),
(5, '8133333333', 'Ford Transit',       'TK-55-210', 1),
(6, '8144444444', 'Nissan NV200',       'MB-30-778', 1),
(7, '8155555555', 'Dodge Ram 700',      'KL-77-102', 0);

-- ---------------------------------------------------------------------
-- Datos fiscales de la empresa emisora
-- (folio_siguiente se recalcula más abajo, según las facturas generadas)
-- ---------------------------------------------------------------------
INSERT INTO empresa_emisor (rfc, razon_social, regimen_fiscal, codigo_postal, serie_factura, folio_siguiente, logo_url) VALUES
('BOGO261027XYZ', 'Distribuidora de Botanas Bogos', '612', '66600', 'F', 1, '/assets/img/logo_bogos.png');

-- ---------------------------------------------------------------------
-- Clientes (30; 14 con datos fiscales, 1 inactivo, 5 dados de alta durante la semana)
-- ---------------------------------------------------------------------
INSERT INTO clientes
  (nombre_negocio, nombre_contacto, telefono, rfc, razon_social, codigo_postal_fiscal, regimen_fiscal, uso_cfdi, correo_facturacion, direccion, referencias, latitud, longitud, activo, fecha_registro)
VALUES
('Abarrotes Garcia', 'Sr. Luis', '8123456789', 'XAXX010101000', 'PUBLICO EN GENERAL', '66600', '616', 'S01', 'facturas@agarcia.com', 'Av. Miguel Alemán 120, Centro, Apodaca, N.L.', 'Frente a la plaza principal', 25.7814000, -100.1883000, 1, '2026-11-08 07:30:00'),
('Mini Super Luna', 'Sra. Ana', '8187654321', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Hidalgo 45, Apodaca, N.L.', 'Llamar antes de ir, no tienen timbre', 25.7790000, -100.1850000, 1, '2026-11-08 07:30:00'),
('Abarrotes Liz', 'Sr. Miguel', '8112345678', 'LIEM850312AB4', 'MIGUEL LIZ ESCAMILLA', '67100', '612', 'G03', 'facturas@abarrotesliz.com', 'Av. Pablo Livas 2300, Guadalupe, N.L.', NULL, 25.6772000, -100.2560000, 1, '2026-11-08 07:30:00'),
('Tienda El Sol', 'Sra. Marta', '8198765432', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Zaragoza 310, Apodaca, N.L.', 'Portón negro junto a la farmacia', 25.7755000, -100.1902000, 1, '2026-11-08 07:30:00'),
('Abarrotes Torres', 'Sr. Jose', '8121112233', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Juárez 88, Apodaca, N.L.', 'Negocio cerrado temporalmente', 25.7801000, -100.1795000, 0, '2026-11-08 07:30:00'),
('Super Don Chuy', 'Don Chuy', '8183344556', 'SDC120815QX3', 'SUPER DON CHUY SA DE CV', '66050', '601', 'G03', 'compras@superdonchuy.com', 'Av. Sendero 450, Escobedo, N.L.', 'Esquina con Calle Roble', 25.7983000, -100.3201000, 1, '2026-11-08 07:30:00'),
('Abarrotes La Esperanza', 'Sra. Rosa', '8176655443', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Ocampo 215, San Nicolás de los Garza, N.L.', NULL, 25.7457000, -100.3021000, 1, '2026-11-08 07:30:00'),
('Miscelánea Los Pinos', 'Sr. Armando', '8112209988', 'MIPA780921KJ7', 'ARMANDO PINEDA MORALES', '66600', '612', 'G03', 'facturas@lospinos.com.mx', 'Calle Los Pinos 12, Col. Valle Verde, Apodaca, N.L.', 'Casa con reja azul', 25.7702000, -100.2011000, 1, '2026-11-08 07:30:00'),
('Tienda Doña Carmen', 'Sra. Carmen', '8117788990', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Allende 530, Guadalupe, N.L.', 'Entregar por la puerta lateral', 25.6841000, -100.2495000, 1, '2026-11-08 07:30:00'),
('Cremería y Abarrotes El Rancho', 'Sr. Ramiro', '8189012345', 'CAR190304L21', 'CREMERIA Y ABARROTES EL RANCHO SA DE CV', '67250', '601', 'G03', 'facturacion@elrancho.mx', 'Carretera a Reynosa Km 8, Juárez, N.L.', 'Entrada por el estacionamiento', 25.6499000, -100.0986000, 1, '2026-11-08 07:30:00'),
('Abarrotes Santa Fe', 'Sra. Elena', '8184433221', NULL, NULL, NULL, NULL, NULL, NULL, 'Av. Industriales 780, Santa Catarina, N.L.', NULL, 25.6738000, -100.4580000, 1, '2026-11-08 07:30:00'),
('Mini Market 24 Horas', 'Sr. Oscar', '8186677889', 'MMV200615H98', 'MINI MARKET VEINTICUATRO SA DE CV', '64000', '601', 'G03', 'pagos@minimarket24.com', 'Av. Madero 1520, Centro, Monterrey, N.L.', 'Recibe a cualquier hora', 25.6700000, -100.3099000, 1, '2026-11-08 07:30:00'),
('Tienda La Providencia', 'Sra. Lupita', '8115566778', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Morelos 77, Apodaca, N.L.', 'Preguntar por Lupita', 25.7768000, -100.1869000, 1, '2026-11-08 07:30:00'),
('Abarrotes Hermanos Cantú', 'Sr. Ernesto', '8182211009', 'CAGE700118TT5', 'ERNESTO CANTU GARZA', '66050', '612', 'G03', 'ernesto@abarrotescantu.com', 'Calle Libertad 340, Escobedo, N.L.', 'Frente al kínder', 25.8012000, -100.3155000, 1, '2026-11-08 07:30:00'),
('Super Express Nogales', 'Sr. Hugo', '8113344990', NULL, NULL, NULL, NULL, NULL, NULL, 'Av. Nogalar 600, San Nicolás de los Garza, N.L.', NULL, 25.7530000, -100.2889000, 1, '2026-11-08 07:30:00'),
('Abarrotes El Mezquital', 'Sra. Norma', '8120345566', 'MEGN820514RT2', 'NORMA MEZA GALVAN', '66640', '612', 'G03', 'norma@elmezquital.mx', 'Av. Mezquital 210, Col. Mezquital, Apodaca, N.L.', 'A un lado de la tortillería', 25.7921000, -100.2104000, 1, '2026-11-08 07:30:00'),
('Mini Super La Estrella', 'Sr. Fidel', '8134567712', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Estrella 18, Col. Nueva Apodaca, Apodaca, N.L.', NULL, 25.7689000, -100.1782000, 1, '2026-11-08 07:30:00'),
('Depósito y Abarrotes Peña', 'Sr. Rodolfo', '8145129087', 'PERR750830MN6', 'RODOLFO PEÑA RIOS', '67110', '612', 'G03', 'depositopena@correo.mx', 'Av. Eloy Cavazos 3120, Guadalupe, N.L.', 'Local con toldo rojo', 25.6695000, -100.2204000, 1, '2026-11-08 07:30:00'),
('Tiendita Don Beto', 'Don Beto', '8151902233', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Río Pesquería 402, Col. Pueblo Nuevo, Apodaca, N.L.', 'Tocar el portón', 25.7598000, -100.2217000, 1, '2026-11-08 07:30:00'),
('Super Abarrotes Linda Vista', 'Sra. Patricia', '8116703345', 'SAL150722PD8', 'SUPER ABARROTES LINDA VISTA SA DE CV', '67130', '601', 'G03', 'compras@lindavista.com.mx', 'Av. Linda Vista 955, Guadalupe, N.L.', 'Recibe mercancía hasta las 5 pm', 25.6942000, -100.2633000, 1, '2026-11-08 07:30:00'),
('Miscelánea La Güera', 'Sra. Teresa', '8129984410', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Guerrero 61, Centro, General Escobedo, N.L.', NULL, 25.7944000, -100.3288000, 1, '2026-11-08 07:30:00'),
('Abarrotes San Judas', 'Sr. Julián', '8183017765', 'GAJU690402QS1', 'JULIAN GARZA JUAREZ', '66450', '612', 'G03', 'sanjudas.abarrotes@correo.mx', 'Av. Universidad 1840, San Nicolás de los Garza, N.L.', 'Frente a la parada del camión', 25.7405000, -100.2987000, 1, '2026-11-08 07:30:00'),
('Mini Super El Roble', 'Sr. Sergio', '8110456690', NULL, NULL, NULL, NULL, NULL, NULL, 'Av. Raúl Salinas 505, Col. El Roble, Escobedo, N.L.', 'Junto a la refaccionaria', 25.8106000, -100.3340000, 1, '2026-11-08 07:30:00'),
('Tienda La Bodeguita', 'Sra. Irma', '8142238871', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle Aldama 233, Juárez, N.L.', NULL, 25.6471000, -100.0932000, 1, '2026-11-08 07:30:00'),
('Abarrotes y Carnes El Norteño', 'Sr. Gilberto', '8189905512', 'ACN180911F45', 'ABARROTES Y CARNES EL NORTEÑO SA DE CV', '64700', '601', 'G03', 'facturas@elnorteno.mx', 'Av. Chapultepec 1410, Col. Buenos Aires, Monterrey, N.L.', 'Estacionamiento por la calle lateral', 25.6612000, -100.2845000, 1, '2026-11-08 07:30:00'),
('Mini Market Cumbres', 'Srita. Daniela', '8125541298', 'MMC210305JB3', 'MINI MARKET CUMBRES SA DE CV', '64610', '601', 'G03', 'admin@marketcumbres.com', 'Av. Paseo de los Leones 2750, Cumbres, Monterrey, N.L.', 'Plaza comercial, local 4', 25.7120000, -100.3795000, 1, '2026-11-09 10:15:00'),
('Tiendita La Esquina', 'Sra. Olga', '8136620914', NULL, NULL, NULL, NULL, NULL, NULL, 'Calle 5 de Mayo 90, Santa Catarina, N.L.', 'Esquina con Calle Colón', 25.6759000, -100.4491000, 1, '2026-11-10 12:40:00'),
('Abarrotes Los Compadres', 'Sr. Raúl', '8181147720', 'LOCR800227HV9', 'RAUL LOZANO CARDENAS', '66480', '612', 'G03', 'loscompadres@correo.mx', 'Av. Las Puentes 320, San Nicolás de los Garza, N.L.', NULL, 25.7361000, -100.2710000, 1, '2026-11-11 09:20:00'),
('Super Económico Valle Soleado', 'Sr. Iván', '8154403388', NULL, NULL, NULL, NULL, NULL, NULL, 'Av. Valle Soleado 1200, Guadalupe, N.L.', 'Preguntar por el encargado', 25.6903000, -100.1898000, 1, '2026-11-12 11:05:00'),
('Cafetería Escolar Prepa 9', 'Profa. Mónica', '8127703451', NULL, NULL, NULL, NULL, NULL, NULL, 'Av. Concordia 800, Apodaca, N.L.', 'Entregar en horario de clases', 25.7733000, -100.1940000, 1, '2026-11-13 08:50:00');

-- ---------------------------------------------------------------------
-- Productos (30; stock_actual se calcula más abajo desde la bitácora)
-- ---------------------------------------------------------------------
INSERT INTO productos (codigo, categoria, nombre, descripcion, precio_unitario, stock_actual, stock_minimo, activo) VALUES
('P001', 'Frituras', 'Papas fritas 100g', 'Papas fritas sabor natural', 18.00, 0, 20, 1),
('P002', 'Frituras', 'Chicharrones 100g', 'Chicharrón de cerdo con limón', 22.00, 0, 20, 1),
('P003', 'Cacahuates', 'Cacahuates 200g', 'Cacahuate salado', 25.00, 0, 30, 1),
('P004', 'Frituras', 'Botana mixta 150g', 'Mezcla de frituras surtidas', 20.00, 0, 20, 1),
('P005', 'Frituras', 'Rueditas 100g', 'Rueditas de harina con chile', 18.00, 0, 10, 1),
('P006', 'Frituras', 'Papas con chile 100g', 'Papas fritas sabor chile y limón', 19.00, 0, 15, 1),
('P007', 'Frituras', 'Nachos con queso 120g', 'Nachos sabor queso cheddar', 21.00, 0, 15, 1),
('P008', 'Frituras', 'Churritos 90g', 'Churritos de maíz con chile', 15.00, 0, 20, 1),
('P009', 'Cacahuates', 'Cacahuates japoneses 150g', 'Cacahuate cubierto estilo japonés', 24.00, 0, 15, 1),
('P010', 'Cacahuates', 'Cacahuates enchilados 200g', 'Cacahuate con chile piquín', 26.00, 0, 20, 1),
('P011', 'Semillas', 'Pepitas saladas 100g', 'Pepita de calabaza salada', 28.00, 0, 10, 1),
('P012', 'Semillas', 'Semillas de girasol 100g', 'Semilla de girasol con sal', 17.00, 0, 15, 1),
('P013', 'Palomitas', 'Palomitas naturales 80g', 'Palomitas de maíz naturales', 14.00, 0, 15, 1),
('P014', 'Palomitas', 'Palomitas con mantequilla 80g', 'Palomitas sabor mantequilla', 15.00, 0, 15, 1),
('P015', 'Frituras', 'Platanitos 100g', 'Chips de plátano macho', 20.00, 0, 15, 1),
('P016', 'Frituras', 'Chicharrón de harina 80g', 'Chicharrón de harina con salsa', 12.00, 0, 15, 1),
('P017', 'Dulces', 'Cacahuate garapiñado 120g', 'Cacahuate cubierto de azúcar', 23.00, 0, 10, 1),
('P018', 'Mixtas', 'Mix picosito 200g', 'Mezcla de cacahuate, chile y frituras', 32.00, 0, 15, 1),
('P019', 'Frituras', 'Tostadas horneadas 150g', 'Tostadas horneadas bajas en grasa', 27.00, 0, 15, 1),
('P020', 'Frituras', 'Totopos 200g', 'Totopos de maíz (producto descontinuado)', 29.00, 0, 10, 0),
('P021', 'Frituras', 'Papas adobadas 100g', 'Papas fritas sabor adobo', 19.00, 0, 20, 1),
('P022', 'Frituras', 'Papas onduladas con queso 150g', 'Papas onduladas sabor queso', 24.00, 0, 15, 1),
('P023', 'Frituras', 'Fritos de maíz con limón 120g', 'Tiras de maíz con sal y limón', 17.00, 0, 20, 1),
('P024', 'Cacahuates', 'Cacahuate con ajo 200g', 'Cacahuate frito con ajo y sal', 27.00, 0, 15, 1),
('P025', 'Cacahuates', 'Habas enchiladas 150g', 'Habas fritas con chile', 22.00, 0, 10, 1),
('P026', 'Semillas', 'Mix de semillas 150g', 'Pepita, girasol y cacahuate', 30.00, 0, 10, 1),
('P027', 'Palomitas', 'Palomitas acarameladas 100g', 'Palomitas con caramelo', 18.00, 0, 15, 1),
('P028', 'Dulces', 'Gomitas enchiladas 150g', 'Gomitas con chamoy y chile', 21.00, 0, 15, 1),
('P029', 'Dulces', 'Tamarindo enchilado 100g', 'Dulce de tamarindo con chile', 16.00, 0, 10, 1),
('P030', 'Mixtas', 'Botana familiar surtida 400g', 'Bolsa familiar de frituras surtidas', 48.00, 0, 10, 1);

-- ---------------------------------------------------------------------
-- Pedidos planeados del 8 al 20 de noviembre (243), en orden cronológico.
-- Se cargan con su resultado final y enseguida se ajustan a la hora actual.
-- ---------------------------------------------------------------------
INSERT INTO pedidos
  (id_pedido, id_cliente, id_repartidor, id_usuario_registro, fecha_registro, fecha_programada, urgencia, estado, total, forma_pago, observaciones, motivo_no_entrega, fecha_entrega, fecha_actualizacion)
VALUES
(1, 16, 4, 1, '2026-11-08 07:59:00', '2026-11-08', 'Media', 'Entregada', 462.00, 'Transferencia', NULL, NULL, '2026-11-08 11:17:00', '2026-11-08 11:17:00'),
(2, 4, 2, 4, '2026-11-08 08:19:00', '2026-11-08', 'Media', 'Entregada', 640.00, 'Efectivo', NULL, NULL, '2026-11-08 18:39:00', '2026-11-08 18:39:00'),
(3, 22, 4, 4, '2026-11-08 08:26:00', '2026-11-08', 'Baja', 'Entregada', 1012.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-08 14:38:00', '2026-11-08 14:38:00'),
(4, 10, 1, 1, '2026-11-08 09:14:00', '2026-11-08', 'Alta', 'Entregada', 544.00, 'Transferencia', NULL, NULL, '2026-11-08 11:07:00', '2026-11-08 11:07:00'),
(5, 25, 4, 4, '2026-11-08 09:20:00', '2026-11-08', 'Media', 'Entregada', 902.00, 'Transferencia', NULL, NULL, '2026-11-08 18:30:00', '2026-11-08 18:30:00'),
(6, 2, 2, 1, '2026-11-08 09:21:00', '2026-11-08', 'Media', 'Entregada', 468.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-08 10:52:00', '2026-11-08 10:52:00'),
(7, 8, 5, 1, '2026-11-08 09:33:00', '2026-11-08', 'Baja', 'Entregada', 408.00, 'Efectivo', NULL, NULL, '2026-11-08 14:34:00', '2026-11-08 14:34:00'),
(8, 7, 4, 4, '2026-11-08 10:42:00', '2026-11-08', 'Media', 'Entregada', 492.00, 'Transferencia', 'Pago contra entrega', NULL, '2026-11-08 13:31:00', '2026-11-08 13:31:00'),
(9, 18, 3, 1, '2026-11-08 10:55:00', '2026-11-08', 'Media', 'No entregada', 608.00, 'Tarjeta', NULL, 'Negocio cerrado al llegar', NULL, '2026-11-08 18:33:00'),
(10, 5, 1, 4, '2026-11-08 16:03:00', '2026-11-09', 'Baja', 'Entregada', 408.00, 'Efectivo', NULL, NULL, '2026-11-09 15:41:00', '2026-11-09 15:41:00'),
(11, 11, 5, 1, '2026-11-08 16:29:00', '2026-11-09', 'Media', 'Entregada', 200.00, 'Efectivo', NULL, NULL, '2026-11-09 16:31:00', '2026-11-09 16:31:00'),
(12, 12, 1, 4, '2026-11-08 17:24:00', '2026-11-09', 'Media', 'Entregada', 540.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-09 13:34:00', '2026-11-09 13:34:00'),
(13, 15, 2, 1, '2026-11-08 17:28:00', '2026-11-09', 'Alta', 'Entregada', 706.00, 'Efectivo', NULL, NULL, '2026-11-09 10:42:00', '2026-11-09 10:42:00'),
(14, 24, 2, 1, '2026-11-09 07:41:00', '2026-11-09', 'Media', 'Entregada', 380.00, 'Transferencia', 'Cliente pide factura', NULL, '2026-11-09 17:32:00', '2026-11-09 17:32:00'),
(15, 7, 4, 4, '2026-11-09 08:32:00', '2026-11-09', 'Alta', 'Entregada', 957.00, 'Tarjeta', 'Llamar antes de llegar', NULL, '2026-11-09 17:11:00', '2026-11-09 17:11:00'),
(16, 8, 5, 4, '2026-11-09 08:52:00', '2026-11-09', 'Media', 'No entregada', 816.00, 'Tarjeta', 'Confirmar pedido por teléfono', 'No había quien recibiera el pedido', NULL, '2026-11-09 12:23:00'),
(17, 10, 3, 1, '2026-11-09 08:57:00', '2026-11-09', 'Alta', 'No entregada', 200.00, 'Tarjeta', 'Pago contra entrega', 'No había quien recibiera el pedido', NULL, '2026-11-09 12:44:00'),
(18, 4, 2, 1, '2026-11-09 09:06:00', '2026-11-09', 'Alta', 'Entregada', 438.00, 'Tarjeta', NULL, NULL, '2026-11-09 11:52:00', '2026-11-09 11:52:00'),
(19, 15, 4, 1, '2026-11-09 09:46:00', '2026-11-09', 'Alta', 'Entregada', 1228.00, 'Transferencia', 'Pago contra entrega', NULL, '2026-11-09 17:10:00', '2026-11-09 17:10:00'),
(20, 19, 2, 1, '2026-11-09 09:50:00', '2026-11-09', 'Media', 'No entregada', 378.00, 'Efectivo', 'Entregar por la puerta lateral', 'No se localizó el domicilio', NULL, '2026-11-09 18:38:00'),
(21, 19, 3, 1, '2026-11-09 10:12:00', '2026-11-09', 'Media', 'Entregada', 68.00, 'Efectivo', NULL, NULL, '2026-11-09 18:24:00', '2026-11-09 18:24:00'),
(22, 22, 4, 1, '2026-11-09 11:05:00', '2026-11-09', 'Alta', 'Entregada', 630.00, 'Efectivo', NULL, NULL, '2026-11-09 18:02:00', '2026-11-09 18:02:00'),
(23, 10, 5, 4, '2026-11-09 11:11:00', '2026-11-09', 'Baja', 'Entregada', 689.00, 'Transferencia', 'Pago contra entrega', NULL, '2026-11-09 13:22:00', '2026-11-09 13:22:00'),
(24, 23, 2, 4, '2026-11-09 11:47:00', '2026-11-09', 'Media', 'Entregada', 1214.00, 'Tarjeta', NULL, NULL, '2026-11-09 15:47:00', '2026-11-09 15:47:00'),
(25, 22, 2, 1, '2026-11-09 15:22:00', '2026-11-10', 'Media', 'Entregada', 860.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-10 09:36:00', '2026-11-10 09:36:00'),
(26, 10, 3, 4, '2026-11-09 15:58:00', '2026-11-10', 'Baja', 'Entregada', 1074.00, 'Transferencia', NULL, NULL, '2026-11-10 09:40:00', '2026-11-10 09:40:00'),
(27, 2, NULL, 1, '2026-11-09 16:54:00', '2026-11-10', 'Media', 'Cancelada', 600.00, 'Tarjeta', 'El cliente cerró temprano', NULL, NULL, '2026-11-09 17:43:00'),
(28, 12, 3, 1, '2026-11-09 18:50:00', '2026-11-10', 'Media', 'Entregada', 670.00, 'Tarjeta', NULL, NULL, '2026-11-10 15:39:00', '2026-11-10 15:39:00'),
(29, 12, 4, 1, '2026-11-10 08:11:00', '2026-11-10', 'Baja', 'Entregada', 114.00, 'Efectivo', NULL, NULL, '2026-11-10 09:43:00', '2026-11-10 09:43:00'),
(30, 20, 1, 1, '2026-11-10 08:27:00', '2026-11-10', 'Baja', 'Entregada', 480.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-10 11:13:00', '2026-11-10 11:13:00'),
(31, 18, 4, 1, '2026-11-10 09:16:00', '2026-11-10', 'Media', 'Entregada', 1260.00, 'Tarjeta', NULL, NULL, '2026-11-10 12:00:00', '2026-11-10 12:00:00'),
(32, 22, 4, 4, '2026-11-10 09:32:00', '2026-11-10', 'Alta', 'Entregada', 960.00, 'Efectivo', NULL, NULL, '2026-11-10 12:44:00', '2026-11-10 12:44:00'),
(33, 14, 1, 4, '2026-11-10 09:46:00', '2026-11-10', 'Alta', 'Entregada', 474.00, 'Transferencia', 'Entregar por la puerta lateral', NULL, '2026-11-10 12:49:00', '2026-11-10 12:49:00'),
(34, 25, 2, 1, '2026-11-10 10:12:00', '2026-11-10', 'Alta', 'Entregada', 270.00, 'Transferencia', 'Cliente pide factura', NULL, '2026-11-10 16:38:00', '2026-11-10 16:38:00'),
(35, 23, 2, 1, '2026-11-10 10:14:00', '2026-11-10', 'Media', 'Entregada', 455.00, 'Efectivo', NULL, NULL, '2026-11-10 16:04:00', '2026-11-10 16:04:00'),
(36, 20, 2, 1, '2026-11-10 11:01:00', '2026-11-10', 'Media', 'Entregada', 110.00, 'Tarjeta', NULL, NULL, '2026-11-10 18:33:00', '2026-11-10 18:33:00'),
(37, 6, 1, 4, '2026-11-10 11:13:00', '2026-11-10', 'Media', 'No entregada', 528.00, 'Tarjeta', 'Cliente pide factura', 'No se localizó el domicilio', NULL, '2026-11-10 16:12:00'),
(38, 20, 4, 1, '2026-11-10 11:43:00', '2026-11-10', 'Media', 'Entregada', 828.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-10 15:29:00', '2026-11-10 15:29:00'),
(39, 24, 3, 4, '2026-11-10 12:22:00', '2026-11-10', 'Media', 'Entregada', 1695.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-10 18:26:00', '2026-11-10 18:26:00'),
(40, 18, 2, 1, '2026-11-10 12:25:00', '2026-11-10', 'Alta', 'No entregada', 204.00, 'Efectivo', 'Entregar antes de las 12:00', 'El encargado no tenía autorización para recibir', NULL, '2026-11-10 17:31:00'),
(41, 3, 1, 1, '2026-11-10 16:06:00', '2026-11-11', 'Baja', 'Entregada', 452.00, 'Efectivo', NULL, NULL, '2026-11-11 17:42:00', '2026-11-11 17:42:00'),
(42, 20, 1, 1, '2026-11-10 16:12:00', '2026-11-11', 'Media', 'Entregada', 420.00, 'Transferencia', NULL, NULL, '2026-11-11 17:32:00', '2026-11-11 17:32:00'),
(43, 23, 2, 4, '2026-11-11 07:38:00', '2026-11-11', 'Baja', 'Entregada', 740.00, 'Efectivo', NULL, NULL, '2026-11-11 10:27:00', '2026-11-11 10:27:00'),
(44, 19, 3, 1, '2026-11-11 07:39:00', '2026-11-11', 'Media', 'Entregada', 702.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-11 14:57:00', '2026-11-11 14:57:00'),
(45, 15, 4, 1, '2026-11-11 07:41:00', '2026-11-11', 'Media', 'Entregada', 176.00, 'Tarjeta', NULL, NULL, '2026-11-11 13:26:00', '2026-11-11 13:26:00'),
(46, 20, 3, 1, '2026-11-11 07:43:00', '2026-11-11', 'Alta', 'Entregada', 990.00, 'Tarjeta', 'Dejar con el encargado', NULL, '2026-11-11 12:27:00', '2026-11-11 12:27:00'),
(47, 6, 3, 4, '2026-11-11 08:41:00', '2026-11-11', 'Baja', 'Entregada', 463.00, 'Tarjeta', NULL, NULL, '2026-11-11 10:35:00', '2026-11-11 10:35:00'),
(48, 16, 3, 1, '2026-11-11 08:44:00', '2026-11-11', 'Alta', 'Entregada', 526.00, 'Efectivo', NULL, NULL, '2026-11-11 17:20:00', '2026-11-11 17:20:00'),
(49, 10, 1, 1, '2026-11-11 08:52:00', '2026-11-11', 'Media', 'Entregada', 1460.00, 'Efectivo', NULL, NULL, '2026-11-11 15:00:00', '2026-11-11 15:00:00'),
(50, 14, 1, 1, '2026-11-11 09:41:00', '2026-11-11', 'Media', 'Entregada', 1202.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-11 14:48:00', '2026-11-11 14:48:00'),
(51, 6, 4, 4, '2026-11-11 09:54:00', '2026-11-11', 'Media', 'Entregada', 504.00, 'Transferencia', NULL, NULL, '2026-11-11 16:56:00', '2026-11-11 16:56:00'),
(52, 25, NULL, 1, '2026-11-11 10:35:00', '2026-11-11', 'Alta', 'Cancelada', 1088.00, 'Tarjeta', 'Pedido duplicado por error de captura', NULL, NULL, '2026-11-11 10:51:00'),
(53, 10, 4, 4, '2026-11-11 10:37:00', '2026-11-11', 'Baja', 'Entregada', 1146.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-11 13:01:00', '2026-11-11 13:01:00'),
(54, 8, 3, 1, '2026-11-11 11:03:00', '2026-11-11', 'Media', 'Entregada', 183.00, 'Efectivo', 'Pago contra entrega', NULL, '2026-11-11 17:14:00', '2026-11-11 17:14:00'),
(55, 23, 2, 1, '2026-11-11 11:34:00', '2026-11-11', 'Media', 'Entregada', 420.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-11 17:47:00', '2026-11-11 17:47:00'),
(56, 10, 4, 4, '2026-11-11 12:05:00', '2026-11-11', 'Baja', 'Entregada', 287.00, 'Efectivo', NULL, NULL, '2026-11-11 15:21:00', '2026-11-11 15:21:00'),
(57, 26, 2, 4, '2026-11-11 12:23:00', '2026-11-11', 'Media', 'Entregada', 744.00, 'Efectivo', NULL, NULL, '2026-11-11 15:17:00', '2026-11-11 15:17:00'),
(58, 14, 4, 4, '2026-11-11 15:32:00', '2026-11-12', 'Media', 'Entregada', 120.00, 'Efectivo', NULL, NULL, '2026-11-12 17:21:00', '2026-11-12 17:21:00'),
(59, 6, 3, 1, '2026-11-11 15:38:00', '2026-11-12', 'Media', 'Entregada', 643.00, 'Transferencia', 'Llamar antes de llegar', NULL, '2026-11-12 17:28:00', '2026-11-12 17:28:00'),
(60, 26, NULL, 1, '2026-11-11 15:45:00', '2026-11-12', 'Baja', 'Cancelada', 432.00, 'Efectivo', 'Pedido duplicado por error de captura', NULL, NULL, '2026-11-11 16:48:00');

INSERT INTO pedidos
  (id_pedido, id_cliente, id_repartidor, id_usuario_registro, fecha_registro, fecha_programada, urgencia, estado, total, forma_pago, observaciones, motivo_no_entrega, fecha_entrega, fecha_actualizacion)
VALUES
(61, 22, 2, 1, '2026-11-11 16:52:00', '2026-11-12', 'Alta', 'Entregada', 468.00, 'Transferencia', 'Cliente pide factura', NULL, '2026-11-12 14:46:00', '2026-11-12 14:46:00'),
(62, 3, 4, 1, '2026-11-12 07:56:00', '2026-11-12', 'Media', 'Entregada', 630.00, 'Efectivo', NULL, NULL, '2026-11-12 11:06:00', '2026-11-12 11:06:00'),
(63, 25, 4, 4, '2026-11-12 08:31:00', '2026-11-12', 'Media', 'Entregada', 1058.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-12 11:21:00', '2026-11-12 11:21:00'),
(64, 17, 4, 4, '2026-11-12 08:45:00', '2026-11-12', 'Media', 'Entregada', 422.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-12 15:00:00', '2026-11-12 15:00:00'),
(65, 27, 2, 1, '2026-11-12 08:46:00', '2026-11-12', 'Media', 'No entregada', 770.00, 'Tarjeta', NULL, 'Negocio cerrado al llegar', NULL, '2026-11-12 15:34:00'),
(66, 27, 3, 1, '2026-11-12 09:05:00', '2026-11-12', 'Alta', 'Entregada', 252.00, 'Efectivo', NULL, NULL, '2026-11-12 18:20:00', '2026-11-12 18:20:00'),
(67, 21, 1, 1, '2026-11-12 09:48:00', '2026-11-12', 'Baja', 'Entregada', 720.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-12 18:24:00', '2026-11-12 18:24:00'),
(68, 11, 2, 4, '2026-11-12 10:03:00', '2026-11-12', 'Baja', 'Entregada', 1047.00, 'Tarjeta', NULL, NULL, '2026-11-12 14:28:00', '2026-11-12 14:28:00'),
(69, 14, 4, 1, '2026-11-12 10:04:00', '2026-11-12', 'Alta', 'Entregada', 693.00, 'Tarjeta', 'Entregar antes de las 12:00', NULL, '2026-11-12 18:21:00', '2026-11-12 18:21:00'),
(70, 23, 1, 1, '2026-11-12 10:10:00', '2026-11-12', 'Alta', 'Cancelada', 474.00, 'Efectivo', 'El cliente cerró temprano', NULL, NULL, '2026-11-12 11:04:00'),
(71, 6, 3, 4, '2026-11-12 10:39:00', '2026-11-12', 'Media', 'Entregada', 876.00, 'Efectivo', NULL, NULL, '2026-11-12 17:25:00', '2026-11-12 17:25:00'),
(72, 11, 2, 1, '2026-11-12 10:43:00', '2026-11-12', 'Media', 'Entregada', 404.00, 'Efectivo', NULL, NULL, '2026-11-12 16:53:00', '2026-11-12 16:53:00'),
(73, 18, 2, 4, '2026-11-12 11:23:00', '2026-11-12', 'Media', 'Entregada', 1142.00, 'Transferencia', NULL, NULL, '2026-11-12 14:40:00', '2026-11-12 14:40:00'),
(74, 20, 2, 1, '2026-11-12 11:57:00', '2026-11-12', 'Alta', 'No entregada', 576.00, 'Tarjeta', 'Confirmar pedido por teléfono', 'No había quien recibiera el pedido', NULL, '2026-11-12 18:18:00'),
(75, 18, 4, 1, '2026-11-12 11:59:00', '2026-11-12', 'Media', 'Entregada', 560.00, 'Efectivo', NULL, NULL, '2026-11-12 14:59:00', '2026-11-12 14:59:00'),
(76, 23, 4, 4, '2026-11-12 15:13:00', '2026-11-13', 'Media', 'Entregada', 996.00, 'Transferencia', 'Entregar antes de las 12:00', NULL, '2026-11-13 10:25:00', '2026-11-13 10:25:00'),
(77, 21, 3, 1, '2026-11-12 15:15:00', '2026-11-13', 'Media', 'Entregada', 840.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-13 11:35:00', '2026-11-13 11:35:00'),
(78, 11, 3, 4, '2026-11-12 17:54:00', '2026-11-13', 'Media', 'Entregada', 320.00, 'Tarjeta', 'Dejar con el encargado', NULL, '2026-11-13 14:02:00', '2026-11-13 14:02:00'),
(79, 22, 1, 1, '2026-11-12 18:16:00', '2026-11-13', 'Media', 'Entregada', 1026.00, 'Tarjeta', 'Cliente pide factura', NULL, '2026-11-13 11:23:00', '2026-11-13 11:23:00'),
(80, 18, 4, 4, '2026-11-12 18:34:00', '2026-11-13', 'Alta', 'No entregada', 348.00, 'Efectivo', 'Confirmar pedido por teléfono', 'No se localizó el domicilio', NULL, '2026-11-13 16:55:00'),
(81, 16, 1, 1, '2026-11-12 18:52:00', '2026-11-13', 'Baja', 'Entregada', 1496.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-13 10:57:00', '2026-11-13 10:57:00'),
(82, 22, 3, 1, '2026-11-13 07:46:00', '2026-11-13', 'Media', 'Entregada', 404.00, 'Efectivo', NULL, NULL, '2026-11-13 09:49:00', '2026-11-13 09:49:00'),
(83, 15, 3, 1, '2026-11-13 07:55:00', '2026-11-13', 'Baja', 'Entregada', 102.00, 'Tarjeta', 'Entregar por la puerta lateral', NULL, '2026-11-13 17:04:00', '2026-11-13 17:04:00'),
(84, 17, 1, 1, '2026-11-13 08:47:00', '2026-11-13', 'Media', 'Entregada', 780.00, 'Transferencia', NULL, NULL, '2026-11-13 12:12:00', '2026-11-13 12:12:00'),
(85, 6, 1, 1, '2026-11-13 09:02:00', '2026-11-13', 'Baja', 'Entregada', 88.00, 'Transferencia', 'Entregar por la puerta lateral', NULL, '2026-11-13 11:24:00', '2026-11-13 11:24:00'),
(86, 1, 4, 1, '2026-11-13 09:19:00', '2026-11-13', 'Alta', 'No entregada', 670.00, 'Efectivo', 'Entregar antes de las 12:00', 'Negocio cerrado al llegar', NULL, '2026-11-13 15:31:00'),
(87, 25, 1, 4, '2026-11-13 09:41:00', '2026-11-13', 'Alta', 'Entregada', 555.00, 'Tarjeta', NULL, NULL, '2026-11-13 15:59:00', '2026-11-13 15:59:00'),
(88, 7, 2, 1, '2026-11-13 11:03:00', '2026-11-13', 'Baja', 'Entregada', 872.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-13 14:00:00', '2026-11-13 14:00:00'),
(89, 10, 2, 4, '2026-11-13 11:15:00', '2026-11-13', 'Baja', 'Entregada', 1278.00, 'Tarjeta', 'Llamar antes de llegar', NULL, '2026-11-13 18:10:00', '2026-11-13 18:10:00'),
(90, 28, 2, 1, '2026-11-13 11:30:00', '2026-11-13', 'Media', 'Entregada', 1218.00, 'Efectivo', NULL, NULL, '2026-11-13 15:04:00', '2026-11-13 15:04:00'),
(91, 13, 4, 4, '2026-11-13 11:34:00', '2026-11-13', 'Alta', 'Entregada', 1664.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-13 14:03:00', '2026-11-13 14:03:00'),
(92, 11, 1, 1, '2026-11-13 11:44:00', '2026-11-13', 'Media', 'Entregada', 180.00, 'Efectivo', NULL, NULL, '2026-11-13 16:51:00', '2026-11-13 16:51:00'),
(93, 28, 1, 4, '2026-11-13 11:47:00', '2026-11-13', 'Alta', 'Entregada', 492.00, 'Transferencia', NULL, NULL, '2026-11-13 16:54:00', '2026-11-13 16:54:00'),
(94, 12, 4, 1, '2026-11-13 12:03:00', '2026-11-13', 'Baja', 'Entregada', 419.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-13 17:33:00', '2026-11-13 17:33:00'),
(95, 14, 4, 1, '2026-11-13 12:30:00', '2026-11-13', 'Media', 'Entregada', 392.00, 'Transferencia', 'Confirmar pedido por teléfono', NULL, '2026-11-13 15:15:00', '2026-11-13 15:15:00'),
(96, 17, 3, 1, '2026-11-13 16:53:00', '2026-11-14', 'Alta', 'Entregada', 548.00, 'Efectivo', NULL, NULL, '2026-11-14 13:02:00', '2026-11-14 13:02:00'),
(97, 3, 1, 4, '2026-11-13 16:53:00', '2026-11-14', 'Media', 'Entregada', 1326.00, 'Tarjeta', NULL, NULL, '2026-11-14 14:48:00', '2026-11-14 14:48:00'),
(98, 16, 1, 4, '2026-11-14 07:48:00', '2026-11-14', 'Media', 'Entregada', 375.00, 'Tarjeta', 'Entregar antes de las 12:00', NULL, '2026-11-14 18:12:00', '2026-11-14 18:12:00'),
(99, 26, 3, 1, '2026-11-14 07:59:00', '2026-11-14', 'Alta', 'Entregada', 796.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-14 13:19:00', '2026-11-14 13:19:00'),
(100, 26, 2, 4, '2026-11-14 08:44:00', '2026-11-14', 'Alta', 'Entregada', 120.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-14 10:36:00', '2026-11-14 10:36:00'),
(101, 25, 1, 1, '2026-11-14 08:53:00', '2026-11-14', 'Media', 'Entregada', 570.00, 'Efectivo', NULL, NULL, '2026-11-14 14:32:00', '2026-11-14 14:32:00'),
(102, 20, 4, 1, '2026-11-14 08:57:00', '2026-11-14', 'Alta', 'Entregada', 978.00, 'Tarjeta', NULL, NULL, '2026-11-14 15:54:00', '2026-11-14 15:54:00'),
(103, 1, 2, 1, '2026-11-14 09:13:00', '2026-11-14', 'Baja', 'Entregada', 240.00, 'Transferencia', 'Pago contra entrega', NULL, '2026-11-14 12:34:00', '2026-11-14 12:34:00'),
(104, 6, 4, 4, '2026-11-14 09:42:00', '2026-11-14', 'Media', 'Entregada', 690.00, 'Transferencia', NULL, NULL, '2026-11-14 14:34:00', '2026-11-14 14:34:00'),
(105, 13, 4, 1, '2026-11-14 09:52:00', '2026-11-14', 'Alta', 'Entregada', 817.00, 'Transferencia', NULL, NULL, '2026-11-14 16:56:00', '2026-11-14 16:56:00'),
(106, 29, 1, 1, '2026-11-14 10:48:00', '2026-11-14', 'Baja', 'Entregada', 405.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-14 15:44:00', '2026-11-14 15:44:00'),
(107, 8, 1, 1, '2026-11-14 10:50:00', '2026-11-14', 'Media', 'Entregada', 840.00, 'Tarjeta', NULL, NULL, '2026-11-14 14:41:00', '2026-11-14 14:41:00'),
(108, 12, 4, 1, '2026-11-14 11:29:00', '2026-11-14', 'Media', 'Entregada', 1482.00, 'Transferencia', NULL, NULL, '2026-11-14 13:42:00', '2026-11-14 13:42:00'),
(109, 10, 1, 1, '2026-11-14 11:44:00', '2026-11-14', 'Baja', 'Entregada', 648.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-14 15:16:00', '2026-11-14 15:16:00'),
(110, 16, 1, 1, '2026-11-14 12:16:00', '2026-11-14', 'Media', 'Entregada', 549.00, 'Efectivo', NULL, NULL, '2026-11-14 17:58:00', '2026-11-14 17:58:00'),
(111, 28, 1, 4, '2026-11-14 12:24:00', '2026-11-14', 'Media', 'Entregada', 1314.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-14 17:55:00', '2026-11-14 17:55:00'),
(112, 15, 3, 1, '2026-11-14 15:06:00', '2026-11-15', 'Media', 'Entregada', 874.00, 'Efectivo', NULL, NULL, '2026-11-15 11:22:00', '2026-11-15 11:22:00'),
(113, 24, 1, 1, '2026-11-14 17:46:00', '2026-11-15', 'Media', 'Entregada', 504.00, 'Transferencia', 'Entregar por la puerta lateral', NULL, '2026-11-15 15:09:00', '2026-11-15 15:09:00'),
(114, 19, 3, 1, '2026-11-15 08:38:00', '2026-11-15', 'Media', 'Entregada', 1436.00, 'Efectivo', NULL, NULL, '2026-11-15 10:22:00', '2026-11-15 10:22:00'),
(115, 19, 1, 4, '2026-11-15 10:08:00', '2026-11-15', 'Media', 'Entregada', 532.00, 'Transferencia', NULL, NULL, '2026-11-15 12:54:00', '2026-11-15 12:54:00'),
(116, 25, 1, 4, '2026-11-15 10:44:00', '2026-11-15', 'Media', 'Entregada', 1034.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-15 15:40:00', '2026-11-15 15:40:00'),
(117, 8, 2, 1, '2026-11-15 11:23:00', '2026-11-15', 'Alta', 'Entregada', 384.00, 'Efectivo', NULL, NULL, '2026-11-15 14:11:00', '2026-11-15 14:11:00'),
(118, 2, 4, 4, '2026-11-15 11:43:00', '2026-11-15', 'Media', 'Entregada', 1100.00, 'Transferencia', NULL, NULL, '2026-11-15 13:59:00', '2026-11-15 13:59:00'),
(119, 30, 3, 4, '2026-11-15 11:54:00', '2026-11-15', 'Media', 'Entregada', 1555.00, 'Tarjeta', 'Pago contra entrega', NULL, '2026-11-15 17:10:00', '2026-11-15 17:10:00'),
(120, 14, 4, 1, '2026-11-15 11:56:00', '2026-11-15', 'Media', 'Entregada', 986.00, 'Transferencia', 'Dejar con el encargado', NULL, '2026-11-15 14:33:00', '2026-11-15 14:33:00');

INSERT INTO pedidos
  (id_pedido, id_cliente, id_repartidor, id_usuario_registro, fecha_registro, fecha_programada, urgencia, estado, total, forma_pago, observaciones, motivo_no_entrega, fecha_entrega, fecha_actualizacion)
VALUES
(121, 2, 3, 1, '2026-11-15 12:28:00', '2026-11-15', 'Alta', 'Entregada', 1096.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-15 16:34:00', '2026-11-15 16:34:00'),
(122, 20, 3, 1, '2026-11-15 15:21:00', '2026-11-16', 'Baja', 'Entregada', 296.00, 'Tarjeta', 'Pago contra entrega', NULL, '2026-11-16 17:23:00', '2026-11-16 17:23:00'),
(123, 21, 2, 1, '2026-11-15 15:37:00', '2026-11-16', 'Media', 'Entregada', 1128.00, 'Tarjeta', 'Dejar con el encargado', NULL, '2026-11-16 11:18:00', '2026-11-16 11:18:00'),
(124, 1, 3, 1, '2026-11-15 16:38:00', '2026-11-16', 'Baja', 'Entregada', 666.00, 'Tarjeta', 'Confirmar pedido por teléfono', NULL, '2026-11-16 14:53:00', '2026-11-16 14:53:00'),
(125, 12, 4, 1, '2026-11-15 17:29:00', '2026-11-16', 'Media', 'Entregada', 360.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-16 13:32:00', '2026-11-16 13:32:00'),
(126, 17, 3, 4, '2026-11-15 17:38:00', '2026-11-16', 'Media', 'Entregada', 880.00, 'Efectivo', NULL, NULL, '2026-11-16 13:02:00', '2026-11-16 13:02:00'),
(127, 6, 4, 1, '2026-11-15 18:30:00', '2026-11-16', 'Alta', 'Entregada', 192.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-16 11:10:00', '2026-11-16 11:10:00'),
(128, 20, 1, 1, '2026-11-16 08:08:00', '2026-11-16', 'Alta', 'Entregada', 432.00, 'Efectivo', NULL, NULL, '2026-11-16 12:54:00', '2026-11-16 12:54:00'),
(129, 29, 1, 1, '2026-11-16 08:10:00', '2026-11-16', 'Media', 'Entregada', 600.00, 'Efectivo', NULL, NULL, '2026-11-16 14:47:00', '2026-11-16 14:47:00'),
(130, 10, 3, 1, '2026-11-16 08:13:00', '2026-11-16', 'Alta', 'Entregada', 640.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-16 17:10:00', '2026-11-16 17:10:00'),
(131, 18, 4, 1, '2026-11-16 08:16:00', '2026-11-16', 'Alta', 'Entregada', 102.00, 'Efectivo', NULL, NULL, '2026-11-16 17:33:00', '2026-11-16 17:33:00'),
(132, 1, 4, 1, '2026-11-16 08:22:00', '2026-11-16', 'Media', 'Entregada', 95.00, 'Transferencia', NULL, NULL, '2026-11-16 11:07:00', '2026-11-16 11:07:00'),
(133, 1, 2, 1, '2026-11-16 08:33:00', '2026-11-16', 'Alta', 'Entregada', 702.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-16 14:28:00', '2026-11-16 14:28:00'),
(134, 21, 3, 1, '2026-11-16 08:43:00', '2026-11-16', 'Baja', 'Entregada', 576.00, 'Efectivo', NULL, NULL, '2026-11-16 13:01:00', '2026-11-16 13:01:00'),
(135, 28, 4, 4, '2026-11-16 09:12:00', '2026-11-16', 'Baja', 'Entregada', 790.00, 'Transferencia', 'Llamar antes de llegar', NULL, '2026-11-16 10:50:00', '2026-11-16 10:50:00'),
(136, 22, 3, 1, '2026-11-16 09:42:00', '2026-11-16', 'Media', 'Cancelada', 533.00, 'Transferencia', 'Cliente canceló por falta de presupuesto', NULL, NULL, '2026-11-16 11:09:00'),
(137, 24, 3, 1, '2026-11-16 10:03:00', '2026-11-16', 'Baja', 'Entregada', 826.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-16 12:43:00', '2026-11-16 12:43:00'),
(138, 20, 2, 1, '2026-11-16 10:05:00', '2026-11-16', 'Media', 'Entregada', 448.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-16 14:27:00', '2026-11-16 14:27:00'),
(139, 17, 1, 1, '2026-11-16 10:06:00', '2026-11-16', 'Media', 'Entregada', 690.00, 'Efectivo', NULL, NULL, '2026-11-16 15:01:00', '2026-11-16 15:01:00'),
(140, 15, 2, 1, '2026-11-16 10:09:00', '2026-11-16', 'Alta', 'Entregada', 770.00, 'Efectivo', NULL, NULL, '2026-11-16 13:05:00', '2026-11-16 13:05:00'),
(141, 22, 3, 1, '2026-11-16 10:11:00', '2026-11-16', 'Alta', 'Entregada', 295.00, 'Efectivo', NULL, NULL, '2026-11-16 17:04:00', '2026-11-16 17:04:00'),
(142, 30, 2, 1, '2026-11-16 10:23:00', '2026-11-16', 'Media', 'No entregada', 1100.00, 'Efectivo', NULL, 'El encargado no tenía autorización para recibir', NULL, '2026-11-16 12:14:00'),
(143, 22, 1, 4, '2026-11-16 10:25:00', '2026-11-16', 'Media', 'Entregada', 873.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-16 16:25:00', '2026-11-16 16:25:00'),
(144, 19, 2, 1, '2026-11-16 10:41:00', '2026-11-16', 'Alta', 'Entregada', 1444.00, 'Efectivo', NULL, NULL, '2026-11-16 13:27:00', '2026-11-16 13:27:00'),
(145, 24, 2, 1, '2026-11-16 12:20:00', '2026-11-16', 'Media', 'No entregada', 228.00, 'Transferencia', 'Entregar antes de las 12:00', 'No había quien recibiera el pedido', NULL, '2026-11-16 18:35:00'),
(146, 2, 1, 4, '2026-11-16 15:03:00', '2026-11-17', 'Media', 'Entregada', 370.00, 'Tarjeta', 'Entregar antes de las 12:00', NULL, '2026-11-17 11:00:00', '2026-11-17 11:00:00'),
(147, 11, 1, 4, '2026-11-16 15:16:00', '2026-11-17', 'Alta', 'Entregada', 880.00, 'Tarjeta', NULL, NULL, '2026-11-17 18:37:00', '2026-11-17 18:37:00'),
(148, 20, 2, 1, '2026-11-16 16:02:00', '2026-11-17', 'Media', 'Entregada', 1262.00, 'Efectivo', NULL, NULL, '2026-11-17 10:58:00', '2026-11-17 10:58:00'),
(149, 28, 4, 1, '2026-11-16 16:23:00', '2026-11-17', 'Baja', 'Entregada', 1260.00, 'Transferencia', NULL, NULL, '2026-11-17 13:56:00', '2026-11-17 13:56:00'),
(150, 2, 1, 1, '2026-11-16 16:44:00', '2026-11-17', 'Media', 'Entregada', 584.00, 'Transferencia', 'Confirmar pedido por teléfono', NULL, '2026-11-17 13:47:00', '2026-11-17 13:47:00'),
(151, 4, NULL, 4, '2026-11-16 17:27:00', '2026-11-17', 'Media', 'Cancelada', 728.00, 'Efectivo', 'El cliente cerró temprano', NULL, NULL, '2026-11-16 19:13:00'),
(152, 15, 3, 4, '2026-11-16 17:35:00', '2026-11-17', 'Media', 'Entregada', 204.00, 'Efectivo', NULL, NULL, '2026-11-17 15:17:00', '2026-11-17 15:17:00'),
(153, 19, 3, 1, '2026-11-16 18:23:00', '2026-11-17', 'Alta', 'Entregada', 480.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-17 17:03:00', '2026-11-17 17:03:00'),
(154, 10, 3, 4, '2026-11-17 07:30:00', '2026-11-17', 'Alta', 'Entregada', 250.00, 'Tarjeta', NULL, NULL, '2026-11-17 10:07:00', '2026-11-17 10:07:00'),
(155, 27, 1, 1, '2026-11-17 07:31:00', '2026-11-17', 'Baja', 'No entregada', 524.00, 'Transferencia', NULL, 'El encargado no tenía autorización para recibir', NULL, '2026-11-17 12:46:00'),
(156, 2, 1, 1, '2026-11-17 07:57:00', '2026-11-17', 'Media', 'Cancelada', 620.00, 'Efectivo', 'Cliente canceló por falta de presupuesto', NULL, NULL, '2026-11-17 09:19:00'),
(157, 12, 2, 1, '2026-11-17 08:12:00', '2026-11-17', 'Media', 'Entregada', 366.00, 'Efectivo', NULL, NULL, '2026-11-17 14:26:00', '2026-11-17 14:26:00'),
(158, 28, 1, 4, '2026-11-17 08:22:00', '2026-11-17', 'Media', 'Entregada', 360.00, 'Transferencia', NULL, NULL, '2026-11-17 12:10:00', '2026-11-17 12:10:00'),
(159, 16, 1, 1, '2026-11-17 08:32:00', '2026-11-17', 'Alta', 'Entregada', 552.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-17 13:26:00', '2026-11-17 13:26:00'),
(160, 14, 1, 4, '2026-11-17 09:36:00', '2026-11-17', 'Alta', 'Entregada', 1341.00, 'Transferencia', 'Dejar con el encargado', NULL, '2026-11-17 18:08:00', '2026-11-17 18:08:00'),
(161, 17, 4, 1, '2026-11-17 09:58:00', '2026-11-17', 'Baja', 'No entregada', 630.00, 'Efectivo', 'Llamar antes de llegar', 'El encargado no tenía autorización para recibir', NULL, '2026-11-17 18:33:00'),
(162, 4, 1, 1, '2026-11-17 10:12:00', '2026-11-17', 'Media', 'Entregada', 1080.00, 'Tarjeta', 'Pago contra entrega', NULL, '2026-11-17 12:25:00', '2026-11-17 12:25:00'),
(163, 18, 3, 1, '2026-11-17 10:20:00', '2026-11-17', 'Alta', 'Entregada', 895.00, 'Tarjeta', 'Confirmar pedido por teléfono', NULL, '2026-11-17 14:01:00', '2026-11-17 14:01:00'),
(164, 28, 1, 1, '2026-11-17 10:32:00', '2026-11-17', 'Baja', 'Entregada', 486.00, 'Efectivo', NULL, NULL, '2026-11-17 16:57:00', '2026-11-17 16:57:00'),
(165, 17, 1, 4, '2026-11-17 11:11:00', '2026-11-17', 'Media', 'Entregada', 1280.00, 'Transferencia', NULL, NULL, '2026-11-17 15:22:00', '2026-11-17 15:22:00'),
(166, 3, 3, 1, '2026-11-17 11:15:00', '2026-11-17', 'Media', 'Entregada', 808.00, 'Efectivo', NULL, NULL, '2026-11-17 12:50:00', '2026-11-17 12:50:00'),
(167, 27, 1, 1, '2026-11-17 11:18:00', '2026-11-17', 'Alta', 'Entregada', 126.00, 'Tarjeta', NULL, NULL, '2026-11-17 17:16:00', '2026-11-17 17:16:00'),
(168, 24, 4, 1, '2026-11-17 11:22:00', '2026-11-17', 'Alta', 'No entregada', 498.00, 'Transferencia', 'Entregar por la puerta lateral', 'Negocio cerrado al llegar', NULL, '2026-11-17 17:09:00'),
(169, 3, 2, 1, '2026-11-17 11:31:00', '2026-11-17', 'Baja', 'Rechazada', 360.00, 'Efectivo', NULL, 'Cliente no contaba con el pago completo', NULL, '2026-11-17 14:30:00'),
(170, 3, 2, 1, '2026-11-17 12:00:00', '2026-11-17', 'Baja', 'Entregada', 653.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-17 16:36:00', '2026-11-17 16:36:00'),
(171, 19, 4, 1, '2026-11-17 12:08:00', '2026-11-17', 'Baja', 'Entregada', 570.00, 'Transferencia', NULL, NULL, '2026-11-17 15:23:00', '2026-11-17 15:23:00'),
(172, 6, 4, 1, '2026-11-17 15:30:00', '2026-11-18', 'Media', 'Entregada', 108.00, 'Tarjeta', NULL, NULL, '2026-11-18 10:18:00', '2026-11-18 10:18:00'),
(173, 1, 2, 1, '2026-11-17 16:11:00', '2026-11-18', 'Media', 'Entregada', 840.00, 'Transferencia', NULL, NULL, '2026-11-18 18:34:00', '2026-11-18 18:34:00'),
(174, 4, 3, 1, '2026-11-17 17:22:00', '2026-11-18', 'Media', 'Entregada', 612.00, 'Efectivo', NULL, NULL, '2026-11-18 14:57:00', '2026-11-18 14:57:00'),
(175, 25, 2, 1, '2026-11-17 18:22:00', '2026-11-18', 'Media', 'Entregada', 200.00, 'Transferencia', NULL, NULL, '2026-11-18 18:12:00', '2026-11-18 18:12:00'),
(176, 4, 3, 1, '2026-11-17 18:33:00', '2026-11-18', 'Media', 'Entregada', 772.00, 'Tarjeta', NULL, NULL, '2026-11-18 15:53:00', '2026-11-18 15:53:00'),
(177, 29, 4, 4, '2026-11-17 18:34:00', '2026-11-18', 'Alta', 'Entregada', 929.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-18 16:18:00', '2026-11-18 16:18:00'),
(178, 25, 3, 1, '2026-11-18 07:36:00', '2026-11-18', 'Baja', 'Entregada', 528.00, 'Tarjeta', 'Entregar por la puerta lateral', NULL, '2026-11-18 09:48:00', '2026-11-18 09:48:00'),
(179, 16, 3, 4, '2026-11-18 08:01:00', '2026-11-18', 'Media', 'No entregada', 300.00, 'Tarjeta', NULL, 'No había quien recibiera el pedido', NULL, '2026-11-18 18:28:00'),
(180, 11, 2, 1, '2026-11-18 08:14:00', '2026-11-18', 'Baja', 'Entregada', 1430.00, 'Transferencia', NULL, NULL, '2026-11-18 16:11:00', '2026-11-18 16:11:00');

INSERT INTO pedidos
  (id_pedido, id_cliente, id_repartidor, id_usuario_registro, fecha_registro, fecha_programada, urgencia, estado, total, forma_pago, observaciones, motivo_no_entrega, fecha_entrega, fecha_actualizacion)
VALUES
(181, 29, 4, 1, '2026-11-18 08:18:00', '2026-11-18', 'Alta', 'Entregada', 290.00, 'Efectivo', 'Confirmar pedido por teléfono', NULL, '2026-11-18 12:17:00', '2026-11-18 12:17:00'),
(182, 13, 3, 1, '2026-11-18 08:22:00', '2026-11-18', 'Alta', 'Entregada', 1120.00, 'Tarjeta', NULL, NULL, '2026-11-18 10:16:00', '2026-11-18 10:16:00'),
(183, 13, 1, 1, '2026-11-18 08:53:00', '2026-11-18', 'Media', 'Entregada', 1030.00, 'Transferencia', 'Cliente pide factura', NULL, '2026-11-18 10:49:00', '2026-11-18 10:49:00'),
(184, 13, 4, 1, '2026-11-18 08:58:00', '2026-11-18', 'Alta', 'Entregada', 306.00, 'Efectivo', NULL, NULL, '2026-11-18 18:05:00', '2026-11-18 18:05:00'),
(185, 10, 2, 1, '2026-11-18 09:09:00', '2026-11-18', 'Baja', 'No entregada', 366.00, 'Tarjeta', NULL, 'Negocio cerrado al llegar', NULL, '2026-11-18 17:04:00'),
(186, 6, 1, 1, '2026-11-18 09:23:00', '2026-11-18', 'Alta', 'Entregada', 812.00, 'Transferencia', NULL, NULL, '2026-11-18 14:20:00', '2026-11-18 14:20:00'),
(187, 12, 4, 1, '2026-11-18 09:49:00', '2026-11-18', 'Baja', 'Entregada', 575.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-18 18:24:00', '2026-11-18 18:24:00'),
(188, 8, 2, 1, '2026-11-18 09:50:00', '2026-11-18', 'Media', 'Entregada', 867.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-18 12:21:00', '2026-11-18 12:21:00'),
(189, 26, 2, 1, '2026-11-18 10:04:00', '2026-11-18', 'Alta', 'Entregada', 728.00, 'Tarjeta', 'Confirmar pedido por teléfono', NULL, '2026-11-18 12:35:00', '2026-11-18 12:35:00'),
(190, 6, 3, 1, '2026-11-18 10:20:00', '2026-11-18', 'Alta', 'Entregada', 1242.00, 'Efectivo', 'Confirmar pedido por teléfono', NULL, '2026-11-18 17:00:00', '2026-11-18 17:00:00'),
(191, 13, 4, 4, '2026-11-18 10:20:00', '2026-11-18', 'Alta', 'Entregada', 114.00, 'Transferencia', 'Entregar antes de las 12:00', NULL, '2026-11-18 14:58:00', '2026-11-18 14:58:00'),
(192, 18, 3, 1, '2026-11-18 10:24:00', '2026-11-18', 'Alta', 'Entregada', 80.00, 'Tarjeta', 'Entregar por la puerta lateral', NULL, '2026-11-18 13:52:00', '2026-11-18 13:52:00'),
(193, 13, 4, 4, '2026-11-18 10:42:00', '2026-11-18', 'Media', 'Entregada', 564.00, 'Efectivo', NULL, NULL, '2026-11-18 13:00:00', '2026-11-18 13:00:00'),
(194, 19, 4, 1, '2026-11-18 10:49:00', '2026-11-18', 'Baja', 'Entregada', 90.00, 'Efectivo', NULL, NULL, '2026-11-18 14:08:00', '2026-11-18 14:08:00'),
(195, 6, 2, 1, '2026-11-18 11:13:00', '2026-11-18', 'Media', 'Entregada', 1094.00, 'Tarjeta', 'Dejar con el encargado', NULL, '2026-11-18 16:38:00', '2026-11-18 16:38:00'),
(196, 22, 1, 4, '2026-11-18 11:16:00', '2026-11-18', 'Alta', 'Entregada', 540.00, 'Efectivo', NULL, NULL, '2026-11-18 17:49:00', '2026-11-18 17:49:00'),
(197, 25, 2, 1, '2026-11-18 11:22:00', '2026-11-18', 'Media', 'Entregada', 1156.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-18 18:35:00', '2026-11-18 18:35:00'),
(198, 14, NULL, 1, '2026-11-18 12:19:00', '2026-11-18', 'Alta', 'Cancelada', 656.00, 'Efectivo', 'Cliente canceló por falta de presupuesto', NULL, NULL, '2026-11-18 13:15:00'),
(199, 12, 4, 4, '2026-11-18 12:28:00', '2026-11-18', 'Baja', 'Entregada', 406.00, 'Tarjeta', 'Entregar antes de las 12:00', NULL, '2026-11-18 18:06:00', '2026-11-18 18:06:00'),
(200, 12, 4, 4, '2026-11-18 15:47:00', '2026-11-19', 'Media', 'Entregada', 1298.00, 'Transferencia', 'Entregar antes de las 12:00', NULL, '2026-11-19 10:36:00', '2026-11-19 10:36:00'),
(201, 22, NULL, 1, '2026-11-18 15:54:00', '2026-11-19', 'Alta', 'Cancelada', 606.00, 'Efectivo', 'Cliente canceló por falta de presupuesto', NULL, NULL, '2026-11-18 16:39:00'),
(202, 18, 4, 4, '2026-11-18 16:07:00', '2026-11-19', 'Media', 'Entregada', 357.00, 'Transferencia', NULL, NULL, '2026-11-19 17:19:00', '2026-11-19 17:19:00'),
(203, 4, 4, 4, '2026-11-19 08:06:00', '2026-11-19', 'Media', 'Entregada', 564.00, 'Tarjeta', NULL, NULL, '2026-11-19 15:56:00', '2026-11-19 15:56:00'),
(204, 30, 3, 4, '2026-11-19 08:15:00', '2026-11-19', 'Media', 'Entregada', 696.00, 'Tarjeta', NULL, NULL, '2026-11-19 16:30:00', '2026-11-19 16:30:00'),
(205, 11, 2, 1, '2026-11-19 08:17:00', '2026-11-19', 'Alta', 'Entregada', 701.00, 'Tarjeta', NULL, NULL, '2026-11-19 10:13:00', '2026-11-19 10:13:00'),
(206, 12, 4, 1, '2026-11-19 08:23:00', '2026-11-19', 'Media', 'Entregada', 936.00, 'Efectivo', NULL, NULL, '2026-11-19 17:09:00', '2026-11-19 17:09:00'),
(207, 7, 1, 1, '2026-11-19 09:05:00', '2026-11-19', 'Media', 'Entregada', 451.00, 'Efectivo', 'Dejar con el encargado', NULL, '2026-11-19 18:17:00', '2026-11-19 18:17:00'),
(208, 11, 3, 1, '2026-11-19 09:08:00', '2026-11-19', 'Alta', 'Entregada', 510.00, 'Efectivo', NULL, NULL, '2026-11-19 14:31:00', '2026-11-19 14:31:00'),
(209, 2, 4, 1, '2026-11-19 09:15:00', '2026-11-19', 'Baja', 'Entregada', 876.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-19 15:34:00', '2026-11-19 15:34:00'),
(210, 1, 4, 1, '2026-11-19 09:18:00', '2026-11-19', 'Media', 'Entregada', 579.00, 'Efectivo', 'Entregar por la puerta lateral', NULL, '2026-11-19 17:11:00', '2026-11-19 17:11:00'),
(211, 7, 4, 1, '2026-11-19 09:48:00', '2026-11-19', 'Media', 'Entregada', 810.00, 'Transferencia', 'Confirmar pedido por teléfono', NULL, '2026-11-19 14:56:00', '2026-11-19 14:56:00'),
(212, 3, 3, 1, '2026-11-19 10:15:00', '2026-11-19', 'Alta', 'Entregada', 1648.00, 'Efectivo', NULL, NULL, '2026-11-19 16:19:00', '2026-11-19 16:19:00'),
(213, 22, 4, 1, '2026-11-19 10:26:00', '2026-11-19', 'Media', 'Entregada', 696.00, 'Transferencia', 'Cliente pide factura', NULL, '2026-11-19 15:37:00', '2026-11-19 15:37:00'),
(214, 20, 1, 1, '2026-11-19 10:35:00', '2026-11-19', 'Media', 'Entregada', 516.00, 'Efectivo', NULL, NULL, '2026-11-19 18:07:00', '2026-11-19 18:07:00'),
(215, 4, 4, 1, '2026-11-19 10:44:00', '2026-11-19', 'Baja', 'Entregada', 456.00, 'Transferencia', NULL, NULL, '2026-11-19 15:38:00', '2026-11-19 15:38:00'),
(216, 28, 1, 1, '2026-11-19 11:00:00', '2026-11-19', 'Media', 'No entregada', 240.00, 'Efectivo', NULL, 'El encargado no tenía autorización para recibir', NULL, '2026-11-19 18:01:00'),
(217, 24, 2, 1, '2026-11-19 11:14:00', '2026-11-19', 'Baja', 'Entregada', 170.00, 'Tarjeta', NULL, NULL, '2026-11-19 13:13:00', '2026-11-19 13:13:00'),
(218, 1, 4, 4, '2026-11-19 11:18:00', '2026-11-19', 'Baja', 'No entregada', 670.00, 'Efectivo', 'Dejar con el encargado', 'No había quien recibiera el pedido', NULL, '2026-11-19 16:20:00'),
(219, 21, 4, 4, '2026-11-19 12:07:00', '2026-11-19', 'Media', 'Entregada', 1128.00, 'Efectivo', 'Entregar antes de las 12:00', NULL, '2026-11-19 14:07:00', '2026-11-19 14:07:00'),
(220, 2, 1, 1, '2026-11-19 12:07:00', '2026-11-19', 'Media', 'Entregada', 970.00, 'Efectivo', NULL, NULL, '2026-11-19 14:38:00', '2026-11-19 14:38:00'),
(221, 2, 2, 1, '2026-11-19 12:12:00', '2026-11-19', 'Baja', 'Entregada', 240.00, 'Transferencia', 'Entregar antes de las 12:00', NULL, '2026-11-19 15:10:00', '2026-11-19 15:10:00'),
(222, 6, 3, 4, '2026-11-19 15:29:00', '2026-11-20', 'Media', 'Entregada', 1494.00, 'Tarjeta', 'Cliente pide factura', NULL, '2026-11-20 11:22:00', '2026-11-20 11:22:00'),
(223, 16, 4, 1, '2026-11-19 16:40:00', '2026-11-20', 'Alta', 'No entregada', 566.00, 'Efectivo', 'Llamar antes de llegar', 'No había quien recibiera el pedido', NULL, '2026-11-20 13:38:00'),
(224, 17, 1, 1, '2026-11-19 16:59:00', '2026-11-20', 'Alta', 'Entregada', 318.00, 'Efectivo', NULL, NULL, '2026-11-20 10:53:00', '2026-11-20 10:53:00'),
(225, 16, 1, 1, '2026-11-19 18:28:00', '2026-11-20', 'Alta', 'Entregada', 281.00, 'Transferencia', NULL, NULL, '2026-11-20 16:35:00', '2026-11-20 16:35:00'),
(226, 1, 1, 1, '2026-11-19 18:39:00', '2026-11-20', 'Media', 'Entregada', 655.00, 'Tarjeta', 'Entregar por la puerta lateral', NULL, '2026-11-20 16:00:00', '2026-11-20 16:00:00'),
(227, 19, 2, 1, '2026-11-20 07:44:00', '2026-11-20', 'Baja', 'Entregada', 604.00, 'Efectivo', 'Cliente pide factura', NULL, '2026-11-20 09:45:00', '2026-11-20 09:45:00'),
(228, 6, 1, 1, '2026-11-20 07:49:00', '2026-11-20', 'Media', 'Entregada', 924.00, 'Efectivo', NULL, NULL, '2026-11-20 10:01:00', '2026-11-20 10:01:00'),
(229, 22, 2, 1, '2026-11-20 07:51:00', '2026-11-20', 'Media', 'Entregada', 1073.00, 'Tarjeta', NULL, NULL, '2026-11-20 10:00:00', '2026-11-20 10:00:00'),
(230, 1, 1, 1, '2026-11-20 08:03:00', '2026-11-20', 'Alta', 'Entregada', 516.00, 'Efectivo', NULL, NULL, '2026-11-20 17:08:00', '2026-11-20 17:08:00'),
(231, 4, 3, 4, '2026-11-20 08:08:00', '2026-11-20', 'Baja', 'Entregada', 340.00, 'Efectivo', 'Llamar antes de llegar', NULL, '2026-11-20 13:49:00', '2026-11-20 13:49:00'),
(232, 6, 1, 1, '2026-11-20 09:38:00', '2026-11-20', 'Media', 'Entregada', 192.00, 'Tarjeta', NULL, NULL, '2026-11-20 14:25:00', '2026-11-20 14:25:00'),
(233, 17, 3, 1, '2026-11-20 09:39:00', '2026-11-20', 'Baja', 'No entregada', 768.00, 'Efectivo', NULL, 'Negocio cerrado al llegar', NULL, '2026-11-20 15:34:00'),
(234, 22, 4, 1, '2026-11-20 09:43:00', '2026-11-20', 'Alta', 'Entregada', 532.00, 'Tarjeta', NULL, NULL, '2026-11-20 18:23:00', '2026-11-20 18:23:00'),
(235, 12, 3, 4, '2026-11-20 10:06:00', '2026-11-20', 'Media', 'Entregada', 865.00, 'Transferencia', 'Llamar antes de llegar', NULL, '2026-11-20 15:20:00', '2026-11-20 15:20:00'),
(236, 23, 4, 1, '2026-11-20 10:09:00', '2026-11-20', 'Media', 'Entregada', 595.00, 'Efectivo', 'Pago contra entrega', NULL, '2026-11-20 13:40:00', '2026-11-20 13:40:00'),
(237, 15, 2, 4, '2026-11-20 10:14:00', '2026-11-20', 'Alta', 'Entregada', 360.00, 'Efectivo', 'Pago contra entrega', NULL, '2026-11-20 12:11:00', '2026-11-20 12:11:00'),
(238, 23, 1, 1, '2026-11-20 10:20:00', '2026-11-20', 'Alta', 'Entregada', 240.00, 'Efectivo', NULL, NULL, '2026-11-20 13:22:00', '2026-11-20 13:22:00'),
(239, 25, 2, 1, '2026-11-20 10:23:00', '2026-11-20', 'Media', 'Entregada', 456.00, 'Efectivo', 'Confirmar pedido por teléfono', NULL, '2026-11-20 18:35:00', '2026-11-20 18:35:00'),
(240, 10, 4, 4, '2026-11-20 10:59:00', '2026-11-20', 'Media', 'No entregada', 818.00, 'Efectivo', NULL, 'No se localizó el domicilio', NULL, '2026-11-20 13:06:00');

INSERT INTO pedidos
  (id_pedido, id_cliente, id_repartidor, id_usuario_registro, fecha_registro, fecha_programada, urgencia, estado, total, forma_pago, observaciones, motivo_no_entrega, fecha_entrega, fecha_actualizacion)
VALUES
(241, 19, 1, 1, '2026-11-20 11:22:00', '2026-11-20', 'Alta', 'Entregada', 432.00, 'Tarjeta', 'Confirmar pedido por teléfono', NULL, '2026-11-20 16:47:00', '2026-11-20 16:47:00'),
(242, 25, 3, 1, '2026-11-20 11:33:00', '2026-11-20', 'Media', 'Entregada', 245.00, 'Efectivo', 'Confirmar pedido por teléfono', NULL, '2026-11-20 13:12:00', '2026-11-20 13:12:00'),
(243, 11, 3, 1, '2026-11-20 11:34:00', '2026-11-20', 'Media', 'Entregada', 324.00, 'Efectivo', 'Pago contra entrega', NULL, '2026-11-20 15:36:00', '2026-11-20 15:36:00');

-- Detalle de pedidos
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(1, 23, 6, 17.00), (1, 4, 18, 20.00), (2, 23, 20, 17.00), (2, 14, 20, 15.00), (3, 26, 18, 30.00),
(3, 1, 20, 18.00), (3, 13, 8, 14.00), (4, 11, 5, 28.00), (4, 25, 8, 22.00), (4, 6, 12, 19.00),
(5, 5, 10, 18.00), (5, 13, 6, 14.00), (5, 8, 24, 15.00), (5, 29, 8, 16.00), (5, 26, 5, 30.00),
(6, 1, 8, 18.00), (6, 24, 12, 27.00), (7, 23, 24, 17.00), (8, 5, 18, 18.00), (8, 11, 6, 28.00),
(9, 18, 4, 32.00), (9, 30, 4, 48.00), (9, 9, 12, 24.00), (10, 12, 24, 17.00), (11, 3, 8, 25.00),
(12, 9, 18, 24.00), (12, 5, 6, 18.00), (13, 25, 10, 22.00), (13, 24, 18, 27.00), (14, 1, 10, 18.00),
(14, 3, 8, 25.00), (15, 21, 10, 19.00), (15, 9, 8, 24.00), (15, 8, 5, 15.00), (15, 3, 20, 25.00),
(16, 7, 20, 21.00), (16, 2, 18, 22.00), (17, 4, 10, 20.00), (18, 17, 12, 23.00), (18, 19, 6, 27.00),
(19, 18, 20, 32.00), (19, 13, 24, 14.00), (19, 7, 12, 21.00), (20, 24, 6, 27.00), (20, 27, 12, 18.00),
(21, 12, 4, 17.00), (22, 7, 6, 21.00), (22, 25, 12, 22.00), (22, 15, 12, 20.00), (23, 29, 8, 16.00),
(23, 16, 6, 12.00), (23, 19, 15, 27.00), (23, 13, 6, 14.00), (24, 11, 15, 28.00), (24, 14, 15, 15.00),
(24, 8, 15, 15.00), (24, 30, 5, 48.00), (24, 10, 4, 26.00), (25, 8, 10, 15.00), (25, 24, 10, 27.00),
(25, 2, 20, 22.00), (26, 18, 6, 32.00), (26, 5, 6, 18.00), (26, 29, 24, 16.00), (26, 11, 5, 28.00),
(26, 3, 10, 25.00), (27, 22, 12, 24.00), (27, 28, 4, 21.00), (27, 21, 12, 19.00), (28, 10, 6, 26.00),
(28, 7, 18, 21.00), (28, 23, 8, 17.00), (29, 6, 6, 19.00), (30, 30, 10, 48.00), (31, 21, 24, 19.00),
(31, 17, 18, 23.00), (31, 10, 15, 26.00), (32, 30, 10, 48.00), (32, 14, 8, 15.00), (32, 24, 8, 27.00),
(32, 1, 8, 18.00), (33, 6, 10, 19.00), (33, 10, 6, 26.00), (33, 29, 8, 16.00), (34, 24, 10, 27.00),
(35, 3, 4, 25.00), (35, 14, 5, 15.00), (35, 15, 5, 20.00), (35, 1, 10, 18.00), (36, 2, 5, 22.00),
(37, 6, 24, 19.00), (37, 1, 4, 18.00), (38, 16, 8, 12.00), (38, 3, 6, 25.00), (38, 23, 12, 17.00),
(38, 28, 18, 21.00), (39, 18, 24, 32.00), (39, 3, 15, 25.00), (39, 8, 24, 15.00), (39, 30, 4, 48.00),
(40, 28, 4, 21.00), (40, 16, 10, 12.00), (41, 21, 18, 19.00), (41, 25, 5, 22.00), (42, 4, 15, 20.00),
(42, 8, 8, 15.00), (43, 14, 20, 15.00), (43, 2, 20, 22.00), (44, 19, 20, 27.00), (44, 24, 6, 27.00),
(45, 2, 8, 22.00), (46, 27, 8, 18.00), (46, 24, 18, 27.00), (46, 8, 8, 15.00), (46, 26, 8, 30.00),
(47, 3, 5, 25.00), (47, 21, 8, 19.00), (47, 1, 4, 18.00), (47, 6, 6, 19.00), (48, 1, 5, 18.00),
(48, 6, 8, 19.00), (48, 12, 10, 17.00), (48, 21, 6, 19.00), (49, 2, 6, 22.00), (49, 27, 10, 18.00),
(49, 18, 24, 32.00), (49, 6, 20, 19.00), (50, 1, 20, 18.00), (50, 2, 4, 22.00), (50, 19, 12, 27.00),
(50, 27, 5, 18.00), (50, 12, 20, 17.00), (51, 16, 15, 12.00), (51, 1, 18, 18.00), (52, 10, 18, 26.00),
(52, 18, 10, 32.00), (52, 3, 12, 25.00), (53, 26, 10, 30.00), (53, 18, 18, 32.00), (53, 8, 18, 15.00),
(54, 1, 6, 18.00), (54, 8, 5, 15.00), (55, 3, 6, 25.00), (55, 15, 4, 20.00), (55, 6, 10, 19.00),
(56, 21, 8, 19.00), (56, 19, 5, 27.00), (57, 28, 8, 21.00), (57, 30, 12, 48.00), (58, 4, 6, 20.00);

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(59, 27, 24, 18.00), (59, 23, 5, 17.00), (59, 28, 6, 21.00), (60, 1, 24, 18.00), (61, 8, 12, 15.00),
(61, 9, 12, 24.00), (62, 4, 20, 20.00), (62, 12, 6, 17.00), (62, 18, 4, 32.00), (63, 10, 10, 26.00),
(63, 3, 12, 25.00), (63, 14, 8, 15.00), (63, 7, 18, 21.00), (64, 6, 10, 19.00), (64, 15, 5, 20.00),
(64, 2, 6, 22.00), (65, 3, 24, 25.00), (65, 23, 10, 17.00), (66, 2, 6, 22.00), (66, 15, 6, 20.00),
(67, 15, 4, 20.00), (67, 4, 4, 20.00), (67, 16, 20, 12.00), (67, 29, 20, 16.00), (68, 30, 18, 48.00),
(68, 2, 4, 22.00), (68, 6, 5, 19.00), (69, 21, 15, 19.00), (69, 23, 24, 17.00), (70, 24, 4, 27.00),
(70, 22, 10, 24.00), (70, 7, 6, 21.00), (71, 7, 24, 21.00), (71, 18, 6, 32.00), (71, 16, 15, 12.00),
(72, 4, 10, 20.00), (72, 23, 12, 17.00), (73, 15, 10, 20.00), (73, 30, 8, 48.00), (73, 1, 8, 18.00),
(73, 12, 12, 17.00), (73, 28, 10, 21.00), (74, 30, 12, 48.00), (75, 4, 10, 20.00), (75, 14, 24, 15.00),
(76, 19, 8, 27.00), (76, 15, 12, 20.00), (76, 22, 15, 24.00), (76, 1, 10, 18.00), (77, 14, 24, 15.00),
(77, 29, 6, 16.00), (77, 18, 12, 32.00), (78, 25, 10, 22.00), (78, 4, 5, 20.00), (79, 24, 18, 27.00),
(79, 1, 20, 18.00), (79, 8, 12, 15.00), (80, 29, 15, 16.00), (80, 1, 6, 18.00), (81, 6, 12, 19.00),
(81, 2, 20, 22.00), (81, 30, 6, 48.00), (81, 26, 18, 30.00), (82, 1, 18, 18.00), (82, 4, 4, 20.00),
(83, 12, 6, 17.00), (84, 7, 20, 21.00), (84, 4, 18, 20.00), (85, 2, 4, 22.00), (86, 25, 10, 22.00),
(86, 16, 6, 12.00), (86, 28, 18, 21.00), (87, 24, 15, 27.00), (87, 3, 6, 25.00), (88, 12, 12, 17.00),
(88, 18, 4, 32.00), (88, 19, 20, 27.00), (89, 6, 18, 19.00), (89, 18, 18, 32.00), (89, 26, 12, 30.00),
(90, 4, 10, 20.00), (90, 2, 24, 22.00), (90, 3, 10, 25.00), (90, 15, 12, 20.00), (91, 22, 24, 24.00),
(91, 6, 12, 19.00), (91, 8, 18, 15.00), (91, 18, 10, 32.00), (91, 19, 10, 27.00), (92, 26, 6, 30.00),
(93, 26, 6, 30.00), (93, 10, 12, 26.00), (94, 1, 18, 18.00), (94, 21, 5, 19.00), (95, 10, 12, 26.00),
(95, 4, 4, 20.00), (96, 21, 10, 19.00), (96, 28, 8, 21.00), (96, 6, 10, 19.00), (97, 8, 10, 15.00),
(97, 18, 18, 32.00), (97, 3, 24, 25.00), (98, 3, 15, 25.00), (99, 16, 8, 12.00), (99, 22, 15, 24.00),
(99, 23, 20, 17.00), (100, 16, 10, 12.00), (101, 7, 20, 21.00), (101, 8, 4, 15.00), (101, 1, 5, 18.00),
(102, 14, 18, 15.00), (102, 4, 15, 20.00), (102, 29, 6, 16.00), (102, 28, 8, 21.00), (102, 1, 8, 18.00),
(103, 15, 12, 20.00), (104, 22, 10, 24.00), (104, 6, 12, 19.00), (104, 2, 6, 22.00), (104, 8, 6, 15.00),
(105, 1, 20, 18.00), (105, 4, 10, 20.00), (105, 7, 5, 21.00), (105, 6, 8, 19.00), (106, 19, 15, 27.00),
(107, 26, 10, 30.00), (107, 8, 18, 15.00), (107, 24, 10, 27.00), (108, 2, 24, 22.00), (108, 3, 12, 25.00),
(108, 19, 10, 27.00), (108, 30, 8, 48.00), (109, 1, 8, 18.00), (109, 28, 24, 21.00), (110, 1, 4, 18.00),
(110, 25, 12, 22.00), (110, 19, 4, 27.00), (110, 7, 5, 21.00), (111, 3, 5, 25.00), (111, 6, 5, 19.00),
(111, 10, 24, 26.00), (111, 1, 20, 18.00), (111, 25, 5, 22.00), (112, 9, 15, 24.00), (112, 6, 10, 19.00),
(112, 1, 18, 18.00), (113, 28, 24, 21.00), (114, 14, 12, 15.00), (114, 18, 10, 32.00), (114, 15, 18, 20.00);

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(114, 22, 24, 24.00), (115, 21, 24, 19.00), (115, 6, 4, 19.00), (116, 1, 12, 18.00), (116, 30, 12, 48.00),
(116, 6, 8, 19.00), (116, 14, 6, 15.00), (117, 18, 6, 32.00), (117, 22, 8, 24.00), (118, 3, 24, 25.00),
(118, 22, 8, 24.00), (118, 4, 5, 20.00), (118, 10, 8, 26.00), (119, 30, 18, 48.00), (119, 2, 10, 22.00),
(119, 10, 8, 26.00), (119, 24, 5, 27.00), (119, 29, 8, 16.00), (120, 9, 10, 24.00), (120, 14, 5, 15.00),
(120, 27, 20, 18.00), (120, 21, 5, 19.00), (120, 1, 12, 18.00), (121, 10, 8, 26.00), (121, 19, 20, 27.00),
(121, 1, 8, 18.00), (121, 23, 12, 17.00), (122, 7, 6, 21.00), (122, 23, 10, 17.00), (123, 1, 12, 18.00),
(123, 27, 6, 18.00), (123, 18, 18, 32.00), (123, 21, 12, 19.00), (124, 28, 10, 21.00), (124, 6, 24, 19.00),
(125, 1, 20, 18.00), (126, 10, 20, 26.00), (126, 3, 10, 25.00), (126, 2, 5, 22.00), (127, 1, 4, 18.00),
(127, 15, 6, 20.00), (128, 1, 5, 18.00), (128, 21, 18, 19.00), (129, 3, 24, 25.00), (130, 18, 10, 32.00),
(130, 4, 12, 20.00), (130, 15, 4, 20.00), (131, 23, 6, 17.00), (132, 21, 5, 19.00), (133, 3, 24, 25.00),
(133, 23, 6, 17.00), (134, 25, 12, 22.00), (134, 10, 12, 26.00), (135, 6, 10, 19.00), (135, 22, 20, 24.00),
(135, 8, 8, 15.00), (136, 3, 5, 25.00), (136, 12, 24, 17.00), (137, 19, 18, 27.00), (137, 23, 20, 17.00),
(138, 1, 12, 18.00), (138, 21, 8, 19.00), (138, 4, 4, 20.00), (139, 25, 15, 22.00), (139, 1, 10, 18.00),
(139, 8, 12, 15.00), (140, 8, 24, 15.00), (140, 18, 5, 32.00), (140, 3, 10, 25.00), (141, 3, 8, 25.00),
(141, 21, 5, 19.00), (142, 3, 20, 25.00), (142, 18, 12, 32.00), (142, 1, 12, 18.00), (143, 2, 8, 22.00),
(143, 23, 5, 17.00), (143, 27, 10, 18.00), (143, 22, 18, 24.00), (144, 3, 24, 25.00), (144, 28, 4, 21.00),
(144, 2, 20, 22.00), (144, 18, 10, 32.00), (145, 6, 12, 19.00), (146, 15, 6, 20.00), (146, 3, 10, 25.00),
(147, 3, 8, 25.00), (147, 15, 8, 20.00), (147, 4, 20, 20.00), (147, 16, 10, 12.00), (148, 10, 20, 26.00),
(148, 14, 10, 15.00), (148, 15, 8, 20.00), (148, 24, 12, 27.00), (148, 27, 6, 18.00), (149, 2, 10, 22.00),
(149, 3, 20, 25.00), (149, 29, 15, 16.00), (149, 8, 20, 15.00), (150, 18, 12, 32.00), (150, 15, 10, 20.00),
(151, 10, 12, 26.00), (151, 6, 4, 19.00), (151, 23, 20, 17.00), (152, 9, 4, 24.00), (152, 27, 6, 18.00),
(153, 4, 24, 20.00), (154, 10, 5, 26.00), (154, 4, 6, 20.00), (155, 12, 12, 17.00), (155, 18, 10, 32.00),
(156, 3, 6, 25.00), (156, 4, 10, 20.00), (156, 8, 18, 15.00), (157, 6, 10, 19.00), (157, 25, 8, 22.00),
(158, 4, 18, 20.00), (159, 16, 24, 12.00), (159, 2, 12, 22.00), (160, 29, 10, 16.00), (160, 3, 15, 25.00),
(160, 7, 10, 21.00), (160, 23, 20, 17.00), (160, 18, 8, 32.00), (161, 4, 24, 20.00), (161, 3, 6, 25.00),
(162, 3, 24, 25.00), (162, 15, 24, 20.00), (163, 15, 12, 20.00), (163, 30, 6, 48.00), (163, 1, 4, 18.00),
(163, 18, 5, 32.00), (163, 19, 5, 27.00), (164, 21, 18, 19.00), (164, 16, 12, 12.00), (165, 7, 4, 21.00),
(165, 3, 18, 25.00), (165, 30, 12, 48.00), (165, 23, 10, 17.00), (166, 28, 10, 21.00), (166, 3, 6, 25.00),
(166, 15, 8, 20.00), (166, 22, 12, 24.00), (167, 7, 6, 21.00), (168, 14, 18, 15.00), (168, 6, 12, 19.00),
(169, 14, 24, 15.00), (170, 27, 12, 18.00), (170, 6, 8, 19.00), (170, 21, 15, 19.00), (171, 3, 18, 25.00);

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(171, 8, 8, 15.00), (172, 1, 6, 18.00), (173, 12, 24, 17.00), (173, 22, 18, 24.00), (174, 9, 8, 24.00),
(174, 14, 12, 15.00), (174, 15, 12, 20.00), (175, 3, 8, 25.00), (176, 15, 12, 20.00), (176, 26, 10, 30.00),
(176, 4, 4, 20.00), (176, 6, 8, 19.00), (177, 28, 18, 21.00), (177, 25, 8, 22.00), (177, 3, 15, 25.00),
(178, 30, 8, 48.00), (178, 9, 6, 24.00), (179, 1, 4, 18.00), (179, 6, 12, 19.00), (180, 8, 24, 15.00),
(180, 4, 15, 20.00), (180, 18, 5, 32.00), (180, 29, 10, 16.00), (180, 26, 15, 30.00), (181, 4, 10, 20.00),
(181, 1, 5, 18.00), (182, 26, 20, 30.00), (182, 16, 12, 12.00), (182, 4, 8, 20.00), (182, 19, 8, 27.00),
(183, 29, 10, 16.00), (183, 8, 10, 15.00), (183, 25, 24, 22.00), (183, 22, 8, 24.00), (184, 23, 18, 17.00),
(185, 2, 8, 22.00), (185, 6, 10, 19.00), (186, 1, 24, 18.00), (186, 21, 20, 19.00), (187, 18, 15, 32.00),
(187, 6, 5, 19.00), (188, 8, 8, 15.00), (188, 19, 5, 27.00), (188, 2, 18, 22.00), (188, 1, 12, 18.00),
(189, 23, 4, 17.00), (189, 2, 12, 22.00), (189, 26, 6, 30.00), (189, 24, 8, 27.00), (190, 9, 15, 24.00),
(190, 18, 12, 32.00), (190, 23, 10, 17.00), (190, 4, 8, 20.00), (190, 28, 8, 21.00), (191, 21, 6, 19.00),
(192, 15, 4, 20.00), (193, 3, 12, 25.00), (193, 2, 12, 22.00), (194, 14, 6, 15.00), (195, 25, 20, 22.00),
(195, 2, 6, 22.00), (195, 16, 6, 12.00), (195, 27, 20, 18.00), (195, 8, 6, 15.00), (196, 1, 20, 18.00),
(196, 8, 12, 15.00), (197, 21, 12, 19.00), (197, 8, 10, 15.00), (197, 9, 18, 24.00), (197, 6, 10, 19.00),
(197, 10, 6, 26.00), (198, 6, 8, 19.00), (198, 9, 5, 24.00), (198, 30, 8, 48.00), (199, 18, 8, 32.00),
(199, 14, 10, 15.00), (200, 15, 24, 20.00), (200, 25, 20, 22.00), (200, 9, 12, 24.00), (200, 14, 6, 15.00),
(201, 10, 15, 26.00), (201, 24, 8, 27.00), (202, 1, 4, 18.00), (202, 6, 15, 19.00), (203, 15, 15, 20.00),
(203, 25, 12, 22.00), (204, 19, 8, 27.00), (204, 4, 24, 20.00), (205, 19, 15, 27.00), (205, 9, 4, 24.00),
(205, 4, 10, 20.00), (206, 9, 8, 24.00), (206, 1, 8, 18.00), (206, 8, 8, 15.00), (206, 30, 10, 48.00),
(207, 12, 5, 17.00), (207, 10, 6, 26.00), (207, 28, 10, 21.00), (208, 16, 10, 12.00), (208, 27, 10, 18.00),
(208, 14, 8, 15.00), (208, 8, 6, 15.00), (209, 6, 12, 19.00), (209, 24, 24, 27.00), (210, 23, 15, 17.00),
(210, 25, 6, 22.00), (210, 16, 6, 12.00), (210, 14, 8, 15.00), (211, 23, 18, 17.00), (211, 19, 12, 27.00),
(211, 27, 10, 18.00), (212, 4, 24, 20.00), (212, 25, 24, 22.00), (212, 26, 15, 30.00), (212, 21, 10, 19.00),
(213, 10, 12, 26.00), (213, 30, 8, 48.00), (214, 18, 6, 32.00), (214, 19, 12, 27.00), (215, 6, 24, 19.00),
(216, 4, 12, 20.00), (217, 23, 10, 17.00), (218, 8, 10, 15.00), (218, 10, 20, 26.00), (219, 23, 12, 17.00),
(219, 8, 12, 15.00), (219, 30, 6, 48.00), (219, 6, 24, 19.00), (220, 22, 12, 24.00), (220, 1, 24, 18.00),
(220, 3, 10, 25.00), (221, 8, 4, 15.00), (221, 14, 12, 15.00), (222, 1, 20, 18.00), (222, 19, 8, 27.00),
(222, 6, 18, 19.00), (222, 22, 24, 24.00), (223, 25, 8, 22.00), (223, 26, 10, 30.00), (223, 14, 6, 15.00),
(224, 27, 12, 18.00), (224, 12, 6, 17.00), (225, 3, 5, 25.00), (225, 10, 6, 26.00), (226, 22, 10, 24.00),
(226, 14, 15, 15.00), (226, 6, 10, 19.00), (227, 1, 8, 18.00), (227, 19, 12, 27.00), (227, 12, 8, 17.00);

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(228, 4, 6, 20.00), (228, 24, 10, 27.00), (228, 1, 15, 18.00), (228, 2, 12, 22.00), (229, 1, 20, 18.00),
(229, 23, 10, 17.00), (229, 30, 6, 48.00), (229, 12, 15, 17.00), (230, 16, 8, 12.00), (230, 28, 20, 21.00),
(231, 26, 4, 30.00), (231, 2, 10, 22.00), (232, 18, 6, 32.00), (233, 18, 24, 32.00), (234, 22, 18, 24.00),
(234, 4, 5, 20.00), (235, 14, 4, 15.00), (235, 8, 15, 15.00), (235, 3, 8, 25.00), (235, 21, 20, 19.00),
(236, 7, 12, 21.00), (236, 25, 4, 22.00), (236, 23, 15, 17.00), (237, 26, 12, 30.00), (238, 7, 5, 21.00),
(238, 19, 5, 27.00), (239, 8, 20, 15.00), (239, 10, 6, 26.00), (240, 6, 12, 19.00), (240, 7, 20, 21.00),
(240, 23, 10, 17.00), (241, 9, 18, 24.00), (242, 14, 10, 15.00), (242, 21, 5, 19.00), (243, 21, 12, 19.00),
(243, 9, 4, 24.00);

-- ---------------------------------------------------------------------
-- Ajuste de los pedidos a la hora actual
-- ---------------------------------------------------------------------
-- 1) Los que todavía no se levantan no existen (su detalle se va en cascada)
DELETE FROM pedidos WHERE fecha_registro > @ahora;
ALTER TABLE pedidos AUTO_INCREMENT = 1;
ALTER TABLE detalle_pedido AUTO_INCREMENT = 1;

-- 2) Los que ya se levantaron pero aún no se entregan (o resuelven) quedan en proceso:
--    los de la última hora y media sin repartidor (Pendiente), el resto En Ruta.
UPDATE pedidos SET observaciones = NULL, fecha_actualizacion = fecha_actualizacion
WHERE fecha_actualizacion > @ahora AND estado = 'Cancelada';

UPDATE pedidos SET id_repartidor = NULL, fecha_actualizacion = fecha_actualizacion
WHERE fecha_actualizacion > @ahora AND fecha_registro > @hace90;

UPDATE pedidos SET estado = 'Pendiente', motivo_no_entrega = NULL, fecha_entrega = NULL, fecha_actualizacion = fecha_actualizacion
WHERE fecha_actualizacion > @ahora AND id_repartidor IS NULL;

UPDATE pedidos SET estado = 'En Ruta', motivo_no_entrega = NULL, fecha_entrega = NULL, fecha_actualizacion = fecha_actualizacion
WHERE fecha_actualizacion > @ahora AND id_repartidor IS NOT NULL;

UPDATE pedidos SET fecha_actualizacion = LEAST(TIMESTAMPADD(MINUTE, 40, fecha_registro), @ahora)
WHERE fecha_actualizacion > @ahora AND estado = 'En Ruta';

UPDATE pedidos SET fecha_actualizacion = fecha_registro
WHERE fecha_actualizacion > @ahora;

-- 3) Pedidos "en vivo": siempre hay pedidos en ruta y pendientes recién levantados,
--    sin importar a qué hora se ejecute el script.
SET @p = (SELECT COALESCE(MAX(id_pedido), 0) FROM pedidos);

INSERT INTO pedidos
  (id_pedido, id_cliente, id_repartidor, id_usuario_registro, fecha_registro, fecha_programada, urgencia, estado, total, forma_pago, observaciones, motivo_no_entrega, fecha_entrega, fecha_actualizacion)
VALUES
(@p + 1, 12, 3, 4, TIMESTAMPADD(MINUTE, -165, @ahora), TIMESTAMPADD(DAY, 0, @hoy), 'Alta', 'En Ruta', 664.00, 'Tarjeta', 'Entregar antes del cierre', NULL, NULL, TIMESTAMPADD(MINUTE, -125, @ahora)),
(@p + 2, 6, 1, 1, TIMESTAMPADD(MINUTE, -140, @ahora), TIMESTAMPADD(DAY, 0, @hoy), 'Media', 'En Ruta', 400.00, 'Efectivo', NULL, NULL, NULL, TIMESTAMPADD(MINUTE, -100, @ahora)),
(@p + 3, 20, 2, 1, TIMESTAMPADD(MINUTE, -115, @ahora), TIMESTAMPADD(DAY, 0, @hoy), 'Media', 'En Ruta', 634.00, 'Transferencia', 'Cliente pide factura', NULL, NULL, TIMESTAMPADD(MINUTE, -75, @ahora)),
(@p + 4, 3, 4, 4, TIMESTAMPADD(MINUTE, -95, @ahora), TIMESTAMPADD(DAY, 0, @hoy), 'Baja', 'En Ruta', 330.00, 'Efectivo', NULL, NULL, NULL, TIMESTAMPADD(MINUTE, -55, @ahora)),
(@p + 5, 14, NULL, 1, TIMESTAMPADD(MINUTE, -50, @ahora), TIMESTAMPADD(DAY, 0, @hoy), 'Alta', 'Pendiente', 276.00, 'Efectivo', 'Cliente solicita entrega urgente', NULL, NULL, TIMESTAMPADD(MINUTE, -50, @ahora)),
(@p + 6, 2, NULL, 4, TIMESTAMPADD(MINUTE, -35, @ahora), TIMESTAMPADD(DAY, 0, @hoy), 'Alta', 'Pendiente', 262.00, 'Tarjeta', 'Llamar antes de ir, no tienen timbre', NULL, NULL, TIMESTAMPADD(MINUTE, -35, @ahora)),
(@p + 7, 25, NULL, 1, TIMESTAMPADD(MINUTE, -25, @ahora), TIMESTAMPADD(DAY, 0, @hoy), 'Media', 'Pendiente', 918.00, 'Transferencia', 'Cliente pide factura', NULL, NULL, TIMESTAMPADD(MINUTE, -25, @ahora)),
(@p + 8, 7, NULL, 1, TIMESTAMPADD(MINUTE, -15, @ahora), TIMESTAMPADD(DAY, 1, @hoy), 'Media', 'Pendiente', 316.00, 'Transferencia', 'Programado para mañana', NULL, NULL, TIMESTAMPADD(MINUTE, -15, @ahora)),
(@p + 9, 16, NULL, 4, TIMESTAMPADD(MINUTE, -10, @ahora), TIMESTAMPADD(DAY, 1, @hoy), 'Baja', 'Pendiente', 300.00, 'Efectivo', 'Programado para mañana', NULL, NULL, TIMESTAMPADD(MINUTE, -10, @ahora)),
(@p + 10, 10, NULL, 1, TIMESTAMPADD(MINUTE, -5, @ahora), TIMESTAMPADD(DAY, 2, @hoy), 'Baja', 'Pendiente', 486.00, 'Transferencia', NULL, NULL, NULL, TIMESTAMPADD(MINUTE, -5, @ahora));

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@p + 1, 1, 12, 18.00),
(@p + 1, 18, 8, 32.00),
(@p + 1, 30, 4, 48.00),
(@p + 2, 2, 10, 22.00),
(@p + 2, 8, 12, 15.00),
(@p + 3, 3, 10, 25.00),
(@p + 3, 10, 6, 26.00),
(@p + 3, 21, 12, 19.00),
(@p + 4, 4, 8, 20.00),
(@p + 4, 23, 10, 17.00),
(@p + 5, 18, 6, 32.00),
(@p + 5, 7, 4, 21.00),
(@p + 6, 2, 5, 22.00),
(@p + 6, 6, 8, 19.00),
(@p + 7, 1, 20, 18.00),
(@p + 7, 24, 10, 27.00),
(@p + 7, 30, 6, 48.00),
(@p + 8, 1, 10, 18.00),
(@p + 8, 12, 8, 17.00),
(@p + 9, 9, 8, 24.00),
(@p + 9, 27, 6, 18.00),
(@p + 10, 9, 8, 24.00),
(@p + 10, 26, 5, 30.00),
(@p + 10, 22, 6, 24.00);

-- ---------------------------------------------------------------------
-- Ventas de mostrador (sin pedido). Se cargan en una tabla de apoyo y solo
-- pasan a `ventas` las que ya ocurrieron.
-- ---------------------------------------------------------------------
CREATE TABLE _seed_mostrador (
  k            INT NOT NULL,
  id_cliente   INT UNSIGNED NOT NULL,
  id_usuario   INT UNSIGNED NOT NULL,
  fecha_venta  DATETIME NOT NULL,
  total        DECIMAL(12,2) NOT NULL,
  forma_pago   VARCHAR(20) NOT NULL,
  PRIMARY KEY (k)
) ENGINE=InnoDB;

CREATE TABLE _seed_mostrador_det (
  k                INT NOT NULL,
  id_producto      INT UNSIGNED NOT NULL,
  cantidad         INT NOT NULL,
  precio_unitario  DECIMAL(10,2) NOT NULL
) ENGINE=InnoDB;

INSERT INTO _seed_mostrador (k, id_cliente, id_usuario, fecha_venta, total, forma_pago) VALUES
(1, 4, 4, '2026-11-08 11:45:00', 126.00, 'Efectivo'),
(2, 3, 4, '2026-11-08 12:21:00', 216.00, 'Efectivo'),
(3, 25, 4, '2026-11-08 14:39:00', 48.00, 'Efectivo'),
(4, 1, 4, '2026-11-08 18:22:00', 156.00, 'Efectivo'),
(5, 25, 1, '2026-11-09 09:13:00', 150.00, 'Efectivo'),
(6, 17, 1, '2026-11-09 10:52:00', 56.00, 'Efectivo'),
(7, 10, 1, '2026-11-09 13:03:00', 105.00, 'Efectivo'),
(8, 22, 1, '2026-11-09 13:10:00', 163.00, 'Tarjeta'),
(9, 26, 1, '2026-11-09 14:13:00', 112.00, 'Tarjeta'),
(10, 4, 4, '2026-11-09 17:09:00', 96.00, 'Transferencia'),
(11, 19, 4, '2026-11-09 17:15:00', 38.00, 'Efectivo'),
(12, 18, 4, '2026-11-10 09:16:00', 160.00, 'Efectivo'),
(13, 2, 4, '2026-11-10 14:06:00', 228.00, 'Efectivo'),
(14, 23, 1, '2026-11-10 14:18:00', 140.00, 'Efectivo'),
(15, 8, 1, '2026-11-10 14:38:00', 157.00, 'Efectivo'),
(16, 1, 4, '2026-11-10 14:41:00', 88.00, 'Transferencia'),
(17, 14, 4, '2026-11-10 17:12:00', 203.00, 'Efectivo'),
(18, 13, 4, '2026-11-10 17:49:00', 313.00, 'Tarjeta'),
(19, 7, 4, '2026-11-11 10:49:00', 140.00, 'Transferencia'),
(20, 16, 4, '2026-11-11 11:01:00', 196.00, 'Efectivo'),
(21, 22, 1, '2026-11-11 11:34:00', 312.00, 'Efectivo'),
(22, 24, 1, '2026-11-11 13:16:00', 30.00, 'Efectivo'),
(23, 4, 1, '2026-11-11 13:57:00', 154.00, 'Tarjeta'),
(24, 28, 4, '2026-11-11 14:47:00', 192.00, 'Tarjeta'),
(25, 23, 1, '2026-11-11 16:17:00', 98.00, 'Transferencia'),
(26, 24, 1, '2026-11-11 16:49:00', 212.00, 'Efectivo'),
(27, 17, 1, '2026-11-12 10:16:00', 96.00, 'Efectivo'),
(28, 14, 1, '2026-11-12 10:23:00', 153.00, 'Efectivo'),
(29, 28, 4, '2026-11-12 12:41:00', 138.00, 'Tarjeta'),
(30, 28, 1, '2026-11-12 13:01:00', 150.00, 'Efectivo'),
(31, 25, 4, '2026-11-12 17:57:00', 180.00, 'Efectivo'),
(32, 7, 4, '2026-11-12 18:12:00', 45.00, 'Efectivo'),
(33, 29, 4, '2026-11-12 18:23:00', 190.00, 'Efectivo'),
(34, 14, 1, '2026-11-12 18:31:00', 40.00, 'Tarjeta'),
(35, 26, 4, '2026-11-13 10:28:00', 96.00, 'Efectivo'),
(36, 20, 4, '2026-11-13 10:48:00', 530.00, 'Efectivo'),
(37, 1, 1, '2026-11-13 13:11:00', 183.00, 'Tarjeta'),
(38, 9, 4, '2026-11-13 13:14:00', 332.00, 'Efectivo'),
(39, 6, 4, '2026-11-13 14:50:00', 198.00, 'Efectivo'),
(40, 8, 1, '2026-11-13 14:56:00', 75.00, 'Transferencia'),
(41, 10, 1, '2026-11-13 16:25:00', 48.00, 'Efectivo'),
(42, 7, 4, '2026-11-13 17:21:00', 60.00, 'Transferencia'),
(43, 3, 4, '2026-11-13 18:39:00', 180.00, 'Tarjeta'),
(44, 15, 4, '2026-11-14 09:11:00', 126.00, 'Efectivo'),
(45, 2, 1, '2026-11-14 12:16:00', 88.00, 'Efectivo'),
(46, 4, 4, '2026-11-14 12:31:00', 134.00, 'Efectivo'),
(47, 29, 4, '2026-11-14 13:41:00', 151.00, 'Transferencia'),
(48, 9, 1, '2026-11-14 13:56:00', 272.00, 'Tarjeta'),
(49, 6, 4, '2026-11-14 14:24:00', 100.00, 'Tarjeta'),
(50, 9, 4, '2026-11-14 14:31:00', 253.00, 'Efectivo'),
(51, 12, 1, '2026-11-14 18:18:00', 192.00, 'Tarjeta'),
(52, 14, 4, '2026-11-14 18:19:00', 113.00, 'Efectivo'),
(53, 26, 4, '2026-11-14 18:36:00', 128.00, 'Transferencia'),
(54, 22, 4, '2026-11-15 09:32:00', 312.00, 'Tarjeta'),
(55, 16, 4, '2026-11-15 12:59:00', 166.00, 'Tarjeta'),
(56, 23, 1, '2026-11-15 14:48:00', 145.00, 'Tarjeta'),
(57, 16, 4, '2026-11-15 16:21:00', 100.00, 'Efectivo'),
(58, 13, 1, '2026-11-15 17:14:00', 189.00, 'Efectivo'),
(59, 8, 1, '2026-11-16 09:37:00', 60.00, 'Efectivo'),
(60, 11, 1, '2026-11-16 10:40:00', 131.00, 'Efectivo'),
(61, 22, 1, '2026-11-16 11:26:00', 164.00, 'Efectivo'),
(62, 17, 4, '2026-11-16 14:08:00', 79.00, 'Transferencia'),
(63, 29, 4, '2026-11-16 14:38:00', 19.00, 'Efectivo'),
(64, 8, 1, '2026-11-16 15:45:00', 75.00, 'Tarjeta'),
(65, 15, 4, '2026-11-16 15:52:00', 245.00, 'Efectivo'),
(66, 15, 4, '2026-11-16 16:09:00', 88.00, 'Tarjeta'),
(67, 28, 4, '2026-11-16 16:58:00', 237.00, 'Efectivo'),
(68, 12, 4, '2026-11-16 18:46:00', 168.00, 'Efectivo'),
(69, 8, 1, '2026-11-17 09:15:00', 199.00, 'Efectivo'),
(70, 28, 1, '2026-11-17 11:06:00', 17.00, 'Tarjeta'),
(71, 16, 4, '2026-11-17 11:08:00', 88.00, 'Efectivo'),
(72, 17, 4, '2026-11-17 11:19:00', 255.00, 'Efectivo'),
(73, 13, 1, '2026-11-17 13:01:00', 126.00, 'Efectivo'),
(74, 1, 1, '2026-11-17 14:19:00', 90.00, 'Transferencia'),
(75, 18, 4, '2026-11-17 14:22:00', 176.00, 'Efectivo'),
(76, 29, 4, '2026-11-17 15:27:00', 132.00, 'Efectivo'),
(77, 9, 4, '2026-11-17 16:27:00', 276.00, 'Efectivo'),
(78, 23, 1, '2026-11-17 16:43:00', 64.00, 'Efectivo'),
(79, 11, 1, '2026-11-17 18:45:00', 60.00, 'Tarjeta'),
(80, 28, 1, '2026-11-18 09:20:00', 40.00, 'Efectivo'),
(81, 7, 1, '2026-11-18 10:14:00', 90.00, 'Transferencia'),
(82, 12, 1, '2026-11-18 10:17:00', 24.00, 'Efectivo'),
(83, 17, 1, '2026-11-18 10:30:00', 19.00, 'Efectivo'),
(84, 11, 1, '2026-11-18 10:34:00', 208.00, 'Efectivo'),
(85, 26, 4, '2026-11-18 11:37:00', 61.00, 'Efectivo'),
(86, 2, 4, '2026-11-18 11:51:00', 20.00, 'Transferencia'),
(87, 20, 1, '2026-11-18 14:28:00', 54.00, 'Tarjeta'),
(88, 25, 1, '2026-11-18 15:01:00', 60.00, 'Efectivo'),
(89, 3, 1, '2026-11-18 15:50:00', 75.00, 'Efectivo'),
(90, 21, 4, '2026-11-18 18:39:00', 30.00, 'Tarjeta'),
(91, 30, 1, '2026-11-18 18:53:00', 126.00, 'Tarjeta'),
(92, 14, 1, '2026-11-19 09:32:00', 97.00, 'Tarjeta'),
(93, 12, 4, '2026-11-19 09:59:00', 282.00, 'Efectivo'),
(94, 25, 4, '2026-11-19 10:17:00', 115.00, 'Efectivo'),
(95, 20, 4, '2026-11-19 10:33:00', 90.00, 'Tarjeta'),
(96, 27, 4, '2026-11-19 11:53:00', 75.00, 'Efectivo'),
(97, 12, 4, '2026-11-19 12:44:00', 109.00, 'Efectivo'),
(98, 24, 4, '2026-11-19 14:30:00', 27.00, 'Tarjeta'),
(99, 17, 1, '2026-11-19 15:36:00', 159.00, 'Efectivo'),
(100, 26, 1, '2026-11-19 16:27:00', 75.00, 'Efectivo'),
(101, 18, 1, '2026-11-20 09:29:00', 346.00, 'Efectivo'),
(102, 16, 4, '2026-11-20 09:59:00', 34.00, 'Tarjeta'),
(103, 6, 1, '2026-11-20 10:19:00', 138.00, 'Efectivo'),
(104, 10, 1, '2026-11-20 11:02:00', 100.00, 'Tarjeta'),
(105, 12, 4, '2026-11-20 14:05:00', 204.00, 'Tarjeta'),
(106, 23, 1, '2026-11-20 14:21:00', 201.00, 'Tarjeta'),
(107, 4, 4, '2026-11-20 15:02:00', 38.00, 'Efectivo'),
(108, 16, 1, '2026-11-20 16:08:00', 150.00, 'Tarjeta'),
(109, 11, 4, '2026-11-20 17:11:00', 99.00, 'Transferencia');

INSERT INTO _seed_mostrador_det (k, id_producto, cantidad, precio_unitario) VALUES
(1, 22, 3, 24.00), (1, 5, 3, 18.00), (2, 19, 8, 27.00), (3, 22, 2, 24.00), (4, 1, 2, 18.00),
(4, 14, 8, 15.00), (5, 3, 6, 25.00), (6, 11, 2, 28.00), (7, 7, 5, 21.00), (8, 4, 5, 20.00),
(8, 28, 3, 21.00), (9, 13, 2, 14.00), (9, 7, 4, 21.00), (10, 18, 3, 32.00), (11, 21, 2, 19.00),
(12, 18, 2, 32.00), (12, 13, 3, 14.00), (12, 27, 3, 18.00), (13, 3, 8, 25.00), (13, 11, 1, 28.00),
(14, 3, 2, 25.00), (14, 14, 6, 15.00), (15, 21, 4, 19.00), (15, 19, 3, 27.00), (16, 17, 2, 23.00),
(16, 7, 2, 21.00), (17, 3, 3, 25.00), (17, 18, 4, 32.00), (18, 7, 6, 21.00), (18, 24, 5, 27.00),
(18, 10, 2, 26.00), (19, 29, 6, 16.00), (19, 25, 2, 22.00), (20, 2, 1, 22.00), (20, 1, 3, 18.00),
(20, 4, 6, 20.00), (21, 4, 8, 20.00), (21, 6, 8, 19.00), (22, 26, 1, 30.00), (23, 24, 5, 27.00),
(23, 21, 1, 19.00), (24, 30, 4, 48.00), (25, 13, 2, 14.00), (25, 16, 2, 12.00), (25, 17, 2, 23.00),
(26, 18, 5, 32.00), (26, 10, 2, 26.00), (27, 18, 3, 32.00), (28, 24, 3, 27.00), (28, 9, 2, 24.00),
(28, 16, 2, 12.00), (29, 16, 2, 12.00), (29, 6, 6, 19.00), (30, 1, 5, 18.00), (30, 4, 3, 20.00),
(31, 26, 6, 30.00), (32, 8, 3, 15.00), (33, 26, 2, 30.00), (33, 8, 6, 15.00), (33, 15, 2, 20.00),
(34, 4, 2, 20.00), (35, 27, 2, 18.00), (35, 4, 3, 20.00), (36, 10, 5, 26.00), (36, 18, 8, 32.00),
(36, 22, 6, 24.00), (37, 19, 5, 27.00), (37, 22, 2, 24.00), (38, 22, 8, 24.00), (38, 21, 5, 19.00),
(38, 8, 3, 15.00), (39, 30, 3, 48.00), (39, 1, 3, 18.00), (40, 26, 1, 30.00), (40, 8, 3, 15.00),
(41, 9, 2, 24.00), (42, 8, 4, 15.00), (43, 30, 2, 48.00), (43, 7, 4, 21.00), (44, 16, 5, 12.00),
(44, 8, 2, 15.00), (44, 5, 2, 18.00), (45, 2, 4, 22.00), (46, 10, 3, 26.00), (46, 11, 2, 28.00),
(47, 4, 1, 20.00), (47, 6, 5, 19.00), (47, 1, 2, 18.00), (48, 3, 2, 25.00), (48, 25, 6, 22.00),
(48, 26, 3, 30.00), (49, 3, 4, 25.00), (50, 10, 8, 26.00), (50, 8, 3, 15.00), (51, 7, 2, 21.00),
(51, 18, 3, 32.00), (51, 1, 3, 18.00), (52, 1, 1, 18.00), (52, 6, 5, 19.00), (53, 18, 4, 32.00),
(54, 28, 8, 21.00), (54, 9, 6, 24.00), (55, 14, 2, 15.00), (55, 23, 8, 17.00), (56, 6, 5, 19.00),
(56, 3, 2, 25.00), (57, 15, 5, 20.00), (58, 8, 2, 15.00), (58, 12, 3, 17.00), (58, 19, 4, 27.00),
(59, 8, 4, 15.00), (60, 21, 5, 19.00), (60, 16, 3, 12.00), (61, 3, 2, 25.00), (61, 21, 6, 19.00),
(62, 18, 2, 32.00), (62, 14, 1, 15.00), (63, 21, 1, 19.00), (64, 8, 5, 15.00), (65, 23, 1, 17.00),
(65, 2, 6, 22.00), (65, 18, 3, 32.00), (66, 25, 4, 22.00), (67, 2, 6, 22.00), (67, 8, 2, 15.00),
(67, 14, 5, 15.00), (68, 16, 8, 12.00), (68, 9, 3, 24.00), (69, 1, 4, 18.00), (69, 3, 3, 25.00),
(69, 10, 2, 26.00), (70, 23, 1, 17.00), (71, 25, 4, 22.00), (72, 30, 3, 48.00), (72, 1, 2, 18.00),
(72, 3, 3, 25.00), (73, 23, 3, 17.00), (73, 3, 3, 25.00), (74, 26, 3, 30.00), (75, 2, 8, 22.00),
(76, 1, 2, 18.00), (76, 18, 3, 32.00), (77, 1, 4, 18.00), (77, 27, 8, 18.00), (77, 4, 3, 20.00),
(78, 18, 2, 32.00), (79, 15, 3, 20.00), (80, 15, 2, 20.00), (81, 27, 5, 18.00), (82, 16, 2, 12.00),
(83, 21, 1, 19.00), (84, 10, 8, 26.00), (85, 12, 1, 17.00), (85, 2, 2, 22.00), (86, 4, 1, 20.00),
(87, 23, 2, 17.00), (87, 4, 1, 20.00), (88, 15, 3, 20.00), (89, 8, 5, 15.00), (90, 8, 2, 15.00),
(91, 28, 6, 21.00), (92, 25, 1, 22.00), (92, 14, 5, 15.00), (93, 23, 8, 17.00), (93, 12, 4, 17.00),
(93, 10, 3, 26.00), (94, 23, 3, 17.00), (94, 8, 3, 15.00), (94, 21, 1, 19.00), (95, 14, 6, 15.00),
(96, 3, 3, 25.00), (97, 8, 3, 15.00), (97, 18, 2, 32.00), (98, 24, 1, 27.00), (99, 24, 5, 27.00),
(99, 22, 1, 24.00), (100, 3, 3, 25.00), (101, 10, 4, 26.00), (101, 3, 2, 25.00), (101, 18, 6, 32.00),
(102, 12, 2, 17.00), (103, 14, 5, 15.00), (103, 28, 3, 21.00), (104, 15, 2, 20.00), (104, 8, 4, 15.00),
(105, 1, 6, 18.00), (105, 18, 3, 32.00), (106, 6, 6, 19.00), (106, 16, 3, 12.00), (106, 12, 3, 17.00),
(107, 6, 2, 19.00), (108, 1, 6, 18.00), (108, 28, 2, 21.00), (109, 1, 2, 18.00), (109, 28, 3, 21.00);

-- ---------------------------------------------------------------------
-- Ventas: una por cada pedido Entregado + las de mostrador, en orden cronológico
-- ---------------------------------------------------------------------
INSERT INTO ventas (id_pedido, id_cliente, id_usuario, fecha_venta, total, forma_pago)
SELECT t.id_pedido, t.id_cliente, t.id_usuario, t.fecha, t.total, t.forma_pago
FROM (
  SELECT p.id_pedido AS id_pedido, p.id_cliente AS id_cliente, p.id_usuario_registro AS id_usuario,
         p.fecha_entrega AS fecha, p.total AS total, p.forma_pago AS forma_pago
  FROM pedidos p
  WHERE p.estado = 'Entregada'
  UNION ALL
  SELECT NULL, m.id_cliente, m.id_usuario, m.fecha_venta, m.total, m.forma_pago
  FROM _seed_mostrador m
  WHERE m.fecha_venta <= @ahora
) t
ORDER BY t.fecha, t.id_cliente;

INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
SELECT v.id_venta, dp.id_producto, dp.cantidad, dp.precio_unitario
FROM ventas v
JOIN detalle_pedido dp ON dp.id_pedido = v.id_pedido
ORDER BY v.id_venta, dp.id_detalle;

INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
SELECT v.id_venta, d.id_producto, d.cantidad, d.precio_unitario
FROM ventas v
JOIN _seed_mostrador m ON m.fecha_venta = v.fecha_venta AND m.id_cliente = v.id_cliente
JOIN _seed_mostrador_det d ON d.k = m.k
WHERE v.id_pedido IS NULL
ORDER BY v.id_venta, d.id_producto;

DROP TABLE _seed_mostrador_det;
DROP TABLE _seed_mostrador;

-- ---------------------------------------------------------------------
-- Facturas: ventas de clientes con RFC (se omite 1 de cada 5 a propósito, y de las
-- ventas de HOY solo se factura la mitad, para que haya ventas por facturar en vivo).
-- El folio usa el mismo formato que genera el sistema (0001, 0002, ...).
-- ---------------------------------------------------------------------
INSERT INTO facturas (serie, folio, uuid, sello_emisor, sello_sat, id_venta, id_cliente, fecha_emision, total)
SELECT 'F',
       LPAD(ROW_NUMBER() OVER (ORDER BY x.emision, x.id_venta), 4, '0'),
       UPPER(UUID()),
       CONCAT(TO_BASE64(UNHEX(SHA2(CONCAT('emisor-', x.id_venta), 256))), '=='),
       CONCAT(TO_BASE64(UNHEX(SHA2(CONCAT('sat-', x.id_venta), 256))), '=='),
       x.id_venta,
       x.id_cliente,
       x.emision,
       x.total
FROM (
  SELECT v.id_venta, v.id_cliente, v.total, v.fecha_venta,
         TIMESTAMPADD(MINUTE, 5 + (v.id_venta % 7) * 9, v.fecha_venta) AS emision
  FROM ventas v
  JOIN clientes c ON c.id_cliente = v.id_cliente
  WHERE c.rfc IS NOT NULL
    AND v.id_venta % 5 <> 0
) x
WHERE x.emision <= @ahora
  AND (x.fecha_venta < @hoy OR x.id_venta % 2 = 1)
ORDER BY x.emision, x.id_venta;

-- El siguiente folio disponible depende de cuántas facturas se emitieron
UPDATE empresa_emisor
SET folio_siguiente = (SELECT COUNT(*) + 1 FROM facturas)
WHERE id_empresa = 1;

-- ---------------------------------------------------------------------
-- Movimientos de inventario
-- stock_resultante se calcula al final con una suma acumulada, y
-- stock_actual de productos sale de la suma de todos los movimientos.
-- ---------------------------------------------------------------------

-- Inventario inicial (domingo 8), reabastos, mermas, devoluciones y ajustes
INSERT INTO movimientos_inventario (id_producto, tipo, cantidad, stock_resultante, id_usuario, motivo, fecha_movimiento) VALUES
(1, 'Entrada', 80, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(2, 'Entrada', 120, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(3, 'Entrada', 140, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(4, 'Entrada', 140, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(5, 'Entrada', 45, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(6, 'Entrada', 80, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(7, 'Entrada', 160, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(8, 'Entrada', 80, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(9, 'Entrada', 100, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(10, 'Entrada', 160, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(11, 'Entrada', 40, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(12, 'Entrada', 120, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(13, 'Entrada', 60, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(14, 'Entrada', 80, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(15, 'Entrada', 160, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(16, 'Entrada', 120, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(17, 'Entrada', 36, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(18, 'Entrada', 160, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(19, 'Entrada', 120, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(20, 'Entrada', 20, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(21, 'Entrada', 160, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(22, 'Entrada', 160, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(23, 'Entrada', 140, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(24, 'Entrada', 100, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(25, 'Entrada', 120, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(26, 'Entrada', 140, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(27, 'Entrada', 160, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(28, 'Entrada', 80, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(29, 'Entrada', 140, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(30, 'Entrada', 120, 0, 1, 'Inventario inicial', '2026-11-08 07:00:00'),
(8, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-10 07:20:00'),
(20, 'Ajuste', -20, 0, 1, 'Producto descontinuado, baja del almacén', '2026-11-10 10:00:00'),
(23, 'Merma', -9, 0, 1, 'Empaques rotos en bodega', '2026-11-10 17:22:00'),
(14, 'Devolucion', 2, 0, 4, 'Devolución de cliente (empaque dañado)', '2026-11-10 18:28:00'),
(6, 'Entrada', 100, 0, 4, 'Compra a proveedor', '2026-11-11 07:00:00'),
(14, 'Entrada', 100, 0, 1, 'Reabasto por alta demanda', '2026-11-11 07:00:00'),
(24, 'Entrada', 100, 0, 4, 'Compra a proveedor', '2026-11-11 07:00:00'),
(1, 'Entrada', 120, 0, 4, 'Reabasto por alta demanda', '2026-11-11 07:30:00'),
(23, 'Merma', -5, 0, 4, 'Producto caducado', '2026-11-11 17:28:00'),
(3, 'Entrada', 100, 0, 1, 'Reabasto por alta demanda', '2026-11-12 07:10:00'),
(23, 'Entrada', 100, 0, 1, 'Reabasto por alta demanda', '2026-11-12 07:30:00'),
(15, 'Merma', -3, 0, 4, 'Producto caducado', '2026-11-12 17:14:00'),
(25, 'Merma', -4, 0, 1, 'Empaques rotos en bodega', '2026-11-12 17:48:00'),
(30, 'Devolucion', 1, 0, 1, 'Devolución de cliente (empaque dañado)', '2026-11-12 18:47:00'),
(18, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-13 07:00:00'),
(2, 'Entrada', 100, 0, 4, 'Reabasto por alta demanda', '2026-11-13 07:10:00'),
(19, 'Entrada', 100, 0, 1, 'Compra a proveedor', '2026-11-13 07:10:00'),
(1, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-13 07:20:00'),
(4, 'Entrada', 100, 0, 4, 'Compra a proveedor', '2026-11-13 07:30:00'),
(6, 'Merma', -5, 0, 1, 'Empaques rotos en bodega', '2026-11-13 17:43:00'),
(6, 'Entrada', 120, 0, 1, 'Reabasto semanal', '2026-11-14 07:00:00'),
(7, 'Entrada', 100, 0, 4, 'Reabasto semanal', '2026-11-14 07:00:00'),
(8, 'Entrada', 80, 0, 4, 'Reabasto por alta demanda', '2026-11-14 07:00:00'),
(28, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-14 07:10:00'),
(2, 'Devolucion', 4, 0, 4, 'Devolución de cliente (empaque dañado)', '2026-11-14 18:45:00'),
(14, 'Entrada', 120, 0, 1, 'Compra a proveedor', '2026-11-15 07:00:00'),
(1, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-15 07:10:00'),
(30, 'Entrada', 80, 0, 4, 'Reabasto por alta demanda', '2026-11-15 07:10:00'),
(3, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-15 07:20:00'),
(21, 'Entrada', 100, 0, 1, 'Reabasto semanal', '2026-11-15 07:20:00'),
(22, 'Entrada', 100, 0, 4, 'Reabasto por alta demanda', '2026-11-16 07:00:00'),
(8, 'Entrada', 100, 0, 1, 'Reabasto semanal', '2026-11-16 07:20:00'),
(2, 'Entrada', 100, 0, 4, 'Reabasto semanal', '2026-11-16 07:30:00'),
(10, 'Entrada', 100, 0, 4, 'Reabasto por alta demanda', '2026-11-16 07:30:00'),
(26, 'Merma', -2, 0, 4, 'Empaques rotos en bodega', '2026-11-16 17:54:00'),
(25, 'Devolucion', 2, 0, 1, 'Devolución de cliente (empaque dañado)', '2026-11-16 18:52:00'),
(4, 'Entrada', 80, 0, 1, 'Reabasto semanal', '2026-11-17 07:00:00'),
(15, 'Entrada', 100, 0, 1, 'Compra a proveedor', '2026-11-17 07:00:00'),
(16, 'Entrada', 120, 0, 1, 'Reabasto semanal', '2026-11-17 07:00:00'),
(25, 'Entrada', 100, 0, 1, 'Compra a proveedor', '2026-11-17 07:00:00'),
(18, 'Entrada', 80, 0, 4, 'Reabasto por alta demanda', '2026-11-17 07:10:00'),
(3, 'Entrada', 120, 0, 1, 'Compra a proveedor', '2026-11-17 07:30:00'),
(23, 'Entrada', 120, 0, 4, 'Compra a proveedor', '2026-11-17 07:30:00'),
(14, 'Merma', -5, 0, 1, 'Bolsas abiertas durante el traslado', '2026-11-17 17:19:00'),
(16, 'Merma', -3, 0, 4, 'Bolsas abiertas durante el traslado', '2026-11-17 17:52:00'),
(4, 'Devolucion', 3, 0, 4, 'Devolución de cliente (empaque dañado)', '2026-11-17 18:51:00'),
(3, 'Entrada', 100, 0, 1, 'Compra a proveedor', '2026-11-18 07:00:00'),
(6, 'Entrada', 80, 0, 1, 'Reabasto por alta demanda', '2026-11-18 07:00:00'),
(8, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-18 07:00:00'),
(21, 'Entrada', 100, 0, 4, 'Reabasto por alta demanda', '2026-11-18 07:10:00');

INSERT INTO movimientos_inventario (id_producto, tipo, cantidad, stock_resultante, id_usuario, motivo, fecha_movimiento) VALUES
(26, 'Entrada', 120, 0, 4, 'Reabasto semanal', '2026-11-18 07:10:00'),
(4, 'Entrada', 80, 0, 4, 'Reabasto semanal', '2026-11-18 07:20:00'),
(29, 'Entrada', 80, 0, 4, 'Reabasto por alta demanda', '2026-11-18 07:20:00'),
(1, 'Entrada', 100, 0, 4, 'Reabasto semanal', '2026-11-18 07:30:00'),
(9, 'Entrada', 100, 0, 4, 'Reabasto por alta demanda', '2026-11-18 07:30:00'),
(12, 'Entrada', 80, 0, 4, 'Reabasto por alta demanda', '2026-11-18 07:30:00'),
(9, 'Merma', -2, 0, 1, 'Caja dañada por humedad', '2026-11-18 17:56:00'),
(30, 'Devolucion', 1, 0, 4, 'Devolución de cliente (empaque dañado)', '2026-11-18 18:23:00'),
(19, 'Entrada', 120, 0, 4, 'Reabasto por alta demanda', '2026-11-19 07:00:00'),
(24, 'Entrada', 80, 0, 4, 'Compra a proveedor', '2026-11-19 07:00:00'),
(27, 'Entrada', 120, 0, 1, 'Compra a proveedor', '2026-11-19 07:00:00'),
(15, 'Entrada', 80, 0, 4, 'Compra a proveedor', '2026-11-19 07:10:00'),
(25, 'Entrada', 100, 0, 4, 'Reabasto semanal', '2026-11-19 07:10:00'),
(6, 'Entrada', 80, 0, 1, 'Reabasto semanal', '2026-11-19 07:20:00'),
(23, 'Entrada', 80, 0, 1, 'Reabasto semanal', '2026-11-19 07:30:00'),
(4, 'Merma', -9, 0, 4, 'Producto aplastado en la ruta', '2026-11-19 17:53:00'),
(12, 'Devolucion', 3, 0, 1, 'Devolución de cliente (empaque dañado)', '2026-11-19 18:49:00'),
(10, 'Entrada', 120, 0, 1, 'Compra a proveedor', '2026-11-20 07:00:00'),
(14, 'Entrada', 80, 0, 4, 'Reabasto por alta demanda', '2026-11-20 07:00:00'),
(22, 'Entrada', 100, 0, 1, 'Compra a proveedor', '2026-11-20 07:00:00'),
(1, 'Entrada', 120, 0, 1, 'Reabasto por alta demanda', '2026-11-20 07:10:00'),
(4, 'Entrada', 100, 0, 4, 'Compra a proveedor', '2026-11-20 07:20:00'),
(2, 'Entrada', 120, 0, 1, 'Compra a proveedor', '2026-11-20 07:30:00'),
(18, 'Entrada', 80, 0, 4, 'Reabasto por alta demanda', '2026-11-20 07:30:00'),
(28, 'Entrada', 100, 0, 1, 'Compra a proveedor', '2026-11-20 07:30:00'),
(8, 'Merma', -6, 0, 4, 'Empaques rotos en bodega', '2026-11-20 17:40:00');

-- Los movimientos que aún no ocurren no se conservan
DELETE FROM movimientos_inventario WHERE fecha_movimiento > @ahora;
ALTER TABLE movimientos_inventario AUTO_INCREMENT = 1;

-- Salidas por cada venta (pedidos entregados + mostrador)
INSERT INTO movimientos_inventario (id_producto, tipo, cantidad, stock_resultante, id_pedido, id_venta, id_usuario, motivo, fecha_movimiento)
SELECT dv.id_producto,
       'Venta',
       -dv.cantidad,
       0,
       v.id_pedido,
       v.id_venta,
       v.id_usuario,
       CONCAT('Descuento automático por Venta #', v.id_venta,
              IF(v.id_pedido IS NULL, '', CONCAT(' / Pedido #', v.id_pedido))),
       v.fecha_venta
FROM detalle_venta dv
JOIN ventas v ON v.id_venta = dv.id_venta
ORDER BY v.fecha_venta, v.id_venta, dv.id_detalle;

-- stock_resultante = suma acumulada por producto en orden cronológico
UPDATE movimientos_inventario m
JOIN (
  SELECT id_movimiento,
         SUM(cantidad) OVER (PARTITION BY id_producto ORDER BY fecha_movimiento, id_movimiento) AS acumulado
  FROM movimientos_inventario
) x ON x.id_movimiento = m.id_movimiento
SET m.stock_resultante = x.acumulado;

-- stock_actual de cada producto = suma de todos sus movimientos
UPDATE productos p
SET p.stock_actual = (
  SELECT COALESCE(SUM(m.cantidad), 0)
  FROM movimientos_inventario m
  WHERE m.id_producto = p.id_producto
);

-- ---------------------------------------------------------------------
-- Cortes diarios (uno por cada día anterior a hoy con ventas).
-- El día de hoy queda SIN corte para poder cerrarlo desde el sistema.
-- ---------------------------------------------------------------------
INSERT INTO cortes_diarios
  (fecha_corte, total_efectivo, total_tarjeta, total_transferencia, num_ventas, total_ventas,
   num_facturas, pedidos_entregados, pedidos_no_entregados, id_usuario_genera, fecha_generacion)
SELECT t.dia,
       SUM(CASE WHEN t.forma_pago = 'Efectivo'      THEN t.total ELSE 0 END),
       SUM(CASE WHEN t.forma_pago = 'Tarjeta'       THEN t.total ELSE 0 END),
       SUM(CASE WHEN t.forma_pago = 'Transferencia' THEN t.total ELSE 0 END),
       COUNT(*),
       SUM(t.total),
       COUNT(t.id_factura),
       (SELECT COUNT(*) FROM pedidos p
         WHERE p.estado = 'Entregada' AND DATE(p.fecha_entrega) = t.dia),
       (SELECT COUNT(*) FROM pedidos p
         WHERE p.estado IN ('No entregada','Rechazada') AND DATE(p.fecha_actualizacion) = t.dia),
       CASE WHEN DAYOFMONTH(t.dia) % 3 = 0 THEN 4 ELSE 1 END,
       TIMESTAMPADD(MINUTE, (DAYOFMONTH(t.dia) * 17) % 90, TIMESTAMP(t.dia, '19:30:00'))
FROM (
  SELECT DATE(v.fecha_venta) AS dia, v.forma_pago, v.total, f.id_factura
  FROM ventas v
  LEFT JOIN facturas f ON f.id_venta = v.id_venta
  WHERE DATE(v.fecha_venta) < @hoy
) t
GROUP BY t.dia
ORDER BY t.dia;

SET SQL_SAFE_UPDATES = 1;

-- =====================================================================
--  3. CONSULTAS DE VERIFICACIÓN (opcionales)
-- =====================================================================
-- Resumen de lo que quedó cargado:
--   SELECT (SELECT COUNT(*) FROM pedidos) AS pedidos, (SELECT COUNT(*) FROM ventas) AS ventas,
--          (SELECT COUNT(*) FROM facturas) AS facturas, (SELECT COUNT(*) FROM cortes_diarios) AS cortes;
--
-- Ventas por día:
--   SELECT DATE(fecha_venta) AS dia, COUNT(*) AS ventas, SUM(total) AS monto FROM ventas GROUP BY dia ORDER BY dia;
--
-- Productos por debajo del stock mínimo:
--   SELECT codigo, nombre, stock_actual, stock_minimo FROM productos
--   WHERE activo = 1 AND stock_actual < stock_minimo;
--
-- Pedidos por estado:
--   SELECT estado, COUNT(*) AS pedidos, SUM(total) AS monto FROM pedidos GROUP BY estado;
--
-- Cortes diarios:
--   SELECT * FROM cortes_diarios ORDER BY fecha_corte DESC;
