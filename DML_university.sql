/*
============================================================
 PROYECTO FINAL BASES DE DATOS 2026-10
 Sistema: Cuenta Corriente del Estudiante
 Motor RDBMS: PostgreSQL
 Entregable #4: Script DML — Datos de Prueba
 Versión: 1.0

 ESCENARIOS DE NEGOCIO CUBIERTOS
 ─────────────────────────────────────────────────────────
 E1 · Matrícula GLOBAL pagada completamente         → saldo = 0
 E2 · Matrícula GLOBAL pago parcial (anticipo)      → saldo > 0  (pendiente)
 E3 · Matrícula por CRÉDITOS pagada completamente   → saldo = 0
 E4 · Matrícula por CRÉDITOS con crédito financiero → código CRED en cuenta
 E5 · Matrícula GLOBAL con descuento aplicado       → saldo = 0
 E6 · Volante MASIVO — dos estudiantes del mismo
      programa generados en un solo lote             → aparece en vista_ingreso_esperado
 E7 · Pago rechazado — no afecta la cuenta corriente
 E8 · Estudiante sin pago — visible en vista_estudiantes_pendientes_pago

 ORDEN DE INSERCIÓN (respeta todas las FK):
  1. rol
  2. persona / usuario / menu / permiso
  3. periodo_academico
  4. programa_academico
  5. asignatura / plan_estudio
  6. regla_cobro
  7. estudiante
  8. inscripcion / detalla
  9. volante_matricula  ← trigger crea cuenta_corriente
 10. detalle_volante    ← trigger registra movimiento COBRO
 11. pago               ← trigger registra movimiento PAGO al aprobar
============================================================
*/

-- ============================================================
-- BLOQUE 0: CONTROL DE TRANSACCIÓN
--   Todo o nada: si algo falla el script se revierte completo.
-- ============================================================
BEGIN;

-- ============================================================
-- BLOQUE 1: SEGURIDAD
--   3 roles, 4 personas, 4 usuarios, menú básico, permisos.
-- ============================================================

-- 1.1 Roles -------------------------------------------------------
INSERT INTO rol (nombre_rol, descripcion, es_especial) VALUES
    ('ADMINISTRADOR', 'Control total del sistema: usuarios, roles, menús y operaciones', TRUE),
    ('SUPERVISOR',    'Gestión académica: programas, tarifas, estudiantes y códigos',    FALSE),
    ('ASISTENTE',     'Operativo: cobros, volantes, pagos e inscripciones',              FALSE);

-- 1.2 Personas (4: 1 admin técnico, 1 supervisor, 2 asistentes) ---
INSERT INTO persona (tipo_documento, numero_documento, primer_nombre, segundo_nombre,
                     primer_apellido, segundo_apellido, correo_personal,
                     telefono_contacto, perfil_tecnico, estado) VALUES
    -- Administrador técnico
    ('CC', '10010001', 'Carlos',   'Alberto',  'Mendoza',   'Ruiz',    'carlos.mendoza@unicaribe.edu.co',  '3001110001', TRUE,  'ACTIVO'),
    -- Supervisor académico
    ('CC', '10010002', 'Marcela',  'Patricia', 'Guerrero',  'Blanco',  'marcela.guerrero@unicaribe.edu.co','3001110002', FALSE, 'ACTIVO'),
    -- Asistente 1
    ('CC', '10010003', 'Andrés',   NULL,       'Palomino',  'Torres',  'andres.palomino@unicaribe.edu.co', '3001110003', FALSE, 'ACTIVO'),
    -- Asistente 2
    ('CC', '10010004', 'Luisa',    'Fernanda', 'Castillo',  NULL,      'luisa.castillo@unicaribe.edu.co',  '3001110004', FALSE, 'ACTIVO');

-- 1.3 Usuarios (password_hash = bcrypt de 'Temporal2026*') --------
INSERT INTO usuario (username, password_hash, estado, correo_notificacion,
                     id_persona, id_rol) VALUES
    ('cmendoza',   '$2b$12$AAAAAAAAAAAAAAAAAAAAAAhashAdmin001', 'ACTIVO',
        'carlos.mendoza@unicaribe.edu.co',
        (SELECT id_persona FROM persona WHERE numero_documento = '10010001'),
        (SELECT id_rol     FROM rol     WHERE nombre_rol = 'ADMINISTRADOR')),
    ('mguerrero',  '$2b$12$AAAAAAAAAAAAAAAAAAAAAAhashSuper001', 'ACTIVO',
        'marcela.guerrero@unicaribe.edu.co',
        (SELECT id_persona FROM persona WHERE numero_documento = '10010002'),
        (SELECT id_rol     FROM rol     WHERE nombre_rol = 'SUPERVISOR')),
    ('apalomino',  '$2b$12$AAAAAAAAAAAAAAAAAAAAAAhashAsist001', 'ACTIVO',
        'andres.palomino@unicaribe.edu.co',
        (SELECT id_persona FROM persona WHERE numero_documento = '10010003'),
        (SELECT id_rol     FROM rol     WHERE nombre_rol = 'ASISTENTE')),
    ('lcastillo',  '$2b$12$AAAAAAAAAAAAAAAAAAAAAAhashAsist002', 'ACTIVO',
        'luisa.castillo@unicaribe.edu.co',
        (SELECT id_persona FROM persona WHERE numero_documento = '10010004'),
        (SELECT id_rol     FROM rol     WHERE nombre_rol = 'ASISTENTE'));

-- 1.4 Menú (primer nivel + submenús de Seguridad y Reportes) ------
INSERT INTO menu (nombre_menu, descripcion, ruta, orden, estado, id_menu_padre) VALUES
    ('Seguridad',         'Usuarios, roles y permisos',                '/seguridad',     1, 'ACTIVO', NULL),
    ('Académico',         'Programas, asignaturas y planes',           '/academico',     2, 'ACTIVO', NULL),
    ('Períodos y Reglas', 'Períodos académicos y tarifas de cobro',    '/periodos',      3, 'ACTIVO', NULL),
    ('Estudiantes',       'Registro y consulta de estudiantes',        '/estudiantes',   4, 'ACTIVO', NULL),
    ('Inscripciones',     'Inscripción de asignaturas',                '/inscripciones', 5, 'ACTIVO', NULL),
    ('Cobros',            'Generación de volantes',                    '/cobros',        6, 'ACTIVO', NULL),
    ('Cuenta Corriente',  'Movimientos y saldo por estudiante',        '/cuenta',        7, 'ACTIVO', NULL),
    ('Pagos',             'Registro y simulación de pagos',            '/pagos',         8, 'ACTIVO', NULL),
    ('Reportes',          'Indicadores de gestión',                    '/reportes',      9, 'ACTIVO', NULL);

-- Submenús de Seguridad
INSERT INTO menu (nombre_menu, descripcion, ruta, orden, estado, id_menu_padre) VALUES
    ('Roles',    'CRUD roles',     '/seguridad/roles',    1, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/seguridad')),
    ('Usuarios', 'CRUD usuarios',  '/seguridad/usuarios', 2, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/seguridad')),
    ('Personas', 'CRUD personas',  '/seguridad/personas', 3, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/seguridad')),
    ('Permisos', 'Matriz permisos','/seguridad/permisos', 4, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/seguridad'));

-- Submenús de Reportes
INSERT INTO menu (nombre_menu, descripcion, ruta, orden, estado, id_menu_padre) VALUES
    ('Resumen Estudiantes', 'Programa, modalidad y monto',           '/reportes/resumen',    1, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/reportes')),
    ('Ingreso Esperado',    'Total esperado por período y programa',  '/reportes/esperado',   2, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/reportes')),
    ('Pendientes de Pago',  'Saldo pendiente por programa',          '/reportes/pendientes', 3, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/reportes')),
    ('Ingreso Real',        'Pagos confirmados en el período',        '/reportes/real',       4, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/reportes')),
    ('Cartera Créditos',    'Estudiantes con crédito financiero',     '/reportes/cartera',    5, 'ACTIVO', (SELECT id_menu FROM menu WHERE ruta = '/reportes'));

-- 1.5 Permisos — ADMINISTRADOR: acceso total a todo el menú -------
INSERT INTO permiso (id_menu, id_rol, puede_ver, puede_crear, puede_editar, puede_eliminar)
SELECT m.id_menu,
       r.id_rol,
       TRUE, TRUE, TRUE, TRUE
FROM menu m
CROSS JOIN rol r
WHERE r.nombre_rol = 'ADMINISTRADOR'
ON CONFLICT DO NOTHING;

-- 1.6 Permisos — SUPERVISOR: sin seguridad ni pagos ---------------
INSERT INTO permiso (id_menu, id_rol, puede_ver, puede_crear, puede_editar, puede_eliminar)
SELECT m.id_menu,
       r.id_rol,
       TRUE, TRUE, TRUE, FALSE
FROM menu m
CROSS JOIN rol r
WHERE r.nombre_rol = 'SUPERVISOR'
  AND m.ruta NOT LIKE '/seguridad%'
  AND m.ruta NOT IN ('/pagos', '/cobros', '/cuenta')
ON CONFLICT DO NOTHING;

-- 1.7 Permisos — ASISTENTE: solo operativo ------------------------
INSERT INTO permiso (id_menu, id_rol, puede_ver, puede_crear, puede_editar, puede_eliminar)
SELECT m.id_menu,
       r.id_rol,
       TRUE, TRUE, FALSE, FALSE
FROM menu m
CROSS JOIN rol r
WHERE r.nombre_rol = 'ASISTENTE'
  AND m.ruta IN ('/cobros', '/pagos', '/cuenta', '/inscripciones',
                 '/reportes', '/reportes/resumen', '/reportes/esperado',
                 '/reportes/pendientes', '/reportes/real', '/reportes/cartera')
ON CONFLICT DO NOTHING;


-- ============================================================
-- BLOQUE 2: PERÍODO ACADÉMICO
--   2025-1 (cerrado) y 2025-2 (activo — período de prueba).
-- ============================================================

INSERT INTO periodo_academico (codigo_periodo, numero_periodo, anio,
                                fecha_inicio, fecha_fin, estado) VALUES
    ('2025-1', 1, 2025, '2025-01-20', '2025-06-14', 'CERRADO'),
    ('2025-2', 2, 2025, '2025-07-14', '2025-11-29', 'ACTIVO');


-- ============================================================
-- BLOQUE 3: PROGRAMAS ACADÉMICOS
--   3 programas con niveles y modalidades distintos para
--   cubrir todos los CHECK constraints del modelo.
-- ============================================================

INSERT INTO programa_academico (codigo_programa, nombre_programa, duracion_semestres,
                                  modalidad_programa, nivel_formacion, estado) VALUES
    ('ING-SIS-01', 'Ingeniería de Sistemas',           10, 'PRESENCIAL', 'PREGRADO',       'ACTIVO'),
    ('ADM-EMP-01', 'Administración de Empresas',        8, 'PRESENCIAL', 'PREGRADO',       'ACTIVO'),
    ('ESP-GES-01', 'Especialización en Gestión TI',     2, 'VIRTUAL',    'ESPECIALIZACION','ACTIVO');


-- ============================================================
-- BLOQUE 4: ASIGNATURAS Y PLAN DE ESTUDIOS
--   Semestres 1–3 de Ing. Sistemas, semestres 1–2 de Admón.
--   Suficientes para probar modalidad CRÉDITOS.
-- ============================================================

-- 4.1 Asignaturas -------------------------------------------------
INSERT INTO asignatura (codigo_asignatura, nombre_asignatura, tipo_asignatura, creditos, estado) VALUES
    -- Ingeniería de Sistemas
    ('IS-MAT1', 'Matemáticas I',              'OBLIGATORIA', 4, 'ACTIVA'),
    ('IS-ALG1', 'Algoritmos y Programación',  'OBLIGATORIA', 3, 'ACTIVA'),
    ('IS-FIS1', 'Física I',                   'OBLIGATORIA', 4, 'ACTIVA'),
    ('IS-HUM1', 'Humanidades I',              'COMPLEMENTARIA', 2, 'ACTIVA'),
    ('IS-MAT2', 'Matemáticas II',             'OBLIGATORIA', 4, 'ACTIVA'),
    ('IS-EST1', 'Estructuras de Datos',       'OBLIGATORIA', 3, 'ACTIVA'),
    ('IS-FIS2', 'Física II',                  'OBLIGATORIA', 4, 'ACTIVA'),
    ('IS-ELE1', 'Electiva Libre I',           'ELECTIVA',    2, 'ACTIVA'),
    ('IS-BDA1', 'Bases de Datos I',           'OBLIGATORIA', 3, 'ACTIVA'),
    ('IS-RED1', 'Redes y Comunicaciones',     'OBLIGATORIA', 3, 'ACTIVA'),
    -- Administración de Empresas
    ('ADM-CON', 'Contabilidad General',       'OBLIGATORIA', 3, 'ACTIVA'),
    ('ADM-ECO', 'Economía General',           'OBLIGATORIA', 3, 'ACTIVA'),
    ('ADM-MAT', 'Matemáticas Financieras',    'OBLIGATORIA', 3, 'ACTIVA'),
    ('ADM-HUM', 'Humanidades I',              'COMPLEMENTARIA', 2, 'ACTIVA'),
    ('ADM-ADM', 'Fundamentos de Administración','OBLIGATORIA',3, 'ACTIVA'),
    ('ADM-MKT', 'Mercadeo I',                 'OBLIGATORIA', 3, 'ACTIVA');

-- 4.2 Plan de estudios — Ingeniería de Sistemas -------------------
INSERT INTO plan_estudio (id_programa, id_asignatura, semestre, creditos_plan, es_obligatoria)
SELECT p.id_programa, a.id_asignatura, x.semestre, x.creditos_plan, x.es_obligatoria
FROM programa_academico p
CROSS JOIN (VALUES
    ('IS-MAT1', 1, 4, TRUE),
    ('IS-ALG1', 1, 3, TRUE),
    ('IS-FIS1', 1, 4, TRUE),
    ('IS-HUM1', 1, 2, FALSE),
    ('IS-MAT2', 2, 4, TRUE),
    ('IS-EST1', 2, 3, TRUE),
    ('IS-FIS2', 2, 4, TRUE),
    ('IS-ELE1', 2, 2, FALSE),
    ('IS-BDA1', 3, 3, TRUE),
    ('IS-RED1', 3, 3, TRUE)
) AS x(cod_asig, semestre, creditos_plan, es_obligatoria)
JOIN asignatura a ON a.codigo_asignatura = x.cod_asig
WHERE p.codigo_programa = 'ING-SIS-01';

-- 4.3 Plan de estudios — Administración de Empresas ---------------
INSERT INTO plan_estudio (id_programa, id_asignatura, semestre, creditos_plan, es_obligatoria)
SELECT p.id_programa, a.id_asignatura, x.semestre, x.creditos_plan, x.es_obligatoria
FROM programa_academico p
CROSS JOIN (VALUES
    ('ADM-CON', 1, 3, TRUE),
    ('ADM-ECO', 1, 3, TRUE),
    ('ADM-MAT', 1, 3, TRUE),
    ('ADM-HUM', 1, 2, FALSE),
    ('ADM-ADM', 2, 3, TRUE),
    ('ADM-MKT', 2, 3, TRUE)
) AS x(cod_asig, semestre, creditos_plan, es_obligatoria)
JOIN asignatura a ON a.codigo_asignatura = x.cod_asig
WHERE p.codigo_programa = 'ADM-EMP-01';


-- ============================================================
-- BLOQUE 5: CÓDIGOS DE DETALLE
--   Catálogo completo del enunciado: 5 COBRO + 4 PAGO.
-- ============================================================

INSERT INTO codigo_detalle (codigo, descripcion, grupo, estado) VALUES
    -- COBROS
    ('PMAT', 'Valor Global de Matrícula por Programa',   'COBRO', 'ACTIVO'),
    ('PCRE', 'Valor de Matrícula por Crédito',           'COBRO', 'ACTIVO'),
    ('PCAR', 'Carné Digital',                            'COBRO', 'ACTIVO'),
    ('PLAB', 'Laboratorios Médicos',                     'COBRO', 'ACTIVO'),
    ('PEXA', 'Exámenes de Ingreso',                      'COBRO', 'ACTIVO'),
    -- PAGOS
    ('MPAG', 'Pago de Matrícula',                        'PAGO',  'ACTIVO'),
    ('ANT',  'Anticipo de Matrícula',                    'PAGO',  'ACTIVO'),
    ('DESC', 'Descuento Aplicado',                       'PAGO',  'ACTIVO'),
    ('CRED', 'Crédito Financiero (ICETEX / Entidad)',    'PAGO',  'ACTIVO');


-- ============================================================
-- BLOQUE 6: REGLAS DE COBRO — período 2025-2
--   Global y por créditos para cada programa activo.
--   Ing. Sistemas: $4.800.000 global / $215.000 por crédito
--   Admón. Empresas: $3.900.000 global / $195.000 por crédito
--   Esp. Gestión TI: $5.500.000 global (solo global, posgrado)
-- ============================================================

INSERT INTO regla_cobro (modalidad_cobro, id_periodo, id_programa,
                          valor_global, valor_credito,
                          fecha_vigencia_desde, fecha_vigencia_hasta, estado)
SELECT 'GLOBAL', per.id_periodo, pro.id_programa,
        tarifas.valor_global, NULL,
        '2025-07-14', '2025-11-29', 'ACTIVA'
FROM periodo_academico per, programa_academico pro
JOIN (VALUES
    ('ING-SIS-01', 4800000.00),
    ('ADM-EMP-01', 3900000.00),
    ('ESP-GES-01', 5500000.00)
) AS tarifas(cod, valor_global) ON pro.codigo_programa = tarifas.cod
WHERE per.codigo_periodo = '2025-2';

INSERT INTO regla_cobro (modalidad_cobro, id_periodo, id_programa,
                          valor_global, valor_credito,
                          fecha_vigencia_desde, fecha_vigencia_hasta, estado)
SELECT 'CREDITOS', per.id_periodo, pro.id_programa,
        NULL, tarifas.valor_credito,
        '2025-07-14', '2025-11-29', 'ACTIVA'
FROM periodo_academico per, programa_academico pro
JOIN (VALUES
    ('ING-SIS-01', 215000.00),
    ('ADM-EMP-01', 195000.00)
    -- ESP-GES-01 no ofrece modalidad CREDITOS (posgrado solo global)
) AS tarifas(cod, valor_credito) ON pro.codigo_programa = tarifas.cod
WHERE per.codigo_periodo = '2025-2';


-- ============================================================
-- BLOQUE 7: ESTUDIANTES
--   8 estudiantes: 4 de Ing. Sistemas, 3 de Admón., 1 de Esp.
--   Cubren todos los escenarios de pago definidos arriba.
-- ============================================================

INSERT INTO estudiante (tipo_documento, numero_documento, primer_nombre, segundo_nombre,
                         primer_apellido, segundo_apellido, telefono_celular, telefono_fijo,
                         correo_electronico, direccion, fecha_nacimiento, fecha_ingreso,
                         id_programa)
SELECT x.tipo_doc, x.num_doc, x.p_nombre, x.s_nombre,
       x.p_apellido, x.s_apellido, x.tel_cel, x.tel_fijo,
       x.correo, x.direccion, x.fecha_nac::DATE, x.fecha_ing::DATE,
       p.id_programa
FROM programa_academico p
JOIN (VALUES
    -- Ingeniería de Sistemas
    ('CC','20020001','Sofía',    'María',   'Ramírez',  'Díaz',    '3100001001',NULL,        'sofia.ramirez@mail.com',       'Cra 45 #12-30, Barranquilla','2001-03-15','2022-01-20','ING-SIS-01'),
    ('CC','20020002','Miguel',   NULL,      'Torres',   'Almeida', '3100001002',NULL,        'miguel.torres@mail.com',       'Cl 72 #50-18, Barranquilla', '2000-07-22','2022-01-20','ING-SIS-01'),
    ('TI','20020003','Valeria',  'Andrea',  'Ospina',   NULL,      '3100001003','3740001','valeria.ospina@mail.com',        'Cra 38 #80-05, Soledad',     '2003-11-08','2023-07-18','ING-SIS-01'),
    ('CC','20020004','Sebastián','Felipe',  'Herrera',  'Mora',    '3100001004',NULL,        'sebastian.herrera@mail.com',   'Cl 30 #20-12, Barranquilla', '2001-05-30','2023-07-18','ING-SIS-01'),
    -- Administración de Empresas
    ('CC','20020005','Camila',   'Lucía',   'Pérez',    'Fuentes', '3100001005',NULL,        'camila.perez@mail.com',        'Cl 84 #45-22, Barranquilla', '2002-01-19','2022-07-18','ADM-EMP-01'),
    ('CC','20020006','Daniel',   NULL,      'Castro',   'Ríos',    '3100001006','3740002','daniel.castro@mail.com',         'Cra 55 #70-33, Malambo',     '2001-09-14','2023-01-20','ADM-EMP-01'),
    ('CC','20020007','Isabella', 'Paola',   'Morales',  'Vega',    '3100001007',NULL,        'isabella.morales@mail.com',    'Cra 21 #15-60, Barranquilla','2002-04-25','2023-01-20','ADM-EMP-01'),
    -- Especialización Gestión TI
    ('CC','20020008','Ricardo',  'Esteban', 'González', 'Serrano', '3100001008',NULL,        'ricardo.gonzalez@mail.com',    'Cl 93 #12-44, Barranquilla', '1990-12-03','2025-01-20','ESP-GES-01')
) AS x(tipo_doc, num_doc, p_nombre, s_nombre, p_apellido, s_apellido,
       tel_cel, tel_fijo, correo, direccion, fecha_nac, fecha_ing, cod_programa)
ON p.codigo_programa = x.cod_programa;


-- ============================================================
-- BLOQUE 8: INSCRIPCIONES Y DETALLA (asignaturas a cursar)
--   Solo estudiantes con modalidad CRÉDITOS requieren detalla.
--   Los de modalidad GLOBAL igual se inscriben (FK en volante).
-- ============================================================

-- Inscripciones en período 2025-2
INSERT INTO inscripcion (fecha_inscripcion, estado, id_estudiante, id_periodo_academico)
SELECT NOW(), 'ACTIVA',
       e.id_estudiante,
       p.id_periodo
FROM estudiante e
CROSS JOIN periodo_academico p
WHERE p.codigo_periodo = '2025-2'
  AND e.numero_documento IN (
      '20020001','20020002','20020003','20020004',
      '20020005','20020006','20020007','20020008'
  );

-- detalla: asignaturas de E3 (Valeria — CRÉDITOS, semestre 2, Ing. Sistemas)
--          Cursa 3 asignaturas = 10 créditos → $2.150.000
INSERT INTO detalla (id_asignatura, id_inscripcion)
SELECT a.id_asignatura, i.id_inscripcion
FROM inscripcion i
JOIN estudiante  e ON e.id_estudiante        = i.id_estudiante
JOIN periodo_academico p ON p.id_periodo     = i.id_periodo_academico
JOIN asignatura  a ON a.codigo_asignatura IN ('IS-MAT2', 'IS-EST1', 'IS-FIS2')
WHERE e.numero_documento = '20020003'
  AND p.codigo_periodo   = '2025-2';

-- detalla: asignaturas de E4 (Sebastián — CRÉDITOS con crédito financiero, sem 2)
--          Cursa 3 asignaturas = 9 créditos → $1.935.000 + cargo carné + lab
INSERT INTO detalla (id_asignatura, id_inscripcion)
SELECT a.id_asignatura, i.id_inscripcion
FROM inscripcion i
JOIN estudiante  e ON e.id_estudiante        = i.id_estudiante
JOIN periodo_academico p ON p.id_periodo     = i.id_periodo_academico
JOIN asignatura  a ON a.codigo_asignatura IN ('IS-MAT2', 'IS-ELE1', 'IS-BDA1')
WHERE e.numero_documento = '20020004'
  AND p.codigo_periodo   = '2025-2';


-- ============================================================
-- BLOQUE 9: VOLANTES DE MATRÍCULA
--   El trigger trg_volante_crear_cuenta crea la cuenta_corriente
--   automáticamente en cada INSERT.
--
--   E1 · Sofía    — GLOBAL  Ing.Sis  sem 3  → PAGADO
--   E2 · Miguel   — GLOBAL  Ing.Sis  sem 2  → PARCIAL (solo anticipo)
--   E3 · Valeria  — CRÉDITOS Ing.Sis sem 2  → PAGADO
--   E4 · Sebastián— CRÉDITOS Ing.Sis sem 2  → FINANCIADO (crédito ICETEX)
--   E5 · Camila   — GLOBAL  Admón.   sem 3  → PAGADO (con descuento)
--   E6a· Daniel   — GLOBAL  Admón.   sem 2  → GENERADO (sin pago — pendiente)
--   E6b· Isabella — GLOBAL  Admón.   sem 2  → GENERADO (sin pago — pendiente)
--   E7 · Ricardo  — GLOBAL  Esp.     sem 1  → pago RECHAZADO (no mueve cuenta)
--   E8 = E6a/E6b (sin pago, visibles en vista_estudiantes_pendientes_pago)
-- ============================================================

-- E1: Sofía — GLOBAL, Ing. Sistemas, semestre 3, generación INDIVIDUAL
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0001', NOW(), 3, 'INDIVIDUAL', 'PAGADO', 'GLOBAL',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username       = 'apalomino'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020001'
  AND pro.codigo_programa= 'ING-SIS-01'
  AND i.id_estudiante  = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;

-- E2: Miguel — GLOBAL, Ing. Sistemas, semestre 2
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0002', NOW(), 2, 'INDIVIDUAL', 'PARCIAL', 'GLOBAL',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username         = 'apalomino'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020002'
  AND pro.codigo_programa= 'ING-SIS-01'
  AND i.id_estudiante    = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;

-- E3: Valeria — CRÉDITOS, Ing. Sistemas, semestre 2
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0003', NOW(), 2, 'INDIVIDUAL', 'PAGADO', 'CREDITOS',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username         = 'lcastillo'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020003'
  AND pro.codigo_programa= 'ING-SIS-01'
  AND i.id_estudiante    = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;

-- E4: Sebastián — CRÉDITOS, Ing. Sistemas, semestre 2 (crédito financiero)
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0004', NOW(), 2, 'INDIVIDUAL', 'FINANCIADO', 'CREDITOS',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username         = 'lcastillo'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020004'
  AND pro.codigo_programa= 'ING-SIS-01'
  AND i.id_estudiante    = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;

-- E5: Camila — GLOBAL, Admón. Empresas, semestre 3 (con descuento)
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0005', NOW(), 3, 'INDIVIDUAL', 'PAGADO', 'GLOBAL',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username         = 'apalomino'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020005'
  AND pro.codigo_programa= 'ADM-EMP-01'
  AND i.id_estudiante    = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;

-- E6a: Daniel — GLOBAL, Admón. sem 2, lote MASIVA (sin pago → pendiente)
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0006', NOW(), 2, 'MASIVA', 'GENERADO', 'GLOBAL',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username         = 'lcastillo'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020006'
  AND pro.codigo_programa= 'ADM-EMP-01'
  AND i.id_estudiante    = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;

-- E6b: Isabella — GLOBAL, Admón. sem 2, lote MASIVA (sin pago → pendiente)
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0007', NOW(), 2, 'MASIVA', 'GENERADO', 'GLOBAL',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username         = 'lcastillo'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020007'
  AND pro.codigo_programa= 'ADM-EMP-01'
  AND i.id_estudiante    = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;

-- E7: Ricardo — GLOBAL, Esp. Gestión TI, sem 1 (pago será rechazado)
INSERT INTO volante_matricula
    (numero_volante, fecha_generacion, semestre_a_cursar, generacion_tipo,
     estado, modalidad_cobro, id_usuario, id_periodo, id_estudiante,
     id_programa, id_inscripcion)
SELECT 'VM-2025-2-0008', NOW(), 1, 'INDIVIDUAL', 'GENERADO', 'GLOBAL',
       u.id_usuario, per.id_periodo, e.id_estudiante, pro.id_programa,
       i.id_inscripcion
FROM usuario u, periodo_academico per, estudiante e,
     programa_academico pro, inscripcion i
WHERE u.username         = 'apalomino'
  AND per.codigo_periodo = '2025-2'
  AND e.numero_documento = '20020008'
  AND pro.codigo_programa= 'ESP-GES-01'
  AND i.id_estudiante    = e.id_estudiante
  AND i.id_periodo_academico = per.id_periodo;


-- ============================================================
-- BLOQUE 10: DETALLE_VOLANTE
--   El trigger trg_detalle_volante_cobro registra automáticamente
--   el movimiento COBRO en la cuenta_corriente de cada estudiante.
--
--   Regla de negocio: suma(COBRO) − suma(PAGO) = saldo.
--   En los escenarios pagados el saldo final debe ser 0.
-- ============================================================

-- E1 · Sofía — GLOBAL Ing. Sistemas
--      PMAT: 1 × $4.800.000 | PCAR: 1 × $35.000
--      Total cobros = $4.835.000
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PMAT', 1.00, 4800000.00),
    ('PCAR', 1.00,   35000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0001';

-- E2 · Miguel — GLOBAL Ing. Sistemas
--      PMAT: 1 × $4.800.000 | PCAR: 1 × $35.000
--      Total cobros = $4.835.000  (solo paga anticipo → saldo pendiente)
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PMAT', 1.00, 4800000.00),
    ('PCAR', 1.00,   35000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0002';

-- E3 · Valeria — CRÉDITOS Ing. Sistemas (IS-MAT2=4cr, IS-EST1=3cr, IS-FIS2=4cr → 11cr)
--      PCRE: 11 × $215.000 = $2.365.000 | PCAR: 1 × $35.000
--      Total cobros = $2.400.000
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PCRE', 11.00, 215000.00),
    ('PCAR',  1.00,  35000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0003';

-- E4 · Sebastián — CRÉDITOS Ing. Sistemas (IS-MAT2=4cr, IS-ELE1=2cr, IS-BDA1=3cr → 9cr)
--      PCRE: 9 × $215.000 = $1.935.000 | PCAR: 1 × $35.000 | PLAB: 1 × $120.000
--      Total cobros = $2.090.000  (cubierto por crédito ICETEX)
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PCRE',  9.00, 215000.00),
    ('PCAR',  1.00,  35000.00),
    ('PLAB',  1.00, 120000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0004';

-- E5 · Camila — GLOBAL Admón. Empresas
--      PMAT: 1 × $3.900.000 | PCAR: 1 × $35.000
--      Descuento: $390.000 (10 % por buen rendimiento)
--      Total cobros = $3.935.000 | Total pagos = $3.935.000 → saldo = 0
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PMAT', 1.00, 3900000.00),
    ('PCAR', 1.00,   35000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0005';

-- E6a · Daniel — GLOBAL Admón. Empresas (lote masivo)
--       PMAT: 1 × $3.900.000 | PCAR: 1 × $35.000
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PMAT', 1.00, 3900000.00),
    ('PCAR', 1.00,   35000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0006';

-- E6b · Isabella — GLOBAL Admón. Empresas (lote masivo)
--       PMAT: 1 × $3.900.000 | PCAR: 1 × $35.000
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PMAT', 1.00, 3900000.00),
    ('PCAR', 1.00,   35000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0007';

-- E7 · Ricardo — GLOBAL Esp. Gestión TI
--      PMAT: 1 × $5.500.000 | PCAR: 1 × $35.000
--      El pago posterior será RECHAZADO → no se genera movimiento PAGO
INSERT INTO detalle_volante (id_codigo_detalle, id_volante_matricula, cantidad, valor_unitario)
SELECT cd.id_codigo_detalle, vm.id_volante, x.cantidad, x.valor_unitario
FROM volante_matricula vm
JOIN (VALUES
    ('PMAT', 1.00, 5500000.00),
    ('PCAR', 1.00,   35000.00)
) AS x(cod, cantidad, valor_unitario) ON TRUE
JOIN codigo_detalle cd ON cd.codigo = x.cod
WHERE vm.numero_volante = 'VM-2025-2-0008';


-- ============================================================
-- BLOQUE 11: PAGOS
--   El trigger trg_pago_movimiento registra el movimiento
--   PAGO (abono) solo cuando estado_pago = 'APROBADO'.
--   Los pagos RECHAZADOS o PENDIENTES no afectan la cuenta.
--
--   NOTA: los INSERTs se hacen directamente con estado APROBADO
--   donde corresponde (el trigger dispara en UPDATE, pero la
--   función compara OLD IS DISTINCT FROM NEW, por lo que
--   insertar directamente como APROBADO también lo activa al
--   hacer el UPDATE posterior). Para simplificar el seed:
--   1) INSERT con estado PENDIENTE
--   2) UPDATE a APROBADO → dispara el trigger
-- ============================================================

-- E1 · Sofía — pago total $4.835.000 (PSE)
INSERT INTO pago (valor_pagado, fecha_pago, estado_pago, referencia_pago,
                  canal_pago, tipo_pago, id_volante_matricula, id_usuario)
SELECT 4835000.00, NOW(), 'PENDIENTE', 'PSE-2025-0001', 'PSE',  'TOTAL',
       vm.id_volante, u.id_usuario
FROM volante_matricula vm, usuario u
WHERE vm.numero_volante = 'VM-2025-2-0001' AND u.username = 'apalomino';

UPDATE pago SET estado_pago = 'APROBADO'
WHERE referencia_pago = 'PSE-2025-0001';

-- E2 · Miguel — anticipo $1.500.000 (CAJA) → saldo pendiente $3.335.000
INSERT INTO pago (valor_pagado, fecha_pago, estado_pago, referencia_pago,
                  canal_pago, tipo_pago, id_volante_matricula, id_usuario)
SELECT 1500000.00, NOW(), 'PENDIENTE', 'CAJ-2025-0001', 'CAJA', 'ANTICIPO',
       vm.id_volante, u.id_usuario
FROM volante_matricula vm, usuario u
WHERE vm.numero_volante = 'VM-2025-2-0002' AND u.username = 'apalomino';

UPDATE pago SET estado_pago = 'APROBADO'
WHERE referencia_pago = 'CAJ-2025-0001';

-- E3 · Valeria — pago total $2.400.000 (TRANSFERENCIA)
INSERT INTO pago (valor_pagado, fecha_pago, estado_pago, referencia_pago,
                  canal_pago, tipo_pago, id_volante_matricula, id_usuario)
SELECT 2400000.00, NOW(), 'PENDIENTE', 'TRF-2025-0001', 'TRANSFERENCIA', 'TOTAL',
       vm.id_volante, u.id_usuario
FROM volante_matricula vm, usuario u
WHERE vm.numero_volante = 'VM-2025-2-0003' AND u.username = 'lcastillo';

UPDATE pago SET estado_pago = 'APROBADO'
WHERE referencia_pago = 'TRF-2025-0001';

-- E4 · Sebastián — crédito financiero ICETEX $2.090.000
--     Se inserta como PENDIENTE, luego APROBADO.
--     El trigger detecta tipo_pago = 'CREDITO_FINANCIERO' y registra CRED.
INSERT INTO pago (valor_pagado, fecha_pago, estado_pago, referencia_pago,
                  canal_pago, tipo_pago, id_volante_matricula, id_usuario)
SELECT 2090000.00, NOW(), 'PENDIENTE', 'CRF-2025-0001', 'TRANSFERENCIA', 'CREDITO_FINANCIERO',
       vm.id_volante, u.id_usuario
FROM volante_matricula vm, usuario u
WHERE vm.numero_volante = 'VM-2025-2-0004' AND u.username = 'lcastillo';

UPDATE pago SET estado_pago = 'APROBADO'
WHERE referencia_pago = 'CRF-2025-0001';

-- E5 · Camila — pago con descuento del 10 %
--     Descuento: $390.000 (se registra como movimiento PAGO con código DESC)
--     Pago neto:  $3.545.000 (TARJETA)
--     Total pagos = $390.000 + $3.545.000 = $3.935.000 = total cobros → saldo 0

-- Paso 1: registrar descuento de Camila como pago tipo DESCUENTO
-- Descuento de Camila
INSERT INTO pago (valor_pagado, fecha_pago, estado_pago, referencia_pago,
                  canal_pago, tipo_pago, id_volante_matricula, id_usuario)
SELECT 390000.00, NOW(), 'PENDIENTE', 'DESC-2025-0001', 'CAJA', 'DESCUENTO',
       vm.id_volante, u.id_usuario
FROM volante_matricula vm, usuario u
WHERE vm.numero_volante = 'VM-2025-2-0005' AND u.username = 'apalomino';

UPDATE pago SET estado_pago = 'APROBADO'
WHERE referencia_pago = 'DESC-2025-0001';

-- Pago neto de Camila
INSERT INTO pago (valor_pagado, fecha_pago, estado_pago, referencia_pago,
                  canal_pago, tipo_pago, id_volante_matricula, id_usuario)
SELECT 3545000.00, NOW(), 'PENDIENTE', 'TAR-2025-0001', 'TARJETA', 'TOTAL',
       vm.id_volante, u.id_usuario
FROM volante_matricula vm, usuario u
WHERE vm.numero_volante = 'VM-2025-2-0005' AND u.username = 'apalomino';

UPDATE pago SET estado_pago = 'APROBADO'
WHERE referencia_pago = 'TAR-2025-0001';

-- E6a · Daniel — sin pago (queda visible en vista_estudiantes_pendientes_pago)
-- E6b · Isabella — sin pago (ídem)
-- (No hay INSERT en pago para VM-2025-2-0006 ni VM-2025-2-0007)

-- E7 · Ricardo — pago RECHAZADO (no genera movimiento PAGO en cuenta)
INSERT INTO pago (valor_pagado, fecha_pago, estado_pago, referencia_pago,
                  canal_pago, tipo_pago, id_volante_matricula, id_usuario)
SELECT 5535000.00, NOW(), 'RECHAZADO', 'PSE-2025-RECH', 'PSE', 'TOTAL',
       vm.id_volante, u.id_usuario
FROM volante_matricula vm, usuario u
WHERE vm.numero_volante = 'VM-2025-2-0008' AND u.username = 'apalomino';
-- Estado RECHAZADO desde el INSERT → el trigger no disparará el abono.


-- ============================================================
-- BLOQUE 12: VERIFICACIÓN INLINE
--   Consultas de comprobación que se ejecutan junto al seed.
--   Los resultados deben coincidir con los valores esperados.
-- ============================================================

-- V1: Saldos de cuentas corrientes (COBROS − PAGOS)
--     Esperado: Sofía=0, Miguel>0, Valeria=0, Sebastián=0,
--               Camila=0, Daniel>0, Isabella>0, Ricardo>0
DO $$
DECLARE
    rec RECORD;
    ok  BOOLEAN := TRUE;
BEGIN
    RAISE NOTICE '======================================';
    RAISE NOTICE ' VERIFICACIÓN: vista_balance_cuenta_corriente';
    RAISE NOTICE '--------------------------------------';
    FOR rec IN
        SELECT nombre_estudiante, total_cobros, total_pagos, saldo
        FROM vista_balance_cuenta_corriente
        ORDER BY nombre_estudiante
    LOOP
        RAISE NOTICE '  %-22s  cobros=%-12s  pagos=%-12s  saldo=%s',
            rec.nombre_estudiante,
            rec.total_cobros::TEXT,
            rec.total_pagos::TEXT,
            rec.saldo::TEXT;
        IF rec.saldo < 0 THEN
            RAISE WARNING '  *** Saldo negativo en cuenta de %!', rec.nombre_estudiante;
            ok := FALSE;
        END IF;
    END LOOP;
    IF ok THEN
        RAISE NOTICE '  ✓ Ningún saldo negativo detectado.';
    END IF;
    RAISE NOTICE '======================================';
END;
$$;

-- V2: Ingreso esperado por programa
DO $$
DECLARE rec RECORD;
BEGIN
    RAISE NOTICE '======================================';
    RAISE NOTICE ' VERIFICACIÓN: vista_ingreso_esperado';
    RAISE NOTICE '--------------------------------------';
    FOR rec IN
        SELECT nombre_programa, total_estudiantes, ingreso_esperado_total
        FROM vista_ingreso_esperado
        ORDER BY nombre_programa
    LOOP
        RAISE NOTICE '  %-40s  estudiantes=%s  esperado=%s',
            rec.nombre_programa, rec.total_estudiantes, rec.ingreso_esperado_total;
    END LOOP;
    RAISE NOTICE '======================================';
END;
$$;

-- V3: Pendientes de pago (debe mostrar Miguel, Daniel, Isabella, Ricardo)
DO $$
DECLARE rec RECORD;
BEGIN
    RAISE NOTICE '======================================';
    RAISE NOTICE ' VERIFICACIÓN: vista_estudiantes_pendientes_pago';
    RAISE NOTICE '--------------------------------------';
    FOR rec IN
        SELECT nombre_estudiante, nombre_programa, saldo_pendiente
        FROM vista_estudiantes_pendientes_pago
        ORDER BY nombre_estudiante
    LOOP
        RAISE NOTICE '  %-22s  %-35s  pendiente=%s',
            rec.nombre_estudiante, rec.nombre_programa, rec.saldo_pendiente;
    END LOOP;
    RAISE NOTICE '======================================';
END;
$$;

-- V4: Ingreso real (solo pagos APROBADO)
DO $$
DECLARE rec RECORD;
BEGIN
    RAISE NOTICE '======================================';
    RAISE NOTICE ' VERIFICACIÓN: vista_ingreso_real';
    RAISE NOTICE '--------------------------------------';
    FOR rec IN
        SELECT nombre_programa, ingreso_real_recibido
        FROM vista_ingreso_real
        ORDER BY nombre_programa
    LOOP
        RAISE NOTICE '  %-40s  ingreso_real=%s',
            rec.nombre_programa, rec.ingreso_real_recibido;
    END LOOP;
    RAISE NOTICE '======================================';
END;
$$;

-- V5: Cartera de créditos financieros (debe mostrar Sebastián)
DO $$
DECLARE rec RECORD;
BEGIN
    RAISE NOTICE '======================================';
    RAISE NOTICE ' VERIFICACIÓN: vista_creditos_financieros';
    RAISE NOTICE '--------------------------------------';
    FOR rec IN
        SELECT nombre_estudiante, nombre_programa, valor_credito
        FROM vista_creditos_financieros
        ORDER BY nombre_estudiante
    LOOP
        RAISE NOTICE '  %-22s  %-35s  credito=%s',
            rec.nombre_estudiante, rec.nombre_programa, rec.valor_credito;
    END LOOP;
    RAISE NOTICE '======================================';
END;
$$;

COMMIT;

/*
============================================================
 VALORES ESPERADOS TRAS LA EJECUCIÓN
 ─────────────────────────────────────────────────────────
 vista_balance_cuenta_corriente
   Sofía Ramírez        cobros=4.835.000  pagos=4.835.000  saldo=0
   Miguel Torres        cobros=4.835.000  pagos=1.500.000  saldo=3.335.000
   Valeria Ospina       cobros=2.400.000  pagos=2.400.000  saldo=0
   Sebastián Herrera    cobros=2.090.000  pagos=2.090.000  saldo=0
                     (CRED 2.090.000 — registrado por trigger según tipo_pago)
   Camila Pérez         cobros=3.935.000  pagos=3.935.000  saldo=0
   Daniel Castro        cobros=3.935.000  pagos=0          saldo=3.935.000
   Isabella Morales     cobros=3.935.000  pagos=0          saldo=3.935.000
   Ricardo González     cobros=5.535.000  pagos=0          saldo=5.535.000

 vista_ingreso_esperado  (2025-2)
   Ingeniería de Sistemas     4 est.  total ≈ 14.160.000
   Administración de Empresas 3 est.  total = 11.805.000
   Especialización Gestión TI 1 est.  total =  5.535.000

 vista_estudiantes_pendientes_pago
   Miguel Torres        Ingeniería de Sistemas           3.335.000
   Daniel Castro        Administración de Empresas       3.935.000
   Isabella Morales     Administración de Empresas       3.935.000
   Ricardo González     Especialización en Gestión TI    5.535.000

 vista_ingreso_real  (2025-2)
   Ingeniería de Sistemas     ≈ 10825000.00 (Sofía+Valeria+Sebastián+Miguel)
   Administración de Empresas = 3.545.000  (Camila neto)

 vista_creditos_financieros
   Sebastián Herrera    Ingeniería de Sistemas  2.090.000
============================================================
*/
