from pydantic import BaseModel
from typing import Optional


# Data schemas used for POST data validation

# USERS
class UsuarioCreate(BaseModel):
    # Datos de persona
    tipo_documento   : str
    numero_documento : str
    primer_nombre    : str
    segundo_nombre   : Optional[str] = None
    primer_apellido  : str
    segundo_apellido : Optional[str] = None
    correo_personal  : str
    telefono_contacto: Optional[str] = None
    # Datos de usuario
    username            : str
    password            : str
    correo_notificacion : str
    nombre_rol          : str   # "ADMINISTRADOR", "SUPERVISOR", "ASISTENTE"

    # Campo secreto para crear cuenta de administrador la primera vez
    admin_secret: Optional[str] = None


class UsuarioOut(BaseModel):
    id_usuario  : int
    username    : str
    estado      : str
    correo_notificacion: str
    nombre_rol  : str
    primer_nombre   : str
    primer_apellido : str
    correo_personal : str
 
    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    primer_nombre       : Optional[str] = None
    primer_apellido     : Optional[str] = None
    username            : Optional[str] = None
    correo_personal     : Optional[str] = None
    correo_notificacion : Optional[str] = None
    telefono_contacto   : Optional[str] = None
    nombre_rol          : Optional[str] = None
 
class PasswordUpdate(BaseModel):
    new_password: str
 
#--------------------------------


# AUTH
class Token(BaseModel):
    access_token: str
    token_type: str
    user: UsuarioOut

#-------------------------------



# CODIGOS DE DETALLE
class CodigoDetalleCreate(BaseModel):
    codigo      : str
    descripcion : str
    grupo       : str  # "COBRO" o "PAGO"

class CodigoDetalleUpdate(BaseModel):
    descripcion : Optional[str] = None
    grupo       : Optional[str] = None
    estado      : Optional[str] = None

class CodigoDetalleOut(BaseModel):
    id_codigo_detalle : int
    codigo            : str
    descripcion       : str
    grupo             : str
    estado            : str

    class Config:
        from_attributes = True


# PROGRAMAS ACADÉMICOS
class ProgramaCreate(BaseModel):
    codigo_programa    : str
    nombre_programa    : str
    duracion_semestres : int
    modalidad_programa : str  # PRESENCIAL, VIRTUAL, HIBRIDO
    nivel_formacion    : str  # PREGRADO, POSGRADO, TECNICO

class ProgramaUpdate(BaseModel):
    nombre_programa    : Optional[str] = None
    duracion_semestres : Optional[int] = None
    modalidad_programa : Optional[str] = None
    nivel_formacion    : Optional[str] = None
    estado             : Optional[str] = None

class ProgramaOut(BaseModel):
    id_programa        : int
    codigo_programa    : str
    nombre_programa    : str
    duracion_semestres : int
    modalidad_programa : str
    nivel_formacion    : str
    estado             : str

    class Config:
        from_attributes = True


# ASIGNATURAS
class AsignaturaCreate(BaseModel):
    codigo_asignatura : str
    nombre_asignatura : str
    tipo_asignatura   : str  # OBLIGATORIA, ELECTIVA
    creditos          : int

class AsignaturaUpdate(BaseModel):
    nombre_asignatura : Optional[str] = None
    tipo_asignatura   : Optional[str] = None
    creditos          : Optional[int] = None
    estado            : Optional[str] = None

class AsignaturaOut(BaseModel):
    id_asignatura     : int
    codigo_asignatura : str
    nombre_asignatura : str
    tipo_asignatura   : str
    creditos          : int
    estado            : str

    class Config:
        from_attributes = True


# PLAN DE ESTUDIO
class PlanEstudioCreate(BaseModel):
    id_asignatura  : int
    semestre       : int
    creditos_plan  : int
    es_obligatoria : bool = True

class PlanEstudioOut(BaseModel):
    id_programa    : int
    id_asignatura  : int
    semestre       : int
    creditos_plan  : int
    es_obligatoria : bool
    asignatura     : AsignaturaOut

    class Config:
        from_attributes = True



# PERIODOS ACADÉMICOS
class PeriodoCreate(BaseModel):
    codigo_periodo : str        # ej: 2025-1
    numero_periodo : int        # 1 o 2
    anio           : int        # 2025
    fecha_inicio   : str        # "2025-01-20"
    fecha_fin      : str        # "2025-06-15"

class PeriodoUpdate(BaseModel):
    fecha_inicio   : Optional[str] = None
    fecha_fin      : Optional[str] = None
    estado         : Optional[str] = None

class PeriodoOut(BaseModel):
    id_periodo     : int
    codigo_periodo : str
    numero_periodo : int
    anio           : int
    fecha_inicio   : str
    fecha_fin      : str
    estado         : str

    class Config:
        from_attributes = True


# ESTUDIANTES
class EstudianteCreate(BaseModel):
    tipo_documento     : str
    numero_documento   : str
    primer_nombre      : str
    segundo_nombre     : Optional[str] = None
    primer_apellido    : str
    segundo_apellido   : Optional[str] = None
    telefono_celular   : Optional[str] = None
    telefono_fijo      : Optional[str] = None
    correo_electronico : str
    direccion          : Optional[str] = None
    fecha_nacimiento   : Optional[str] = None
    id_programa        : int

class EstudianteUpdate(BaseModel):
    primer_nombre      : Optional[str] = None
    primer_apellido    : Optional[str] = None
    telefono_celular   : Optional[str] = None
    telefono_fijo      : Optional[str] = None
    correo_electronico : Optional[str] = None
    direccion          : Optional[str] = None
    id_programa        : Optional[int] = None

class EstudianteOut(BaseModel):
    id_estudiante      : int
    tipo_documento     : str
    numero_documento   : str
    primer_nombre      : str
    segundo_nombre     : Optional[str]
    primer_apellido    : str
    segundo_apellido   : Optional[str]
    telefono_celular   : Optional[str]
    correo_electronico : str
    direccion          : Optional[str]
    fecha_ingreso      : str
    id_programa        : int
    nombre_programa    : Optional[str] = None

    class Config:
        from_attributes = True


# REGLAS DE COBRO
class ReglaCobro(BaseModel):
    modalidad_cobro      : str   # GLOBAL o POR_CREDITOS
    id_periodo           : int
    id_programa          : int
    valor_global         : Optional[float] = None  # solo si modalidad es GLOBAL
    valor_credito        : Optional[float] = None  # solo si modalidad es POR_CREDITOS
    fecha_vigencia_desde : Optional[str]  = None
    fecha_vigencia_hasta : Optional[str]  = None

class ReglaCobroUpdate(BaseModel):
    valor_global         : Optional[float] = None
    valor_credito        : Optional[float] = None
    fecha_vigencia_hasta : Optional[str]   = None
    estado               : Optional[str]   = None

class ReglaCobroOut(BaseModel):
    modalidad_cobro      : str
    id_periodo           : int
    id_programa          : int
    valor_global         : Optional[float]
    valor_credito        : Optional[float]
    fecha_vigencia_desde : str
    fecha_vigencia_hasta : Optional[str]
    estado               : str

    class Config:
        from_attributes = True


# COBROS
class GenerarCobro(BaseModel):
    id_estudiante   : int
    id_periodo      : int
    semestre        : int
    modalidad_cobro : str        # GLOBAL o POR_CREDITOS
    id_asignaturas  : Optional[list[int]] = None  # solo si es POR_CREDITOS
    codigo_cobro    : str        # ej: PMAT o PCRE

class DetalleVolanteOut(BaseModel):
    id_codigo_detalle    : int
    id_volante_matricula : int
    cantidad             : float
    valor_unitario       : float

    class Config:
        from_attributes = True

class VolanteOut(BaseModel):
    id_volante        : int
    numero_volante    : str
    fecha_generacion  : str
    semestre_a_cursar : int
    generacion_tipo   : str
    estado            : str
    modalidad_cobro   : str
    id_estudiante     : int
    id_periodo        : int
    id_programa       : int
    monto_total       : float
    detalles          : list[DetalleVolanteOut] = []

    class Config:
        from_attributes = True


# PAGOS
class RegistrarPago(BaseModel):
    id_volante_matricula : int
    valor_pagado         : float
    canal_pago           : str   # CAJA, PSE, TARJETA
    tipo_pago            : str   # MPAG, ANT, DESC, CRED
    referencia_pago      : str

class PagoOut(BaseModel):
    id_pago              : int
    valor_pagado         : float
    fecha_pago           : str
    estado_pago          : str
    referencia_pago      : str
    canal_pago           : str
    tipo_pago            : str
    id_volante_matricula : int

    class Config:
        from_attributes = True


# CUENTA CORRIENTE
class MovimientoOut(BaseModel):
    id_cuenta_corriente   : int
    numero_secuencia      : int
    id_codigo_detalle     : int
    codigo                : str
    descripcion           : str
    tipo_origen           : str
    fecha_movimiento      : str
    valor                 : float

    class Config:
        from_attributes = True

class CuentaCorrienteOut(BaseModel):
    id_cuenta      : int
    id_estudiante  : int
    id_periodo     : int
    estado         : str
    fecha_apertura : str
    total_cobros   : float
    total_pagos    : float
    balance        : float
    movimientos    : list[MovimientoOut] = []

    class Config:
        from_attributes = True
