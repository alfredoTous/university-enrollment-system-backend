from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.sql.functions import user

import database
import models
from routers import auth
import schemas

router = APIRouter(prefix="/users", tags=["users"])

# FUNCTIONS ---------------------
def get_user_by_id(user_id: int, db: Session):
    user = db.query(models.Usuario).filter(models.Usuario.id_usuario == user_id).first()
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")
    return user
# -------------------------------


# ENDPOINTS
@router.get("/", response_model=list[schemas.UsuarioOut])
def get_users(
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")), 
        db: Session = Depends(database.get_db)
):
    users = db.query(models.Usuario).all()
    response = []
    for i in users:
        response.append(auth.build_usuario_out(i))
    return response


@router.get("/{user_id}", response_model=schemas.UsuarioOut)
def get_user(
        user_id: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    user = get_user_by_id(user_id, db)
    return auth.build_usuario_out(user)


@router.put("/{user_id}", response_model=schemas.UsuarioOut)
def update_user(
        user_id: int,
        data: schemas.UserUpdate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    user = get_user_by_id(user_id, db)
    
    if data.primer_nombre: 
        user.persona.primer_nombre = data.primer_nombre

    if data.primer_apellido:
        user.persona.primer_apellido = data.primer_apellido

    if data.username:
        exists = db.query(models.Usuario).filter(models.Usuario.username == data.username, models.Usuario.id_usuario != user.id_usuario).first()
        if exists:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "El username ya existe")
        user.username = data.username

    if data.correo_personal:
        exists = db.query(models.Persona).filter(models.Persona.correo_personal == data.correo_personal, models.Persona.id_persona != user.id_persona).first()
        if exists:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "El correo ya existe")
        user.persona.correo_personal = data.correo_personal

    if data.correo_notificacion:
        exists = db.query(models.Usuario).filter(models.Usuario.correo_notificacion == data.correo_notificacion, models.Usuario.id_usuario != user.id_usuario)
        if exists:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "EL correo correo de notificacion ya existe")
        user.correo_notificacion = data.correo_notificacion

    if data.telefono_contacto:
        user.persona.telefono_contacto = data.telefono_contacto

    if data.nombre_rol:
        role = db.query(models.Rol).filter(models.Rol.nombre_rol == data.nombre_rol).first()
        if not role:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Rol '{data.nombre_rol}' no existe")
        user.id_rol = role.id_rol

    db.commit()
    db.refresh(user)
    return auth.build_usuario_out(user)


@router.put("/{user_id}/password")
def change_password(
        user_id: int,
        data: schemas.PasswordUpdate,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    user = get_user_by_id(user_id, db)
    user.password_hash = auth.hash_password(data.new_password)
    db.commit()
    db.refresh(user)
    return {"msg": "password changed successfully"}


@router.get("/{user_id}/deactivate")
def deactivate_user(
        user_id: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    user = get_user_by_id(user_id, db)
    
    if user.id_usuario == current_user.id_usuario:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No puedes desactivarte a ti mismo")
    
    user.estado = "INACTIVO"
    db.commit()
    db.refresh(user)
    return {"msg": "successfull"}


@router.get("/{user_id}/activate")
def activate_user(
        user_id: int,
        current_user: models.Usuario = Depends(auth.require_role("ADMINISTRADOR")),
        db: Session = Depends(database.get_db)
):
    user = get_user_by_id(user_id, db)
    
    if user.id_usuario == current_user.id_usuario:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No puedes activarte a ti mismo")
    
    user.estado = "ACTIVO"
    db.commit()
    db.refresh(user)
    return {"msg": "successfull"}

