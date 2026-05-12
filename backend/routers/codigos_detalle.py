from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, query
from sqlalchemy import select
from sqlalchemy.sql.functions import mode


import database
import schemas
import models
from routers import auth


router = APIRouter(prefix="/codigos-detalle", tags=["codigos-detalle"])

@router.get("/", response_model=list[schemas.CodigoDetalleOut])
def get_codigos(db: Session = Depends(database.get_db)):
    return db.query(models.CodigoDetalle).all()


@router.get("/{id}", response_model=schemas.CodigoDetalleOut)
def get_codigo(id: int, db: Session = Depends(database.get_db)):
    codigo = db.query(models.CodigoDetalle).filter(models.CodigoDetalle.id_codigo_detalle == id).first()
    if not codigo:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Codigo no encontrado")
    return codigo


@router.post("/", response_model=schemas.CodigoDetalleOut, status_code=201)
def create_codigo(
        data: schemas.CodigoDetalleCreate,
        db: Session = Depends(database.get_db),
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR"))
):
    if db.query(models.CodigoDetalle).filter(models.CodigoDetalle.codigo == data.codigo).first():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El codigo ya existe")
    
    if data.grupo not in ("COBRO", "PAGO"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El grupo debe ser COBRO o PAGO")

    codigo_detalle = models.CodigoDetalle(codigo=data.codigo, descripcion=data.descripcion, grupo=data.grupo)

    db.add(codigo_detalle)
    db.commit()
    db.refresh(codigo_detalle)
    return codigo_detalle


@router.put("/{id}")
def update_codigo(
    id: int,
    data: schemas.CodigoDetalleUpdate,
    current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR", "SUPERVISOR")),
    db: Session = Depends(database.get_db)
):
    codigo_detalle = db.query(models.CodigoDetalle).filter(models.CodigoDetalle.id_codigo_detalle == id).first()
    if not codigo_detalle:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Codigo no encontrado")
    if data.grupo and data.grupo not in ("COBRO", "PAGO"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El grupo debe ser COBRO o PAGO")

    if data.descripcion:
        codigo_detalle.descripcion = data.descripcion
    if data.grupo:
        codigo_detalle.grupo = data.grupo
    if data.estado:
        codigo_detalle.estado = data.estado
    
    db.commit()
    db.refresh(codigo_detalle)
    return codigo_detalle


@router.delete("/{id}", status_code=204)
def delete(
    id: int,
    current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
    db: Session = Depends(database.get_db)
):
    codigo_detalle = db.query(models.CodigoDetalle).filter(models.CodigoDetalle.id_codigo_detalle == id).first()

    if not codigo_detalle:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Codigo no encontrado")

    db.delete(codigo_detalle)
    db.commit()






