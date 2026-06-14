/*
============================================================
 PROYECTO FINAL BASES DE DATOS 2026-10
 Sistema: Cuenta Corriente del Estudiante
 Motor RDBMS: PostgreSQL
 Entregable #3: Script DDL
 Versión: snake_case sin comillas dobles


 Nota de nomenclatura:
 - Se usa snake_case sin comillas dobles, convención recomendada
   para PostgreSQL y para evitar discrepancias en consultas.
============================================================
*/

-- ============================================================
-- 0. LIMPIEZA OPCIONAL DEL ESQUEMA
-- ============================================================

DROP VIEW IF EXISTS vista_creditos_financieros CASCADE;
DROP VIEW IF EXISTS vista_estudiantes_pendientes_pago CASCADE;
DROP VIEW IF EXISTS vista_ingreso_real CASCADE;
DROP VIEW IF EXISTS vista_ingreso_esperado CASCADE;
DROP VIEW IF EXISTS vista_resumen_estudiantes CASCADE;
DROP VIEW IF EXISTS vista_balance_cuenta_corriente CASCADE;

DROP TRIGGER IF EXISTS trg_pago_movimiento          ON pago;
DROP TRIGGER IF EXISTS trg_detalle_volante_cobro    ON detalle_volante;
DROP TRIGGER IF EXISTS trg_volante_crear_cuenta     ON volante_matricula;

DROP FUNCTION IF EXISTS fn_registrar_movimiento_pago();
DROP FUNCTION IF EXISTS fn_detalle_volante_movimiento();
DROP FUNCTION IF EXISTS fn_crear_cuenta_auto();

DROP TABLE IF EXISTS movimiento CASCADE;
DROP TABLE IF EXISTS pago CASCADE;
DROP TABLE IF EXISTS detalle_volante CASCADE;
DROP TABLE IF EXISTS volante_matricula CASCADE;
DROP TABLE IF EXISTS cuenta_corriente CASCADE;
DROP TABLE IF EXISTS codigo_detalle CASCADE;
DROP TABLE IF EXISTS detalla CASCADE;
DROP TABLE IF EXISTS inscripcion CASCADE;
DROP TABLE IF EXISTS regla_cobro CASCADE;
DROP TABLE IF EXISTS plan_estudio CASCADE;
DROP TABLE IF EXISTS asignatura CASCADE;
DROP TABLE IF EXISTS estudiante CASCADE;
DROP TABLE IF EXISTS programa_academico CASCADE;
DROP TABLE IF EXISTS periodo_academico CASCADE;
DROP TABLE IF EXISTS permiso CASCADE;
DROP TABLE IF EXISTS menu CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;
DROP TABLE IF EXISTS persona CASCADE;
DROP TABLE IF EXISTS rol CASCADE;

-- ============================================================
-- 1. SEGURIDAD: ROLES, PERSONAS, USUARIOS, MENÚS Y PERMISOS
-- ============================================================

CREATE TABLE rol (
    id_rol          BIGSERIAL PRIMARY KEY,
    nombre_rol      VARCHAR(50)  NOT NULL UNIQUE,
    descripcion     VARCHAR(255),
    es_especial     BOOLEAN      NOT NULL DEFAULT FALSE,

    CONSTRAINT ck_rol_nombre
        CHECK (nombre_rol IN ('ADMINISTRADOR', 'SUPERVISOR', 'ASISTENTE'))
);

CREATE TABLE persona (
    id_persona        BIGSERIAL PRIMARY KEY,
    tipo_documento    VARCHAR(20)  NOT NULL,
    numero_documento  VARCHAR(30)  NOT NULL UNIQUE,
    primer_nombre     VARCHAR(80)  NOT NULL,
    segundo_nombre    VARCHAR(80),
    primer_apellido   VARCHAR(80)  NOT NULL,
    segundo_apellido  VARCHAR(80),
    correo_personal   VARCHAR(150) NOT NULL UNIQUE,
    telefono_contacto VARCHAR(30),
    perfil_tecnico    BOOLEAN      NOT NULL DEFAULT FALSE,
    estado            VARCHAR(20)  NOT NULL DEFAULT 'ACTIVO',

    CONSTRAINT ck_persona_estado
        CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT ck_persona_tipo_documento
        CHECK (tipo_documento IN ('CC', 'TI', 'CE', 'PASAPORTE'))
);

CREATE TABLE usuario (
    id_usuario          BIGSERIAL PRIMARY KEY,
    username            VARCHAR(80)  NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    fecha_creacion      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado              VARCHAR(20)  NOT NULL DEFAULT 'ACTIVO',
    correo_notificacion VARCHAR(150) NOT NULL,
    ultimo_acceso       TIMESTAMP,
    id_persona          BIGINT       NOT NULL UNIQUE,
    id_rol              BIGINT       NOT NULL,

    CONSTRAINT fk_usuario_persona
        FOREIGN KEY (id_persona) REFERENCES persona (id_persona)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_rol
        FOREIGN KEY (id_rol) REFERENCES rol (id_rol)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_usuario_estado
        CHECK (estado IN ('ACTIVO', 'INACTIVO', 'BLOQUEADO'))
);

CREATE TABLE menu (
    id_menu       BIGSERIAL PRIMARY KEY,
    nombre_menu   VARCHAR(100) NOT NULL,
    descripcion   VARCHAR(255),
    ruta          VARCHAR(255),
    orden         INTEGER      NOT NULL DEFAULT 1,
    estado        VARCHAR(20)  NOT NULL DEFAULT 'ACTIVO',
    id_menu_padre BIGINT,

    CONSTRAINT fk_menu_padre
        FOREIGN KEY (id_menu_padre) REFERENCES menu (id_menu)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT ck_menu_estado
        CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT ck_menu_orden
        CHECK (orden > 0)
);

CREATE TABLE permiso (
    id_menu        BIGINT  NOT NULL,
    id_rol         BIGINT  NOT NULL,
    puede_ver      BOOLEAN NOT NULL DEFAULT FALSE,
    puede_crear    BOOLEAN NOT NULL DEFAULT FALSE,
    puede_editar   BOOLEAN NOT NULL DEFAULT FALSE,
    puede_eliminar BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_permiso PRIMARY KEY (id_menu, id_rol),
    CONSTRAINT fk_permiso_menu
        FOREIGN KEY (id_menu) REFERENCES menu (id_menu)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_permiso_rol
        FOREIGN KEY (id_rol) REFERENCES rol (id_rol)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- ============================================================
-- 2. ESTRUCTURA ACADÉMICA
-- ============================================================

CREATE TABLE periodo_academico (
    id_periodo     BIGSERIAL PRIMARY KEY,
    codigo_periodo VARCHAR(20) NOT NULL UNIQUE,
    numero_periodo INTEGER     NOT NULL,
    anio           INTEGER     NOT NULL,
    fecha_inicio   DATE        NOT NULL,
    fecha_fin      DATE        NOT NULL,
    estado         VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',

    CONSTRAINT ck_periodo_numero
        CHECK (numero_periodo BETWEEN 1 AND 3),
    CONSTRAINT ck_periodo_fechas
        CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT ck_periodo_estado
        CHECK (estado IN ('ACTIVO', 'INACTIVO', 'CERRADO'))
);

CREATE TABLE programa_academico (
    id_programa        BIGSERIAL PRIMARY KEY,
    codigo_programa    VARCHAR(30)  NOT NULL UNIQUE,
    nombre_programa    VARCHAR(150) NOT NULL UNIQUE,
    duracion_semestres INTEGER      NOT NULL,
    modalidad_programa VARCHAR(30)  NOT NULL,
    nivel_formacion    VARCHAR(50)  NOT NULL,
    estado             VARCHAR(20)  NOT NULL DEFAULT 'ACTIVO',

    CONSTRAINT ck_programa_duracion
        CHECK (duracion_semestres > 0),
    CONSTRAINT ck_programa_estado
        CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT ck_programa_modalidad
        CHECK (modalidad_programa IN ('PRESENCIAL', 'VIRTUAL', 'HIBRIDA')),
    CONSTRAINT ck_programa_nivel
        CHECK (nivel_formacion IN ('PREGRADO', 'ESPECIALIZACION', 'MAESTRIA', 'DOCTORADO'))
);

CREATE TABLE estudiante (
    id_estudiante      BIGSERIAL PRIMARY KEY,
    tipo_documento     VARCHAR(20)  NOT NULL,
    numero_documento   VARCHAR(30)  NOT NULL UNIQUE,
    primer_nombre      VARCHAR(80)  NOT NULL,
    segundo_nombre     VARCHAR(80),
    primer_apellido    VARCHAR(80)  NOT NULL,
    segundo_apellido   VARCHAR(80),
    telefono_celular   VARCHAR(30),
    telefono_fijo      VARCHAR(30),
    correo_electronico VARCHAR(150) NOT NULL UNIQUE,
    direccion          VARCHAR(255),
    fecha_nacimiento   DATE,
    fecha_ingreso      DATE         NOT NULL DEFAULT CURRENT_DATE,
    id_programa        BIGINT       NOT NULL,

    CONSTRAINT fk_estudiante_programa
        FOREIGN KEY (id_programa) REFERENCES programa_academico (id_programa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_estudiante_tipo_documento
        CHECK (tipo_documento IN ('CC', 'TI', 'CE', 'PASAPORTE'))
);

CREATE TABLE asignatura (
    id_asignatura     BIGSERIAL PRIMARY KEY,
    codigo_asignatura VARCHAR(30)  NOT NULL UNIQUE,
    nombre_asignatura VARCHAR(150) NOT NULL,
    tipo_asignatura   VARCHAR(30)  NOT NULL,
    creditos          INTEGER      NOT NULL,
    estado            VARCHAR(20)  NOT NULL DEFAULT 'ACTIVA',

    CONSTRAINT ck_asignatura_creditos
        CHECK (creditos > 0),
    CONSTRAINT ck_asignatura_estado
        CHECK (estado IN ('ACTIVA', 'INACTIVA')),
    CONSTRAINT ck_asignatura_tipo
        CHECK (tipo_asignatura IN ('OBLIGATORIA', 'ELECTIVA', 'COMPLEMENTARIA'))
);

CREATE TABLE plan_estudio (
    id_programa    BIGINT  NOT NULL,
    id_asignatura  BIGINT  NOT NULL,
    semestre       INTEGER NOT NULL,
    creditos_plan  INTEGER NOT NULL,
    es_obligatoria BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_plan_estudio PRIMARY KEY (id_programa, id_asignatura, semestre),
    CONSTRAINT fk_plan_programa
        FOREIGN KEY (id_programa) REFERENCES programa_academico (id_programa)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_plan_asignatura
        FOREIGN KEY (id_asignatura) REFERENCES asignatura (id_asignatura)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_plan_semestre
        CHECK (semestre > 0),
    CONSTRAINT ck_plan_creditos
        CHECK (creditos_plan > 0)
);

CREATE TABLE regla_cobro (
    modalidad_cobro      VARCHAR(20)   NOT NULL,
    id_periodo           BIGINT        NOT NULL,
    id_programa          BIGINT        NOT NULL,
    valor_global         NUMERIC(14,2),
    valor_credito        NUMERIC(14,2),
    fecha_vigencia_desde DATE          NOT NULL DEFAULT CURRENT_DATE,
    fecha_vigencia_hasta DATE,
    estado               VARCHAR(20)   NOT NULL DEFAULT 'ACTIVA',

    CONSTRAINT pk_regla_cobro PRIMARY KEY (modalidad_cobro, id_periodo, id_programa),
    CONSTRAINT fk_regla_periodo
        FOREIGN KEY (id_periodo) REFERENCES periodo_academico (id_periodo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_regla_programa
        FOREIGN KEY (id_programa) REFERENCES programa_academico (id_programa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_regla_modalidad
        CHECK (modalidad_cobro IN ('GLOBAL', 'CREDITOS')),
    CONSTRAINT ck_regla_estado
        CHECK (estado IN ('ACTIVA', 'INACTIVA')),
    CONSTRAINT ck_regla_valores
        CHECK (
            (modalidad_cobro = 'GLOBAL'   AND valor_global  IS NOT NULL AND valor_global  > 0)
            OR
            (modalidad_cobro = 'CREDITOS' AND valor_credito IS NOT NULL AND valor_credito > 0)
        ),
    CONSTRAINT ck_regla_vigencia
        CHECK (fecha_vigencia_hasta IS NULL OR fecha_vigencia_hasta >= fecha_vigencia_desde)
);

-- ============================================================
-- 3. INSCRIPCIÓN ACADÉMICA Y ASIGNATURAS A CURSAR
-- ============================================================

CREATE TABLE inscripcion (
    id_inscripcion       BIGSERIAL PRIMARY KEY,
    fecha_inscripcion    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado               VARCHAR(20) NOT NULL DEFAULT 'ACTIVA',
    id_estudiante        BIGINT      NOT NULL,
    id_periodo_academico BIGINT      NOT NULL,

    CONSTRAINT fk_inscripcion_estudiante
        FOREIGN KEY (id_estudiante) REFERENCES estudiante (id_estudiante)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_inscripcion_periodo
        FOREIGN KEY (id_periodo_academico) REFERENCES periodo_academico (id_periodo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_inscripcion_estudiante_periodo
        UNIQUE (id_estudiante, id_periodo_academico),
    CONSTRAINT ck_inscripcion_estado
        CHECK (estado IN ('ACTIVA', 'ANULADA', 'FINALIZADA'))
);

CREATE TABLE detalla (
    id_asignatura  BIGINT NOT NULL,
    id_inscripcion BIGINT NOT NULL,

    CONSTRAINT pk_detalla PRIMARY KEY (id_asignatura, id_inscripcion),
    CONSTRAINT fk_detalla_asignatura
        FOREIGN KEY (id_asignatura) REFERENCES asignatura (id_asignatura)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_detalla_inscripcion
        FOREIGN KEY (id_inscripcion) REFERENCES inscripcion (id_inscripcion)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- ============================================================
-- 4. CÓDIGOS, CUENTA CORRIENTE, VOLANTES Y PAGOS
-- ============================================================

CREATE TABLE codigo_detalle (
    id_codigo_detalle BIGSERIAL PRIMARY KEY,
    codigo            VARCHAR(20)  NOT NULL UNIQUE,
    descripcion       VARCHAR(255) NOT NULL,
    grupo             VARCHAR(20)  NOT NULL,
    estado            VARCHAR(20)  NOT NULL DEFAULT 'ACTIVO',

    CONSTRAINT ck_codigo_grupo
        CHECK (grupo IN ('COBRO', 'PAGO')),
    CONSTRAINT ck_codigo_estado
        CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE cuenta_corriente (
    id_cuenta      BIGSERIAL PRIMARY KEY,
    fecha_apertura DATE        NOT NULL DEFAULT CURRENT_DATE,
    estado         VARCHAR(20) NOT NULL DEFAULT 'ABIERTA',
    id_estudiante  BIGINT      NOT NULL,
    id_periodo     BIGINT      NOT NULL,

    CONSTRAINT fk_cuenta_estudiante
        FOREIGN KEY (id_estudiante) REFERENCES estudiante (id_estudiante)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_cuenta_periodo
        FOREIGN KEY (id_periodo) REFERENCES periodo_academico (id_periodo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_cuenta_estudiante_periodo
        UNIQUE (id_estudiante, id_periodo),
    CONSTRAINT ck_cuenta_estado
        CHECK (estado IN ('ABIERTA', 'CERRADA', 'BLOQUEADA'))
);

CREATE TABLE volante_matricula (
    id_volante        BIGSERIAL PRIMARY KEY,
    numero_volante    VARCHAR(40) NOT NULL UNIQUE,
    fecha_generacion  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    semestre_a_cursar INTEGER     NOT NULL,
    generacion_tipo   VARCHAR(20) NOT NULL,
    estado            VARCHAR(20) NOT NULL DEFAULT 'GENERADO',
    modalidad_cobro   VARCHAR(20) NOT NULL,
    id_usuario        BIGINT      NOT NULL,
    id_periodo        BIGINT      NOT NULL,
    id_estudiante     BIGINT      NOT NULL,
    id_programa       BIGINT      NOT NULL,
    id_inscripcion    BIGINT,

    CONSTRAINT fk_volante_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_volante_periodo
        FOREIGN KEY (id_periodo) REFERENCES periodo_academico (id_periodo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_volante_estudiante
        FOREIGN KEY (id_estudiante) REFERENCES estudiante (id_estudiante)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_volante_programa
        FOREIGN KEY (id_programa) REFERENCES programa_academico (id_programa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_volante_inscripcion
        FOREIGN KEY (id_inscripcion) REFERENCES inscripcion (id_inscripcion)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_volante_regla_cobro
        FOREIGN KEY (modalidad_cobro, id_periodo, id_programa)
        REFERENCES regla_cobro (modalidad_cobro, id_periodo, id_programa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_volante_semestre
        CHECK (semestre_a_cursar > 0),
    CONSTRAINT ck_volante_generacion
        CHECK (generacion_tipo IN ('INDIVIDUAL', 'MASIVA')),
    CONSTRAINT ck_volante_modalidad
        CHECK (modalidad_cobro IN ('GLOBAL', 'CREDITOS')),
    CONSTRAINT ck_volante_estado
        CHECK (estado IN ('GENERADO', 'PENDIENTE', 'PAGADO', 'PARCIAL', 'ANULADO', 'FINANCIADO'))
);

CREATE TABLE detalle_volante (
    id_codigo_detalle    BIGINT        NOT NULL,
    id_volante_matricula BIGINT        NOT NULL,
    cantidad             NUMERIC(10,2) NOT NULL DEFAULT 1,
    valor_unitario       NUMERIC(14,2) NOT NULL,

    CONSTRAINT pk_detalle_volante PRIMARY KEY (id_codigo_detalle, id_volante_matricula),
    CONSTRAINT fk_detalle_volante_codigo
        FOREIGN KEY (id_codigo_detalle) REFERENCES codigo_detalle (id_codigo_detalle)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_volante_volante
        FOREIGN KEY (id_volante_matricula) REFERENCES volante_matricula (id_volante)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_detalle_volante_cantidad
        CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_volante_valor
        CHECK (valor_unitario >= 0)
);

CREATE TABLE pago (
    id_pago              BIGSERIAL PRIMARY KEY,
	tipo_pago            VARCHAR(30)   NOT NULL DEFAULT 'TOTAL',
    valor_pagado         NUMERIC(14,2) NOT NULL,
    fecha_pago           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado_pago          VARCHAR(20)   NOT NULL DEFAULT 'APROBADO',
    referencia_pago      VARCHAR(80)   NOT NULL UNIQUE,
    canal_pago           VARCHAR(30)   NOT NULL,
    id_volante_matricula BIGINT        NOT NULL,
    id_usuario           BIGINT        NOT NULL,

    CONSTRAINT fk_pago_volante
        FOREIGN KEY (id_volante_matricula) REFERENCES volante_matricula (id_volante)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pago_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_pago_valor
        CHECK (valor_pagado > 0),
    CONSTRAINT ck_pago_estado
        CHECK (estado_pago IN ('APROBADO', 'RECHAZADO', 'ANULADO', 'PENDIENTE')),
    CONSTRAINT ck_pago_canal
        CHECK (canal_pago IN ('CAJA', 'PSE', 'TRANSFERENCIA', 'TARJETA')),
	CONSTRAINT ck_pago_tipo
    	CHECK (tipo_pago IN ('TOTAL', 'ANTICIPO', 'DESCUENTO', 'CREDITO_FINANCIERO', 'AJUSTE'))
);

CREATE TABLE movimiento (
    id_cuenta_corriente   BIGINT        NOT NULL,
    numero_secuencia      INTEGER       NOT NULL,
    id_codigo_detalle     BIGINT        NOT NULL,
    id_origen             BIGINT,
    tipo_origen           VARCHAR(30)   NOT NULL,
    fecha_movimiento      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descripcion_adicional VARCHAR(255),
    valor                 NUMERIC(14,2) NOT NULL,

    CONSTRAINT pk_movimiento PRIMARY KEY (id_cuenta_corriente, numero_secuencia),
    CONSTRAINT fk_movimiento_cuenta
        FOREIGN KEY (id_cuenta_corriente) REFERENCES cuenta_corriente (id_cuenta)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_movimiento_codigo
        FOREIGN KEY (id_codigo_detalle) REFERENCES codigo_detalle (id_codigo_detalle)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_movimiento_secuencia
        CHECK (numero_secuencia > 0),
    CONSTRAINT ck_movimiento_valor
        CHECK (valor > 0),
    CONSTRAINT ck_movimiento_tipo_origen
        CHECK (tipo_origen IN ('VOLANTE', 'PAGO', 'DESCUENTO', 'ANTICIPO', 'CREDITO', 'AJUSTE'))
);

-- ============================================================
-- 5. ÍNDICES RECOMENDADOS PARA CONSULTAS Y REPORTES
-- ============================================================

CREATE INDEX idx_estudiante_programa      ON estudiante (id_programa);
CREATE INDEX idx_inscripcion_periodo      ON inscripcion (id_periodo_academico);
CREATE INDEX idx_volante_periodo_programa ON volante_matricula (id_periodo, id_programa);
CREATE INDEX idx_volante_estudiante       ON volante_matricula (id_estudiante);
CREATE INDEX idx_pago_volante             ON pago (id_volante_matricula);
CREATE INDEX idx_movimiento_cuenta        ON movimiento (id_cuenta_corriente);
CREATE INDEX idx_movimiento_codigo        ON movimiento (id_codigo_detalle);

-- ============================================================
-- 6. FUNCIONES Y TRIGGERS
--
--   Trigger 1 — fn_crear_cuenta_auto:
--     Al insertar un volante_matricula, crea automáticamente la
--     cuenta_corriente del estudiante en ese periodo si no existe.
--
--   Trigger 2 — fn_detalle_volante_movimiento:
--     Al insertar una línea en detalle_volante, registra el
--     movimiento de COBRO correspondiente en cuenta_corriente.
--
--   Trigger 3 — fn_registrar_movimiento_pago:
--     Al actualizar un pago a estado APROBADO, registra el
--     movimiento de PAGO (abono) en cuenta_corriente.
-- ============================================================

-- ------------------------------------------------------------
-- TRIGGER 1: Crear cuenta corriente automáticamente
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_crear_cuenta_auto()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM cuenta_corriente
        WHERE id_estudiante = NEW.id_estudiante
          AND id_periodo    = NEW.id_periodo
    ) THEN
        INSERT INTO cuenta_corriente (id_estudiante, id_periodo, fecha_apertura, estado)
        VALUES (NEW.id_estudiante, NEW.id_periodo, CURRENT_DATE, 'ABIERTA');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_crear_cuenta_auto()
    IS 'Abre la cuenta_corriente del estudiante en el periodo si es su primer volante.';

CREATE TRIGGER trg_volante_crear_cuenta
AFTER INSERT ON volante_matricula
FOR EACH ROW EXECUTE FUNCTION fn_crear_cuenta_auto();

-- ------------------------------------------------------------
-- TRIGGER 2: Registrar movimiento de COBRO por cada línea de detalle_volante
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_detalle_volante_movimiento()
RETURNS TRIGGER AS $$
DECLARE
    v_id_cuenta       BIGINT;
    v_id_estudiante   BIGINT;
    v_id_periodo      BIGINT;
    v_codigo          VARCHAR(20);
    v_next_secuencia  INTEGER;
BEGIN
    -- Obtener estudiante y periodo desde el volante
    SELECT id_estudiante, id_periodo
    INTO v_id_estudiante, v_id_periodo
    FROM volante_matricula
    WHERE id_volante = NEW.id_volante_matricula;

    -- Obtener la cuenta corriente del periodo
    SELECT id_cuenta INTO v_id_cuenta
    FROM cuenta_corriente
    WHERE id_estudiante = v_id_estudiante
      AND id_periodo    = v_id_periodo;

    -- Calcular el siguiente numero_secuencia para esta cuenta
    SELECT COALESCE(MAX(numero_secuencia), 0) + 1
    INTO v_next_secuencia
    FROM movimiento
    WHERE id_cuenta_corriente = v_id_cuenta;

    -- Obtener el código para el mensaje descriptivo
    SELECT codigo INTO v_codigo
    FROM codigo_detalle
    WHERE id_codigo_detalle = NEW.id_codigo_detalle;

    -- Insertar el movimiento de COBRO
    INSERT INTO movimiento (
        id_cuenta_corriente,
        numero_secuencia,
        id_codigo_detalle,
        id_origen,
        tipo_origen,
        descripcion_adicional,
        valor
    ) VALUES (
        v_id_cuenta,
        v_next_secuencia,
        NEW.id_codigo_detalle,
        NEW.id_volante_matricula,
        'VOLANTE',
        'Cobro volante ' || NEW.id_volante_matricula || ' — código: ' || v_codigo,
        NEW.cantidad * NEW.valor_unitario
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_detalle_volante_movimiento()
    IS 'Asienta un movimiento de COBRO por cada línea insertada en detalle_volante.';

CREATE TRIGGER trg_detalle_volante_cobro
AFTER INSERT ON detalle_volante
FOR EACH ROW EXECUTE FUNCTION fn_detalle_volante_movimiento();

-- ------------------------------------------------------------
-- TRIGGER 3: Registrar movimiento de PAGO al confirmar un pago
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_registrar_movimiento_pago()
RETURNS TRIGGER AS $$
DECLARE
    v_id_cuenta      BIGINT;
    v_id_estudiante  BIGINT;
    v_id_periodo     BIGINT;
    v_id_codigo      BIGINT;
    v_next_secuencia INTEGER;
BEGIN
    -- Solo ejecutar cuando el estado cambia efectivamente a APROBADO
    IF NEW.estado_pago = 'APROBADO' AND (OLD.estado_pago IS DISTINCT FROM 'APROBADO') THEN

        -- Obtener estudiante y periodo desde el volante asociado
        SELECT id_estudiante, id_periodo
        INTO v_id_estudiante, v_id_periodo
        FROM volante_matricula
        WHERE id_volante = NEW.id_volante_matricula;

        -- Obtener la cuenta corriente del periodo
        SELECT id_cuenta INTO v_id_cuenta
        FROM cuenta_corriente
        WHERE id_estudiante = v_id_estudiante
          AND id_periodo    = v_id_periodo;

        -- Obtener el id del código
        SELECT id_codigo_detalle INTO v_id_codigo
		FROM codigo_detalle
		WHERE codigo = CASE NEW.tipo_pago
		    WHEN 'CREDITO_FINANCIERO' THEN 'CRED'
		    WHEN 'DESCUENTO'          THEN 'DESC'
		    WHEN 'ANTICIPO'           THEN 'ANT'
		    ELSE 'MPAG'
		END;

        -- Calcular el siguiente numero_secuencia para esta cuenta
        SELECT COALESCE(MAX(numero_secuencia), 0) + 1
        INTO v_next_secuencia
        FROM movimiento
        WHERE id_cuenta_corriente = v_id_cuenta;

        -- Insertar el movimiento de PAGO (abono)
        INSERT INTO movimiento (
            id_cuenta_corriente,
            numero_secuencia,
            id_codigo_detalle,
            id_origen,
            tipo_origen,
            descripcion_adicional,
            valor
        ) VALUES (
            v_id_cuenta,
            v_next_secuencia,
            v_id_codigo,
            NEW.id_pago,
            'PAGO',
            'Pago ref: ' || NEW.referencia_pago || ' — canal: ' || NEW.canal_pago,
            NEW.valor_pagado
        );

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_registrar_movimiento_pago()
    IS 'Asienta el abono (MPAG) en cuenta_corriente cuando un pago se confirma como APROBADO.';

CREATE TRIGGER trg_pago_movimiento
AFTER UPDATE OF estado_pago ON pago
FOR EACH ROW EXECUTE FUNCTION fn_registrar_movimiento_pago();

-- ============================================================
-- 7. VISTAS PARA CUENTA CORRIENTE Y REPORTES DE GESTIÓN
-- ============================================================

-- Balance por cuenta corriente: COBROS - PAGOS.
CREATE VIEW vista_balance_cuenta_corriente AS
SELECT
    cc.id_cuenta,
    cc.id_estudiante,
    e.numero_documento,
    CONCAT(e.primer_nombre, ' ', e.primer_apellido) AS nombre_estudiante,
    cc.id_periodo,
    pa.codigo_periodo,
    COALESCE(SUM(CASE WHEN cd.grupo = 'COBRO' THEN m.valor ELSE 0 END), 0)          AS total_cobros,
    COALESCE(SUM(CASE WHEN cd.grupo = 'PAGO'  THEN m.valor ELSE 0 END), 0)          AS total_pagos,
    COALESCE(SUM(CASE WHEN cd.grupo = 'COBRO' THEN m.valor ELSE -m.valor END), 0)   AS saldo
FROM cuenta_corriente cc
JOIN estudiante e
    ON e.id_estudiante = cc.id_estudiante
JOIN periodo_academico pa
    ON pa.id_periodo = cc.id_periodo
LEFT JOIN movimiento m
    ON m.id_cuenta_corriente = cc.id_cuenta
LEFT JOIN codigo_detalle cd
    ON cd.id_codigo_detalle = m.id_codigo_detalle
GROUP BY
    cc.id_cuenta, cc.id_estudiante, e.numero_documento,
    e.primer_nombre, e.primer_apellido, cc.id_periodo, pa.codigo_periodo;

-- Reporte 1: listado de estudiantes con programa, modalidad y monto.
CREATE VIEW vista_resumen_estudiantes AS
SELECT
    e.id_estudiante,
    e.primer_nombre || ' ' || e.primer_apellido AS nombre_estudiante,
    e.numero_documento,
    pr.nombre_programa,
    pr.codigo_programa,
    vm.modalidad_cobro,
    vm.semestre_a_cursar,
    pa.codigo_periodo,
    COALESCE(SUM(dv.cantidad * dv.valor_unitario), 0) AS monto_volante,
    vm.estado AS estado_volante
FROM volante_matricula vm
JOIN estudiante e          ON e.id_estudiante  = vm.id_estudiante
JOIN programa_academico pr ON pr.id_programa   = vm.id_programa
JOIN periodo_academico pa  ON pa.id_periodo    = vm.id_periodo
LEFT JOIN detalle_volante dv ON dv.id_volante_matricula = vm.id_volante
GROUP BY
    e.id_estudiante, e.primer_nombre, e.primer_apellido,
    e.numero_documento, pr.nombre_programa, pr.codigo_programa,
    vm.modalidad_cobro, vm.semestre_a_cursar, pa.codigo_periodo, vm.estado;

-- Reporte 2: ingreso esperado totalizado por periodo y programa.
CREATE VIEW vista_ingreso_esperado AS
SELECT
    pa.id_periodo,
    pa.codigo_periodo,
    pr.id_programa,
    pr.nombre_programa,
    COUNT(DISTINCT vm.id_estudiante)     AS total_estudiantes,
    SUM(dv.cantidad * dv.valor_unitario) AS ingreso_esperado_total
FROM volante_matricula vm
JOIN detalle_volante dv    ON dv.id_volante_matricula = vm.id_volante
JOIN periodo_academico pa  ON pa.id_periodo           = vm.id_periodo
JOIN programa_academico pr ON pr.id_programa          = vm.id_programa
WHERE vm.estado <> 'ANULADO'
GROUP BY
    pa.id_periodo, pa.codigo_periodo,
    pr.id_programa, pr.nombre_programa;

-- Reporte 3: estudiantes pendientes de pago por periodo y programa.
-- Nota: se construye directamente desde las tablas base (no desde
-- vista_ingreso_esperado) para poder filtrar por estudiante individual
-- y evitar un JOIN costoso sobre una vista ya agregada.
CREATE VIEW vista_estudiantes_pendientes_pago AS
SELECT
    pa.id_periodo,
    pa.codigo_periodo,
    pr.id_programa,
    pr.nombre_programa,
    e.id_estudiante,
    e.numero_documento,
    e.primer_nombre || ' ' || e.primer_apellido AS nombre_estudiante,
    vm.modalidad_cobro,
    vm.id_volante,
    vm.numero_volante,
    COALESCE(SUM(dv.cantidad * dv.valor_unitario), 0) AS monto_esperado,
    COALESCE((
        SELECT SUM(p2.valor_pagado)
        FROM pago p2
        WHERE p2.id_volante_matricula = vm.id_volante
          AND p2.estado_pago = 'APROBADO'
    ), 0) AS monto_pagado,
    COALESCE(SUM(dv.cantidad * dv.valor_unitario), 0)
        - COALESCE((
            SELECT SUM(p2.valor_pagado)
            FROM pago p2
            WHERE p2.id_volante_matricula = vm.id_volante
              AND p2.estado_pago = 'APROBADO'
        ), 0) AS saldo_pendiente
FROM volante_matricula vm
JOIN estudiante e          ON e.id_estudiante  = vm.id_estudiante
JOIN programa_academico pr ON pr.id_programa   = vm.id_programa
JOIN periodo_academico pa  ON pa.id_periodo    = vm.id_periodo
LEFT JOIN detalle_volante dv ON dv.id_volante_matricula = vm.id_volante
WHERE vm.estado <> 'ANULADO'
GROUP BY
    pa.id_periodo, pa.codigo_periodo, pr.id_programa, pr.nombre_programa,
    e.id_estudiante, e.numero_documento, e.primer_nombre, e.primer_apellido,
    vm.modalidad_cobro, vm.id_volante, vm.numero_volante
HAVING
    COALESCE(SUM(dv.cantidad * dv.valor_unitario), 0)
        - COALESCE((
            SELECT SUM(p2.valor_pagado)
            FROM pago p2
            WHERE p2.id_volante_matricula = vm.id_volante
              AND p2.estado_pago = 'APROBADO'
        ), 0) > 0;

-- Reporte 4: ingreso real recibido por periodo académico.
CREATE VIEW vista_ingreso_real AS
SELECT
    pa.id_periodo,
    pa.codigo_periodo,
    pr.id_programa,
    pr.nombre_programa,
    SUM(p.valor_pagado) AS ingreso_real_recibido
FROM pago p
JOIN volante_matricula vm  ON vm.id_volante  = p.id_volante_matricula
JOIN periodo_academico pa  ON pa.id_periodo  = vm.id_periodo
JOIN programa_academico pr ON pr.id_programa = vm.id_programa
WHERE p.estado_pago = 'APROBADO'
  AND p.tipo_pago <> 'DESCUENTO'
GROUP BY pa.id_periodo, pa.codigo_periodo, pr.id_programa, pr.nombre_programa;

-- Reporte 5: estudiantes con crédito financiero y total de cartera.
CREATE VIEW vista_creditos_financieros AS
SELECT
    cc.id_periodo,
    pa.codigo_periodo,
    e.id_estudiante,
    e.numero_documento,
    CONCAT(e.primer_nombre, ' ', e.primer_apellido) AS nombre_estudiante,
    pr.id_programa,
    pr.nombre_programa,
    SUM(m.valor) AS valor_credito
FROM movimiento m
JOIN codigo_detalle cd     ON cd.id_codigo_detalle = m.id_codigo_detalle
JOIN cuenta_corriente cc   ON cc.id_cuenta         = m.id_cuenta_corriente
JOIN periodo_academico pa  ON pa.id_periodo        = cc.id_periodo
JOIN estudiante e          ON e.id_estudiante      = cc.id_estudiante
JOIN programa_academico pr ON pr.id_programa       = e.id_programa
WHERE cd.codigo = 'CRED'
GROUP BY
    cc.id_periodo, pa.codigo_periodo, e.id_estudiante, e.numero_documento,
    e.primer_nombre, e.primer_apellido, pr.id_programa, pr.nombre_programa;

-- ============================================================
-- 8. COMENTARIOS DOCUMENTALES PARA EL DICCIONARIO DE DATOS
-- ============================================================

COMMENT ON TABLE codigo_detalle     IS 'Catálogo de códigos de cobro y pago. Ejemplos: PMAT, PCRE, PCAR, MPAG, ANT, DESC, CRED.';
COMMENT ON TABLE cuenta_corriente   IS 'Cuenta corriente del estudiante por periodo académico.';
COMMENT ON TABLE movimiento         IS 'Movimientos codificados de la cuenta corriente. El balance se calcula según el grupo del código: COBRO o PAGO.';
COMMENT ON TABLE volante_matricula  IS 'Documento generado para liquidar el valor esperado de matrícula de un estudiante en un periodo.';

COMMENT ON VIEW vista_balance_cuenta_corriente    IS 'Calcula total de cobros, total de pagos y saldo de cada cuenta corriente.';
COMMENT ON VIEW vista_resumen_estudiantes         IS 'Reporte 1: listado de estudiantes con programa, modalidad de cobro y monto del volante.';
COMMENT ON VIEW vista_ingreso_esperado            IS 'Reporte 2: ingreso esperado totalizado por periodo académico y programa.';
COMMENT ON VIEW vista_estudiantes_pendientes_pago IS 'Reporte 3: estudiantes con saldo pendiente por periodo académico y programa.';
COMMENT ON VIEW vista_ingreso_real                IS 'Reporte 4: ingreso real recibido por periodo académico y programa.';
COMMENT ON VIEW vista_creditos_financieros        IS 'Reporte 5: estudiantes con código CRED en cuenta corriente y valor total del crédito financiero.';