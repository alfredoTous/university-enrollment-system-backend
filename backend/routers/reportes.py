from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text

import database
from routers.auth import get_current_user

router = APIRouter(prefix="/reportes", tags=["reportes"])


@router.get("/resumen-estudiantes")
def reporte_resumen_estudiantes(
    id_periodo: int | None = None,
    db: Session = Depends(database.get_db),
    current_user = Depends(get_current_user)
):
    """
    Reporte 1: Listado de estudiantes con programa, modalidad y monto.
    GET /reportes/resumen-estudiantes?id_periodo=1
    """
    query = "SELECT * FROM vista_resumen_estudiantes"
    if id_periodo:
        query += f" WHERE id_periodo = {id_periodo}"
    query += " ORDER BY nombre_estudiante"

    rows = db.execute(text(query)).mappings().all()
    return [dict(row) for row in rows]


@router.get("/ingreso-esperado")
def reporte_ingreso_esperado(
    id_periodo: int | None = None,
    db: Session = Depends(database.get_db),
    current_user = Depends(get_current_user)
):
    """
    Reporte 2: Ingreso esperado totalizado por periodo y programa.
    GET /reportes/ingreso-esperado?id_periodo=1
    """
    query = "SELECT * FROM vista_ingreso_esperado"
    if id_periodo:
        query += f" WHERE id_periodo = {id_periodo}"
    query += " ORDER BY codigo_periodo, nombre_programa"

    rows = db.execute(text(query)).mappings().all()
    return [dict(row) for row in rows]


@router.get("/pendientes-pago")
def reporte_pendientes_pago(
    id_periodo  : int,
    id_programa : int,
    db: Session = Depends(database.get_db),
    current_user = Depends(get_current_user)
):
    """
    Reporte 3: Estudiantes pendientes de pago filtrado por programa.
    GET /reportes/pendientes-pago?id_periodo=1&id_programa=1
    """
    query = text("""
        SELECT * FROM vista_estudiantes_pendientes_pago
        WHERE id_periodo  = :id_periodo
          AND id_programa = :id_programa
        ORDER BY nombre_estudiante
    """)
    rows = db.execute(query, {"id_periodo": id_periodo, "id_programa": id_programa}).mappings().all()
    return [dict(row) for row in rows]


@router.get("/ingreso-real")
def reporte_ingreso_real(
    id_periodo: int | None = None,
    db: Session = Depends(database.get_db),
    current_user = Depends(get_current_user)
):
    """
    Reporte 4: Ingreso real recibido en el periodo.
    GET /reportes/ingreso-real?id_periodo=1
    """
    query = "SELECT * FROM vista_ingreso_real"
    if id_periodo:
        query += f" WHERE id_periodo = {id_periodo}"
    query += " ORDER BY codigo_periodo, nombre_programa"

    rows = db.execute(text(query)).mappings().all()
    return [dict(row) for row in rows]


@router.get("/creditos-financieros")
def reporte_creditos_financieros(
    id_periodo: int | None = None,
    db: Session = Depends(database.get_db),
    current_user = Depends(get_current_user)
):
    """
    Reporte 5: Estudiantes con crédito financiero y total de cartera.
    GET /reportes/creditos-financieros?id_periodo=1
    """
    query = "SELECT * FROM vista_creditos_financieros"
    params = {}
    if id_periodo:
        query += " WHERE id_periodo = :id_periodo"
        params["id_periodo"] = id_periodo
    query += " ORDER BY nombre_estudiante"

    rows = db.execute(text(query), params).mappings().all()
    total_cartera = sum(float(row["valor_credito"]) for row in rows)

    return {
        "total_cartera" : total_cartera,
        "estudiantes"   : [dict(row) for row in rows]
    }
