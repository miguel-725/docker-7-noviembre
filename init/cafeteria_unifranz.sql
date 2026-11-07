-- Configuración inicial
SET client_encoding = 'UTF8';
SET standard_conforming_strings = ON;
SET check_function_bodies = false;

-- ==========================================
-- CREACIÓN DE FUNCIONES Y SECUENCIAS
-- ==========================================

CREATE SEQUENCE public.ticket_numero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 99
    CACHE 1
    CYCLE;

CREATE FUNCTION public.siguiente_ticket() RETURNS character varying
    LANGUAGE plpgsql
    AS $$ DECLARE candidato varchar; intentos integer := 0; BEGIN LOOP candidato := lpad(nextval('ticket_numero_seq')::text, 2, '0'); IF NOT EXISTS ( SELECT 1 FROM pedidos WHERE ticket_numero = candidato AND estado IN ('PENDIENTE', 'EN_PREPARACION', 'LISTO') AND eliminado_cuando IS NULL ) THEN RETURN candidato; END IF; intentos := intentos + 1; IF intentos >= 99 THEN RAISE EXCEPTION 'No hay tickets disponibles'; END IF; END LOOP; END; $$;

CREATE SEQUENCE public.bloques_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.categorias_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.detalle_pedido_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.detalle_pedidos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.empleados_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.historial_estados_pedido_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.inventario_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.notificaciones_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.pagos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.pedidos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.productos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.receta_productos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.turnos_menu_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
CREATE SEQUENCE public.usuarios_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

-- ==========================================
-- CREACIÓN DE TABLAS Y RESTRICCIONES
-- ==========================================

CREATE TABLE public.bloques (
    id integer NOT NULL DEFAULT nextval('public.bloques_id_seq'::regclass),
    nombre character varying(50) NOT NULL,
    CONSTRAINT bloques_pkey PRIMARY KEY (id),
    CONSTRAINT bloques_nombre_key UNIQUE (nombre)
);
ALTER SEQUENCE public.bloques_id_seq OWNED BY public.bloques.id;

CREATE TABLE public.categorias (
    id bigint NOT NULL DEFAULT nextval('public.categorias_id_seq'::regclass),
    nombre character varying(80) NOT NULL,
    descripcion text,
    CONSTRAINT categorias_pkey PRIMARY KEY (id),
    CONSTRAINT categorias_nombre_key UNIQUE (nombre)
);
ALTER SEQUENCE public.categorias_id_seq OWNED BY public.categorias.id;

CREATE TABLE public.bloques_referencia_aux (id int); -- Aux para dependencias si aplica

CREATE TABLE public.usuarios (
    id integer NOT NULL DEFAULT nextval('public.usuarios_id_seq'::regclass),
    nombre_completo character varying(120) NOT NULL,
    email character varying(150) NOT NULL,
    password_hash character varying(255) NOT NULL,
    rol character varying(30) NOT NULL,
    telefono character varying(20),
    creado_cuando timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    creado_por character varying(100),
    modificado_por character varying(100),
    modificado_cuando timestamp without time zone,
    eliminado_por character varying(100),
    eliminado_cuando timestamp without time zone,
    bloque_id integer,
    CONSTRAINT usuarios_pkey PRIMARY KEY (id),
    CONSTRAINT usuarios_email_key UNIQUE (email),
    CONSTRAINT check_roles_validos CHECK (((rol)::text = ANY ((ARRAY['ADMIN'::character varying, 'CAJERO'::character varying, 'COCINA'::character varying, 'CLIENTE'::character varying, 'PANTALLA'::character varying])::text[]))),
    CONSTRAINT usuarios_bloque_id_fkey FOREIGN KEY (bloque_id) REFERENCES public.bloques(id)
);
ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.usuarios.id;

CREATE TABLE public.productos (
    id bigint NOT NULL DEFAULT nextval('public.productos_id_seq'::regclass),
    categoria_id bigint NOT NULL,
    nombre character varying(120) NOT NULL,
    descripcion character varying(500),
    precio numeric(10,2) NOT NULL,
    imagen_url character varying(1000),
    disponible boolean DEFAULT true,
    menu_del_dia boolean DEFAULT false,
    creado_cuando timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    creado_por character varying(100),
    modificado_por character varying(100),
    modificado_cuando timestamp without time zone,
    eliminado_por character varying(100),
    eliminado_cuando timestamp without time zone,
    bloque character varying(20) DEFAULT 'AMBOS'::character varying NOT NULL,
    CONSTRAINT productos_pkey PRIMARY KEY (id),
    CONSTRAINT productos_precio_check CHECK ((precio >= (0)::numeric)),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id) REFERENCES public.categorias(id) ON DELETE CASCADE
);
ALTER SEQUENCE public.productos_id_seq OWNED BY public.productos.id;

CREATE TABLE public.inventario (
    id integer NOT NULL DEFAULT nextval('public.inventario_id_seq'::regclass),
    bloque_id integer NOT NULL,
    nombre_insumo character varying(100) NOT NULL,
    cantidad_actual numeric(10,2) NOT NULL,
    unidad_medida character varying(20) NOT NULL,
    stock_minimo numeric(10,2) DEFAULT 5.0 NOT NULL,
    creado_por character varying(100),
    creado_cuando timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    modificado_por character varying(100),
    modificado_cuando timestamp without time zone,
    eliminado_por character varying(100),
    eliminado_cuando timestamp without time zone,
    CONSTRAINT inventario_pkey PRIMARY KEY (id),
    CONSTRAINT inventario_cantidad_actual_check CHECK ((cantidad_actual >= (0)::numeric)),
    CONSTRAINT fk_inventario_bloque FOREIGN KEY (bloque_id) REFERENCES public.bloques(id) ON DELETE CASCADE
);
ALTER SEQUENCE public.inventario_id_seq OWNED BY public.inventario.id;

CREATE TABLE public.receta_productos (
    id integer NOT NULL DEFAULT nextval('public.receta_productos_id_seq'::regclass),
    producto_id integer NOT NULL,
    inventario_id integer NOT NULL,
    cantidad_requerida numeric(10,2) NOT NULL,
    CONSTRAINT receta_productos_pkey PRIMARY KEY (id),
    CONSTRAINT receta_productos_cantidad_requerida_check CHECK ((cantidad_requerida > (0)::numeric)),
    CONSTRAINT fk_receta_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE,
    CONSTRAINT fk_receta_inventario FOREIGN KEY (inventario_id) REFERENCES public.inventario(id) ON DELETE CASCADE
);
ALTER SEQUENCE public.receta_productos_id_seq OWNED BY public.receta_productos.id;

CREATE TABLE public.pedidos (
    id bigint NOT NULL DEFAULT nextval('public.pedidos_id_seq'::regclass),
    ticket_numero character varying(30) DEFAULT public.siguiente_ticket() NOT NULL,
    usuario_id bigint NOT NULL,
    bloque_id integer NOT NULL,
    origen_pedido character varying(30) NOT NULL,
    estado character varying(30) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    monto_total numeric(12,2) NOT NULL,
    tiempo_espera_minutos integer DEFAULT 15,
    creado_cuando timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    modificado_cuando timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    creado_por character varying(100),
    modificado_por character varying(100),
    eliminado_por character varying(100),
    eliminado_cuando timestamp without time zone,
    fecha_creacion timestamp(6) without time zone NOT NULL,
    cliente_id bigint,
    numero_pedido character varying(30),
    metodo_pago character varying(20),
    modalidad_servicio character varying(20),
    expira_cuando timestamp(6) without time zone,
    estado_pago character varying(20),
    CONSTRAINT pedidos_pkey PRIMARY KEY (id),
    CONSTRAINT uk6ywv5771tibn93splh6t3ft06 UNIQUE (numero_pedido),
    CONSTRAINT pedidos_monto_total_check CHECK ((monto_total >= (0)::numeric)),
    CONSTRAINT pedidos_estado_check CHECK (((estado)::text = ANY (ARRAY[('PENDIENTE'::character varying)::text, ('EN_PREPARACION'::character varying)::text, ('LISTO'::character varying)::text, ('ENTREGADO'::character varying)::text, ('CANCELADO'::character varying)::text]))),
    CONSTRAINT pedidos_origen_pedido_check CHECK (((origen_pedido)::text = ANY (ARRAY[('WEB_MOVIL'::character varying)::text, ('PANTALLA_TACTIL'::character varying)::text, ('CAJA'::character varying)::text]))),
    CONSTRAINT fk_pedido_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pedido_bloque FOREIGN KEY (bloque_id) REFERENCES public.bloques(id) ON DELETE RESTRICT
);
ALTER SEQUENCE public.pedidos_id_seq OWNED BY public.pedidos.id;

CREATE TABLE public.detalle_pedido (
    id bigint NOT NULL GENERATED BY DEFAULT AS IDENTITY (SEQUENCE NAME public.detalle_pedido_id_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1),
    nombre_producto character varying(120) NOT NULL,
    cantidad integer NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    pedido_id bigint NOT NULL,
    producto_id bigint NOT NULL,
    CONSTRAINT detalle_pedido_pkey PRIMARY KEY (id),
    CONSTRAINT fkg9h17fjynh9lgf1kbn0v9p4kf FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id),
    CONSTRAINT fkdfdl21316mnac14d7f4oi4m84 FOREIGN KEY (producto_id) REFERENCES public.productos(id)
);

CREATE TABLE public.detalle_pedidos (
    id bigint NOT NULL DEFAULT nextval('public.detalle_pedidos_id_seq'::regclass),
    pedido_id bigint NOT NULL,
    producto_id bigint NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    nombre_producto character varying(120) NOT NULL,
    CONSTRAINT detalle_pedidos_pkey PRIMARY KEY (id),
    CONSTRAINT detalle_pedidos_cantidad_check CHECK ((cantidad > 0)),
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE RESTRICT
);
ALTER SEQUENCE public.detalle_pedidos_id_seq OWNED BY public.detalle_pedidos.id;

CREATE TABLE public.empleados (
    id integer NOT NULL DEFAULT nextval('public.empleados_id_seq'::regclass),
    nombre character varying(120) NOT NULL,
    cargo character varying(50) NOT NULL,
    bloque character varying(20) DEFAULT 'BLOQUE_A'::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_cuando timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    creado_por character varying(100),
    modificado_por character varying(100),
    modificado_cuando timestamp without time zone,
    eliminado_por character varying(100),
    eliminado_cuando timestamp without time zone,
    CONSTRAINT empleados_pkey PRIMARY KEY (id)
);
ALTER SEQUENCE public.empleados_id_seq OWNED BY public.empleados.id;

CREATE TABLE public.historial_estados_pedido (
    id integer NOT NULL DEFAULT nextval('public.historial_estados_pedido_id_seq'::regclass),
    pedido_id integer NOT NULL,
    estado_anterior character varying(20),
    estado_nuevo character varying(20) NOT NULL,
    cambiado_por_usuario_id integer,
    fecha_cambio timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT historial_estados_pedido_pkey PRIMARY KEY (id),
    CONSTRAINT fk_historial_pedido FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE CASCADE,
    CONSTRAINT fk_historial_usuario FOREIGN KEY (cambiado_por_usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL
);
ALTER SEQUENCE public.historial_estados_pedido_id_seq OWNED BY public.historial_estados_pedido.id;

CREATE TABLE public.notificaciones (
    id integer NOT NULL DEFAULT nextval('public.notificaciones_id_seq'::regclass),
    usuario_id integer NOT NULL,
    pedido_id integer NOT NULL,
    mensaje text NOT NULL,
    leido boolean DEFAULT false,
    enviado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT notificaciones_pkey PRIMARY KEY (id),
    CONSTRAINT fk_notif_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE,
    CONSTRAINT fk_notif_pedido FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE CASCADE
);
ALTER SEQUENCE public.notificaciones_id_seq OWNED BY public.notificaciones.id;

CREATE TABLE public.pagos (
    id integer NOT NULL DEFAULT nextval('public.pagos_id_seq'::regclass),
    pedido_id integer NOT NULL,
    metodo_pago character varying(20) NOT NULL,
    estado_pago character varying(20) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    referencia_transaccion character varying(100),
    monto numeric(10,2) NOT NULL,
    fecha_pago timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pagos_pkey PRIMARY KEY (id),
    CONSTRAINT pagos_pedido_id_key UNIQUE (pedido_id),
    CONSTRAINT pagos_estado_pago_check CHECK (((estado_pago)::text = ANY (ARRAY[('PENDIENTE'::character varying)::text, ('COMPLETADO'::character varying)::text, ('RECHAZADO'::character varying)::text]))),
    CONSTRAINT pagos_metodo_pago_check CHECK (((metodo_pago)::text = ANY (ARRAY[('QR'::character varying)::text, ('EFECTIVO'::character varying)::text, ('TARJETA'::character varying)::text])))
);
ALTER SEQUENCE public.pagos_id_seq OWNED BY public.pagos.id;

CREATE TABLE public.turnos_menu (
    id integer NOT NULL DEFAULT nextval('public.turnos_menu_id_seq'::regclass),
    nombre_turno character varying(50) NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    CONSTRAINT turnos_menu_pkey PRIMARY KEY (id)
);
ALTER SEQUENCE public.turnos_menu_id_seq OWNED BY public.turnos_menu.id;

-- ==========================================
-- INSERCIÓN DE DATOS (INSERTS)
-- ==========================================

INSERT INTO public.usuarios (id, nombre_completo, email, password_hash, rol, telefono, creado_cuando, creado_por, modificado_por, modificado_cuando, eliminado_por, eliminado_cuando, bloque_id) VALUES 
(12, 'Administrador General', 'admin1@cafeteria.com', '$2b$10$s.0C4/OqsnJXRozoNxMcvu6WQTDoAMdZsLuxx8x42uL8hVDpJAPMG', 'ADMIN', '70000051', '2026-10-16 16:51:05.474467', 'seed', NULL, NULL, NULL, NULL, NULL),
(14, 'Clara Cliente', 'cliente1@cafeteria.com', '$2b$10$pCcEzITI2Xa/fP1jQoCVYuQYsSPYf.vDHjLsMfzFESkFJsyiRATuK', 'CLIENTE', '70000203', '2026-10-16 16:51:05.474467', 'seed', NULL, NULL, NULL, NULL, NULL),
(15, 'Pantalla Bloque A', 'pantalla1@cafeteria.com', '$2b$10$Y3pwkNOWk7RFhZkhuV9XmOQ0ZRH3DOoT0Qr81RcANTZcwlb3dgBYa', 'PANTALLA', '70230004', '2026-10-16 16:51:05.474467', 'seed', NULL, NULL, NULL, NULL, NULL),
(16, 'Jose andrade', 'jose@gmail.com', '$2a$10$vvGFCFRkFHQJK4qFQ8KdzOGJRPDyD1NgvYRrO/G99YB6QS3tEM68G', 'CLIENTE', NULL, '2026-10-16 20:29:56.624792', NULL, NULL, NULL, NULL, NULL, NULL),
(13, 'Carlos Cajero', 'cajero1@cafeteria.com', '$2b$10$5YBhMfpAvoACYpPGgdVhXOjq3/jHz5Se32dNvajCS.u6LSf1zDEUO', 'CAJERO', '70000032', '2026-10-16 16:51:05.474467', 'seed', NULL, NULL, NULL, NULL, 1),
(9, 'Cliente Prueba', 'cliente@cafeteria.com', '$2a$10$SBSf084F19qJcWSMxDMVN.ZyKR0kdN7Bs9DlexJyLPyP/BNuZXQ8O', 'CLIENTE', '70000001', '2026-10-16 14:32:54.087360', NULL, NULL, NULL, NULL, NULL, NULL),
(11, 'Cajero Turno', 'cajero@cafeteria.com', '$2a$10$SBSf084F19qJcWSMxDMVN.ZyKR0kdN7Bs9DlexJyLPyP/BNuZXQ8O', 'CAJERO', '70000002', '2026-10-16 14:34:34.861419', NULL, NULL, NULL, NULL, NULL, 2),
(17, 'Cajero Bloque A', 'cajero.a@cafeteria.com', '$2a$10$SBSf084F19qJcWSMxDMVN.ZyKR0kdN7Bs9DlexJyLPyP/BNuZXQ8O', 'CAJERO', NULL, '2026-10-17 00:53:03.093413', 'seed', NULL, NULL, NULL, NULL, 1),
(18, 'Cajero Bloque B', 'cajero.b@cafeteria.com', '$2a$10$SBSf084F19qJcWSMxDMVN.ZyKR0kdN7Bs9DlexJyLPyP/BNuZXQ8O', 'CAJERO', NULL, '2026-10-17 00:53:03.095912', 'seed', NULL, NULL, NULL, NULL, 2),
(19, 'julian alvarez', 'aldo@gmail.com', '$2a$10$BeOWCkz0jSJRq4oV2ddzj.lRf/u.Zj4aXHedM27C5PMkSSi/rJ6cS', 'CLIENTE', NULL, '2026-10-17 03:50:04.251199', NULL, NULL, NULL, NULL, NULL, NULL),
(20, 'jose carlos', 'jos@gmail.com', '$2a$10$hdRcXbWpoBD/2Qns3yHyyeB.tD44BqH/Qzy1FVZTbC0N9QfY7h0yK', 'CLIENTE', NULL, '2026-10-17 09:49:36.157658', NULL, NULL, NULL, NULL, NULL, NULL),
(21, 'CRISTIAN ANTEZANA APAZA', 'lpze.cristian.antezana.ap@unifranz.edu.bo', '$2a$10$590NBvqAYx6CNv0wzf/81uTYrZL1XG//x/pBY/OY.e.66MEGIBQfC', 'CLIENTE', NULL, '2026-10-31 06:20:13.331623', NULL, NULL, NULL, NULL, NULL, NULL);

INSERT INTO public.bloques (id, nombre) VALUES 
(1, 'Bloque A'),
(2, 'Bloque B');

INSERT INTO public.categorias (id, nombre, descripcion) VALUES 
(3, 'refrescos', 'categoria refrescos');

INSERT INTO public.productos (id, categoria_id, nombre, descripcion, precio, imagen_url, disponible, menu_del_dia, creado_cuando, creado_por, modificado_por, modificado_cuando, eliminado_por, eliminado_cuando, bloque) VALUES 
(3, 3, 'coca cola', NULL, 4.00, NULL, true, true, '2026-10-17 08:36:36.563403', NULL, NULL, NULL, NULL, NULL, 'AMBOS');

-- ==========================================
-- RESTABLECER VALORES DE SECUENCIAS
-- ==========================================

SELECT pg_catalog.setval('public.bloques_id_seq', 2, true);
SELECT pg_catalog.setval('public.categorias_id_seq', 3, true);
SELECT pg_catalog.setval('public.detalle_pedido_id_seq', 1, false);
SELECT pg_catalog.setval('public.detalle_pedidos_id_seq', 1, false);
SELECT pg_catalog.setval('public.empleados_id_seq', 1, false);
SELECT pg_catalog.setval('public.historial_estados_pedido_id_seq', 1, false);
SELECT pg_catalog.setval('public.inventario_id_seq', 1, false);
SELECT pg_catalog.setval('public.notificaciones_id_seq', 1, false);
SELECT pg_catalog.setval('public.pagos_id_seq', 1, false);
SELECT pg_catalog.setval('public.pedidos_id_seq', 31, true);
SELECT pg_catalog.setval('public.productos_id_seq', 4, true);
SELECT pg_catalog.setval('public.receta_productos_id_seq', 1, false);
SELECT pg_catalog.setval('public.ticket_numero_seq', 11, true);
SELECT pg_catalog.setval('public.turnos_menu_id_seq', 1, false);
SELECT pg_catalog.setval('public.usuarios_id_seq', 21, true);