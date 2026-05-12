from operator import mod
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.sql.functions import mode

import schemas
import database
import models
from routers import auth


router = APIRouter(prefix="/programas", tags=["programas"])


# -- PROGRAMAS ----------------------------------------------
@router.get("/", response_model=list[schemas.ProgramaOut])
def get_programas(
    db: Session = Depends(database.get_db)
):
    return db.query(models.ProgramaAcademico).all()

@router.get("/{id}", response_model=schemas.ProgramaOut)
def get_programa(
    id: int,
    db: Session = Depends(database.get_db)
):
    programa = db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == id).first()
    if not programa:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Programa no encontrado")
    return programa


@router.post("/", response_model=schemas.ProgramaOut, status_code=201)
def create_programa(
    data: schemas.ProgramaCreate,
    current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
    db: Session = Depends(database.get_db),
):
    exists = db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == data.codigo_programa).first()
    if exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Codigo de programa ya existe")

    programa = models.ProgramaAcademico(**data.model_dump())
    db.add(programa)
    db.commit()
    db.refresh(programa)
    return programa


@router.put("/id", response_model=schemas.ProgramaOut)
def update_programa(
    id: int,
    data: schemas.ProgramaUpdate,
    current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
    db: Session = Depends(database.get_db)
):

    programa = db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == id).first()
    if not programa:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Programa no encontrado")

    if data.nombre_programa:
        programa.nombre_programa = data.nombre_programa
    if data.duracion_semestres:
        programa.duracion_semestres = data.duracion_semestres
    if data.modalidad_programa:
        programa.modalidad_programa = data.modalidad_programa
    if data.nivel_formacion:
        programa.nivel_formacion = data.nivel_formacion
    if data.estado:
        programa.estado = data.estado

    db.commit()
    db.refresh(programa)
    return programa


router.delete("/{id}", status_code=204)
def delete_programa(
    id: int,
    current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
    db: Session = Depends(database.get_db)
):
    programa = db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == id).first()

    if not programa:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Programa no encontrado")
    
    db.delete(programa)
    db.commit()
# ---------------------------------------------------------


# -- ASIGNATURAS ------------------------------------------

@router.get("/asignaturas/", response_model=list[schemas.AsignaturaOut])
def get_asignaturas(
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    return db.query(models.Asignatura).all()


@router.post("/asignaturas/", response_model=schemas.AsignaturaOut)
def create_asignatura(
    data: schemas.AsignaturaCreate,
    current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
    db: Session = Depends(database.get_db)
):
    exists = db.query(models.Asignatura).filter(models.Asignatura.codigo_asignatura == data.codigo_asignatura).first()
    if exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El codigo de asignatura ya existe")
    
    asignatura = models.Asignatura(**data.model_dump())
    db.add(asignatura)
    db.commit()
    db.refresh(asignatura)
    return asignatura


@router.put("/asignaturas/{id}", response_model=schemas.AsignaturaOut)
def update_asignatura(
        id: int,
        data: schemas.AsignaturaUpdate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    asignatura = db.query(models.Asignatura).filter(models.Asignatura.id_asignatura == id).first()
    if not asignatura:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Id de asignatura no existe")
    
    for key, value in data.model_dump(exclude_none=True).items():
        setattr(asignatura, key, value)
    
    db.commit()
    db.refresh(asignatura)
    return asignatura


@router.delete("/asignaturas/{id}", status_code=204)
def delete_asignatura(
        id: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    asignatura = db.query(models.Asignatura).filter(models.Asignatura.id_asignatura == id).first()
    
    if not asignatura:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Asignatura no encontrada")
    
    db.delete(asignatura)
    db.commit()
# ---------------------------------------------------------------------------


# -- PLAN ESTUDIO -----------------------------------------------------------
@router.get("/{id}/plan", response_model=list[schemas.PlanEstudioOut])
def get_plan(
        id: int,
        db: Session = Depends(database.get_db)
):
    programa = db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == id).first()
    
    if not programa:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Programa no encontrado")

    plan = db.execute(select(models.PlanEstudio).where(models.PlanEstudio.id_programa == id).order_by(models.PlanEstudio.semestre)).scalars().all()
    return plan



@router.post("/{id}/plan", response_model=schemas.PlanEstudioOut, status_code=201)
def add_asignatura_plan(
        id: int,
        data: schemas.PlanEstudioCreate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    exists = db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == id).first()
    if not exists:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Programa no encontrado")

    exists = db.query(models.Asignatura).filter(models.Asignatura.id_asignatura == data.id_asignatura).first()
    if not exists:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Asignastura no encontrado")

    plan = models.PlanEstudio(id_programa=id, **data.model_dump())
    db.add(plan)
    db.commit()
    db.refresh(plan)
    return plan


@router.delete("{id}/plan/{id_asignatura}", status_code=201)
def remove_asignatura_from_plan(
        id: int,
        id_asignatura: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    entrada = db.execute(
        select(models.PlanEstudio).where(
            models.PlanEstudio.id_programa == id,
            models.PlanEstudio.id_asignatura == id_asignatura
        )
    ).scalars().first()
    if not entrada:
        raise HTTPException(status_code=404, detail="Entrada del plan no encontrada")
    db.delete(entrada)
    db.commit()


