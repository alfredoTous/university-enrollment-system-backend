from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session


import schemas
import database
import models
from routers import auth


router = APIRouter(prefix="/estudiantes", tags=["estudiantes"])

@router.get("/", response_model=list[schemas.EstudianteOut])
def get_estudiantes(
    db: Session = Depends(database.get_db)
):
    return db.query(models.Estudiante).all()


@router.get("/{id}", response_model=schemas.EstudianteOut)
def get_estudiante(
        id: int,
        db: Session = Depends(database.get_db)
):
    estudiante = db.query(models.Estudiante).filter(models.Estudiante.id_estudiante == id).first()
    if not estudiante:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Estudiante no encontrado")
    return estudiante


@router.post("/", response_model=schemas.EstudianteOut, status_code=201)
def create_estudiante(
        data: schemas.EstudianteCreate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    exists = db.query(models.Estudiante).filter(models.Estudiante.numero_documento == data.numero_documento).first()
    if exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Ya existe un estudiante con ese documento")
    
    exists = db.query(models.Estudiante).filter(models.Estudiante.correo_electronico ==  data.correo_electronico).first()
    if exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El correo ya esta en uso")

    exists = db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == data.id_programa)
    if not exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El id del programa no existe")
    
    estudiante = models.Estudiante(**data.model_dump())
    db.add(estudiante)
    db.commit()
    db.refresh(estudiante)
    return estudiante


@router.put("/{id}", response_model=schemas.EstudianteOut)
def update_estudiante(
        id: int,
        data: schemas.EstudianteUpdate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    estudiante = db.query(models.Estudiante).filter(models.Estudiante.id_estudiante == id).first()

    if not estudiante:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Estudiante no encontrado")

    for key, value in data.model_dump(exclude_none=True).items():
        setattr(estudiante, key, value)

    db.commit()
    db.refresh(estudiante)
    return estudiante


@router.delete("/{id}", status_code=204)
def delete_estudiante(
        id: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    estudiante = db.query(models.Estudiante).filter(models.Estudiante.id_estudiante == id).first()
    if not estudiante:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "El estudiante no existe")

    db.delete(estudiante)
    db.commit()


