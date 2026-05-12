from fastapi import APIRouter, Depends, HTTPException, status

from sqlalchemy.orm import Session
from sqlalchemy.sql.functions import mode


import schemas
import database
import models
from routers import auth

router = APIRouter(prefix="/periodos", tags=["periodos"])


@router.get("/", response_model=list[schemas.PeriodoOut])
def get_periodos(
        db: Session = Depends(database.get_db)
):
    return db.query(models.PeriodoAcademico).all()


@router.get("/{id}", response_model=schemas.PeriodoOut)
def get_periodo(
        id: int,
        db: Session = Depends(database.get_db)
):
    periodo = db.query(models.PeriodoAcademico).filter(models.PeriodoAcademico.id_periodo == id).first()
    if not periodo:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Periodo no encontrado")
    return periodo


@router.post("/", response_model=schemas.PeriodoOut, status_code=201)
def create_periodo(
        data: schemas.PeriodoCreate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    exists = db.query(models.PeriodoAcademico).filter(models.PeriodoAcademico.codigo_periodo == data.codigo_periodo).first()
    if exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El codigo de periodo ya existe")
    
    periodo = models.PeriodoAcademico(**data.model_dump())
    db.add(periodo)
    db.commit()
    db.refresh(periodo)
    return periodo


@router.put("/{id}", response_model=schemas.PeriodoOut)
def update_periodo(
        id: int,
        data: schemas.PeriodoUpdate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    periodo = db.query(models.PeriodoAcademico).filter(models.PeriodoAcademico.id_periodo == id).first()
    if not periodo:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Periodo no encontrado")

    for key, value in data.model_dump(exclude_none=True).items():
        setattr(periodo, key, value)

    db.commit()
    db.refresh(periodo)
    return periodo


@router.delete("/{id}", status_code=204)
def delete_periodo(
        id: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    periodo = db.query(models.PeriodoAcademico).filter(models.PeriodoAcademico.id_periodo == id).first()
    if not periodo:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Periodo no encontrado")

    db.delete(periodo)
    db.commit()



