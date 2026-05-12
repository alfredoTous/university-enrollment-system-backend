from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPDigest
from sqlalchemy.orm import Session
from datetime import datetime
import uuid

import schemas
import models
import database
from routers import auth

router = APIRouter(prefix="/cobros")


# -- FUNCTIONS -----------------------------------------------------------

# Calcula el monto del cobro según la modalidad
def calcular_monto(id_programa: int, data: schemas.GenerarCobro, db: Session) -> tuple[float, float]:
    regla = db.query(models.ReglaCobro).filter(
        models.ReglaCobro.modalidad_cobro == data.modalidad_cobro,
        models.ReglaCobro.id_periodo      == data.id_periodo,
        models.ReglaCobro.id_programa     == id_programa
    ).first()
    if not regla:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Reglas de cobro no encontrada")
    
    if data.modalidad_cobro == "GLOBAL":
        if not regla.valor_global:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "La regla no tiene valor global definido")
        return float(regla.valor_global), float(regla.valor_global)

    elif data.modalidad_cobro == "POR_CREDITOS":
        if not data.id_asignaturas:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Modalidad POR_CREDITOS requiere lista de asignaturas")

        total_creditos = 0
        
        for id_asig in data.id_asignaturas:
            plan = db.query(models.PlanEstudio).filter(
                models.PlanEstudio.id_programa   == id_programa,
                models.PlanEstudio.id_asignatura == id_asig
            ).first()
            if not plan:
                raise HTTPException(status.HTTP_404_NOT_FOUND, f"Asignatura {id_asig} no esta en el plan del programa")

            total_creditos += plan.creditos_plan
        
        if regla.valor_credito:
            monto_total = total_creditos * float(regla.valor_credito)
            return monto_total, float(regla.valor_credito)
        
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Error Inesperado")
    else:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Modalidad inválida")


def get_or_create_inscripcion(id_estudiante, id_periodo, db: Session) -> models.Inscripcion:
    inscripcion = db.query(models.Inscripcion).filter(
        models.Inscripcion.id_estudiante == id_estudiante, 
        models.Inscripcion.id_periodo_academico == id_periodo
    ).first()

    if not inscripcion:
        inscripcion = models.Inscripcion(
            id_estudiante = id_estudiante,
            id_periodo_academico = id_periodo,
        )
        db.add(inscripcion)
        db.flush()

    return inscripcion
    


def get_or_create_cuenta(id_estudiante, id_periodo, db: Session) -> models.CuentaCorriente:
    cuenta = db.query(models.CuentaCorriente).filter(
        models.CuentaCorriente.id_estudiante == id_estudiante,
        models.CuentaCorriente.id_periodo    == id_periodo
    ).first()

    if not cuenta:
        cuenta = models.CuentaCorriente(
            id_estudiante = id_estudiante,
            id_periodo    = id_periodo
        )
        db.add(cuenta)
        db.flush()

    return cuenta

# Genera un cobro individual para un estudiante
def generar_numero_volante() -> str:
    return f"VOL-{datetime.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"

#-------------------------------------------------------------------------

# -- ENDPOINTS -----------------------------------------------------------
@router.post("/generar", response_model=schemas.VolanteOut, status_code=201)
def generar_cobro(
        data: schemas.GenerarCobro,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR","ASISTENTE")),
        db: Session = Depends(database.get_db)
):
    estudiante = db.query(models.Estudiante).filter(models.Estudiante.id_estudiante == data.id_estudiante).first()
    if not estudiante:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Estudiante no encontrado")

    if not db.query(models.PeriodoAcademico).filter(models.PeriodoAcademico.id_periodo == data.id_periodo).first():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Periodo no encontrado")


    codigo_detalle = db.query(models.CodigoDetalle).filter(
        models.CodigoDetalle.codigo == data.codigo_cobro,
        models.CodigoDetalle.grupo  == "COBRO"
    ).first()

    if not codigo_detalle:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Código de cobro '{data.codigo_cobro}' no encontrado")

    # Calcular monto
    monto_total, valor_unitario = calcular_monto(estudiante.id_programa, data, db)
    cantidad = 1
    
    if data.modalidad_cobro == "POR_CREDITOS" and data.id_asignaturas:
        cantidad = len(data.id_asignaturas)

    inscripcion = get_or_create_inscripcion(data.id_estudiante, data.id_periodo, db)
    get_or_create_cuenta(data.id_estudiante, data.id_periodo, db)

    # Crear volante
    volante = models.VolanteMatricula(
        numero_volante    = generar_numero_volante(),
        semestre_a_cursar = data.semestre,
        generacion_tipo   = "INDIVIDUAL",
        modalidad_cobro   = data.modalidad_cobro,
        id_usuario        = current_user.id_usuario,
        id_periodo        = data.id_periodo,
        id_estudiante     = data.id_estudiante,
        id_programa       = estudiante.id_programa,
        id_inscripcion    = inscripcion.id_inscripcion,
    )

    db.add(volante)
    db.flush()

    if data.modalidad_cobro == "POR_CREDITOS" and data.id_asignaturas:
        for id_asig in data.id_asignaturas:
            db.add(models.Detalla(
                id_asignatura  = id_asig,
                id_inscripcion = inscripcion.id_inscripcion
            ))

    detalle = models.DetalleVolante(
        id_codigo_detalle = codigo_detalle.id_codigo_detalle,
        id_volante_matricula = volante.id_volante,
        cantidad             = cantidad,
        valor_unitario       = valor_unitario,
    )
    db.add(detalle)
    db.commit()
    db.refresh(volante)
    return schemas.VolanteOut(
        id_volante        = volante.id_volante,
        numero_volante    = volante.numero_volante,
        fecha_generacion  = str(volante.fecha_generacion),
        semestre_a_cursar = volante.semestre_a_cursar,
        generacion_tipo   = volante.generacion_tipo,
        estado            = volante.estado,
        modalidad_cobro   = volante.modalidad_cobro,
        id_estudiante     = volante.id_estudiante,
        id_periodo        = volante.id_periodo,
        id_programa       = volante.id_programa,
        monto_total       = monto_total,
        detalles          = [schemas.DetalleVolanteOut(
                                id_codigo_detalle    = d.id_codigo_detalle,
                                id_volante_matricula = d.id_volante_matricula,
                                cantidad             = float(d.cantidad),
                                valor_unitario       = float(d.valor_unitario),
                                )
                            for d in volante.detalles],
    )


# Genera cobros para todos los estudiantes activos de todos los programas
@router.post("/generar-masivo", status_code=201)
def generar_cobro_masivo(
        id_periodo: int,
        semestre: int,
        modalidad_cobro: str,
        codigo_cobro: str,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "ASISTENTE")),
        db: Session = Depends(database.get_db)
):
    estudiantes = db.query(models.Estudiante).all()
    resultados = {"generados": 0, "errores": []}

    for estudiante in estudiantes:
        try:
            data = schemas.GenerarCobro(
                id_estudiante=estudiante.id_estudiante,
                id_periodo=estudiante.id_periodo,
                semestre=semestre,
                modalidad_cobro=modalidad_cobro,
                codigo_cobro=codigo_cobro
            )
            generar_cobro(data, current_user, db)
            resultados["generados"] += 1
        except Exception as e:
            resultados["errores"].append({
                "id_estudiante": estudiante.id_estudiante,
                "error": str(e)
            })

    return resultados


# Registra un pago sobre un volante
@router.post("/pagar", response_model=schemas.PagoOut, status_code=201)
def registrar_pago(
        data: schemas.RegistrarPago,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "ASISTENTE")),
        db: Session = Depends(database.get_db)
):
    volante = db.query(models.VolanteMatricula).filter(models.VolanteMatricula.id_volante == data.id_volante_matricula).first()
    if not volante:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Volante no encontrado")

    codigo = db.query(models.CodigoDetalle).filter(models.CodigoDetalle.codigo == data.tipo_pago, models.CodigoDetalle.grupo == "PAGO").first()

    if not codigo:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Codigo de pago {data.tipo_pago} no encontrado")

    pago = models.Pago(
        valor_pagado         = data.valor_pagado,
        estado_pago          = "APROBADO",
        referencia_pago      = data.referencia_pago,
        canal_pago           = data.canal_pago,
        tipo_pago            = data.tipo_pago,
        id_volante_matricula = data.id_volante_matricula,
        id_usuario           = current_user.id_usuario
    )

    db.add(pago)
    db.commit()
    db.refresh(pago)
    return schemas.PagoOut(
        id_pago              = pago.id_pago,
        valor_pagado         = float(pago.valor_pagado),
        fecha_pago           = str(pago.fecha_pago),
        estado_pago          = pago.estado_pago,
        referencia_pago      = pago.referencia_pago,
        canal_pago           = pago.canal_pago,
        tipo_pago            = pago.tipo_pago,
        id_volante_matricula = pago.id_volante_matricula,
    )


# Muestra la cuenta corriente del estudiante con balance
@router.get("/cuenta-corriente/{id_estudiante}/{id_periodo}")
def get_cuenta_corriente(
        id_estudiante: int,
        id_periodo: int,
        current_user: models.Usuario = Depends(auth.get_current_user),
        db: Session = Depends(database.get_db)
):
    cuenta = db.query(models.CuentaCorriente).filter(
        models.CuentaCorriente.id_estudiante == id_estudiante,
        models.CuentaCorriente.id_periodo    == id_periodo
    ).first()

    if not cuenta:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cuenta corriente no encontrada")
    
    total_cobros = sum(
        float(m.valor) for m in cuenta.movimientos
        if m.codigo_detalle.grupo == "COBRO"
    )
    total_pagos = sum(
        float(m.valor) for m in cuenta.movimientos
        if m.codigo_detalle.grupo == "PAGO"
    )

    movimientos_out = [
        schemas.MovimientoOut(
            id_cuenta_corriente = m.id_cuenta_corriente,
            numero_secuencia    = m.numero_secuencia,
            id_codigo_detalle   = m.id_codigo_detalle,
            codigo              = m.codigo_detalle.codigo,
            descripcion         = m.codigo_detalle.descripcion,
            tipo_origen         = m.tipo_origen,
            fecha_movimiento    = str(m.fecha_movimiento),
            valor               = float(m.valor),
        )
        for m in cuenta.movimientos
    ]

    return schemas.CuentaCorrienteOut(
        id_cuenta      = cuenta.id_cuenta,
        id_estudiante  = cuenta.id_estudiante,
        id_periodo     = cuenta.id_periodo,
        estado         = cuenta.estado,
        fecha_apertura = str(cuenta.fecha_apertura),
        total_cobros   = total_cobros,
        total_pagos    = total_pagos,
        balance        = total_cobros - total_pagos,
        movimientos    = movimientos_out,
    )


