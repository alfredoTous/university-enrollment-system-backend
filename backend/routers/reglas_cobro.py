from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import schemas
import database
import models
from routers import auth


router = APIRouter(prefix="/reglas-cobro", tags=["reglas-cobro"])


@router.get("/", response_model=list[schemas.ReglaCobroOut])
def get_reglas(
        db: Session = Depends(database.get_db)
):
    return db.query(models.ReglaCobro).all()


@router.get("/{modalidad}/{id_periodo}/{id_programa}", response_model=schemas.ReglaCobroOut)
def get_regla(
        modalidad: str,
        id_periodo: int,
        id_programa: int,
        db: Session = Depends(database.get_db)
):
    regla = db.query(models.ReglaCobro).filter(
        models.ReglaCobro.modalidad_cobro == modalidad, 
        models.ReglaCobro.id_periodo      == id_periodo,
        models.ReglaCobro.id_programa     == id_programa
        )

    if not regla:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Regla no encontrada")
    return regla



@router.post("/", response_model=schemas.ReglaCobroOut, status_code=201)
def create_regla(
        data: schemas.ReglaCobro,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    if data.modalidad_cobro not in ("GLOBAL", "POR_CREDITOS"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Modalidad debe ser GLOBAL o POR_CREDITOS")

    if data.modalidad_cobro == "GLOBAL" and data.valor_global is None:
        raise HTTPException(status_code=400, detail="GLOBAL requiere valor_global")
    if data.modalidad_cobro == "POR_CREDITOS" and data.valor_credito is None:
        raise HTTPException(status_code=400, detail="POR_CREDITOS requiere valor_credito")

    exists = db.query(models.ReglaCobro).filter(
        models.ReglaCobro.modalidad_cobro == data.modalidad_cobro,
        models.ReglaCobro.id_periodo == data.id_periodo,
        models.ReglaCobro.id_programa == data.id_programa
    )

    if exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Ya existe una regla para esac ombinacion")

    
    if not db.query(models.PeriodoAcademico).filter(models.PeriodoAcademico.id_periodo == data.id_periodo).first():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Periodo no encontrado")

    if not db.query(models.ProgramaAcademico).filter(models.ProgramaAcademico.id_programa == data.id_programa).first():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Programa no encontrado")


    regla = models.ReglaCobro(**data.model_dump())
    db.add(regla)
    db.commit()
    db.refresh(regla)
    return regla


@router.put("/{modalidad}/{id_periodo}/{id_programa}", response_model=schemas.ReglaCobroOut)
def update_regla(
        modalidad: str,
        id_periodo: int,
        id_programa: int,
        data: schemas.ReglaCobroUpdate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
        db: Session = Depends(database.get_db)
):
    regla = db.query(models.ReglaCobro).filter(
        models.ReglaCobro.modalidad_cobro == modalidad,
        models.ReglaCobro.id_periodo == id_periodo,
        models.ReglaCobro.id_programa == id_programa
    ).first()

    if not regla:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Regla no encontrada")

    for key, value in data.model_dump(exclude_none=True).items():
        setattr(regla, key, value)

    db.commit()
    db.refresh(regla)
    return regla



@router.delete("/{modalidad}/{id_periodo}/{id_programa}")
def delete_regla(
        modalidad: str,
        id_periodo: int,
        id_programa: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    regla = db.query(models.ReglaCobro).filter(
        models.ReglaCobro.modalidad_cobro == modalidad,
        models.ReglaCobro.id_periodo == id_periodo,
        models.ReglaCobro.id_programa == id_programa
    ).first()
    if not regla:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Regla no encontrada")

    db.delete(regla)
    db.commit()


