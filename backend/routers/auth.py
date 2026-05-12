import os
from fastapi import APIRouter, Depends, HTTPException, status
from dotenv import load_dotenv
import bcrypt
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from datetime import datetime, timedelta, timezone
from typing import Optional
from sqlalchemy.orm import Session

import secrets
from utils.email import enviar_credenciales

import models
import database
import schemas


load_dotenv()

SECRET_KEY = str(os.getenv("SECRET_KEY"))
ALGORITHM  = os.getenv("ALGORITHM", "HS256")
EXPIRE_MIN = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 60))
ADMIN_SECRET = os.getenv("ADMIN_SECRET")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")
router = APIRouter(prefix="/auth", tags=["auth"])
#------------


# Functions
def hash_password(password):
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def verify_password(plain, hashed):
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=EXPIRE_MIN)

    updated_data = data.copy()
    updated_data.update({"exp": expire})
    encoded_jwt = jwt.encode(updated_data, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)) -> models.Usuario:
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(models.Usuario).filter(models.Usuario.username == username).first()
    if user is None or not user.estado:
        raise credentials_exception

    return user


def require_role(*roles: str):
    def dependency(user: models.Usuario = Depends(get_current_user)):
        if user.rol.nombre_rol not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Rol invalido") # No sufficent permissions
        return user
    return dependency


def build_usuario_out(usuario: models.Usuario):
    return schemas.UsuarioOut(
        id_usuario          = usuario.id_usuario,
        username            = usuario.username,
        estado              = usuario.estado,
        correo_notificacion = usuario.correo_notificacion,
        nombre_rol          = usuario.rol.nombre_rol,
        primer_nombre       = usuario.persona.primer_nombre,
        primer_apellido     = usuario.persona.primer_apellido,
        correo_personal     = usuario.persona.correo_personal,
    )
 

# ------------------

# ENDPOINTS
@router.post("/register", response_model=schemas.UsuarioOut, status_code=201)
def register(
        data: schemas.UsuarioCreate,
        db: Session = Depends(database.get_db),
        token: Optional[str] = Depends(OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False))
):
    
    # Verificar rol ADMINISTRADOR antes de registrar nuevo usuario
    if data.admin_secret and data.admin_secret == ADMIN_SECRET:
        pass
    elif token:
        user = get_current_user(token, db)
        if user.rol.nombre_rol != "ADMINISTRADOR":
            raise HTTPException(status_code=403, detail="Se requiere rol ADMINISTRADOR")
    else:
        raise HTTPException(status_code=401, detail="Se requiere token o clave de administrador")


    # Verificar duplicados
    if db.query(models.Usuario).filter(models.Usuario.username == data.username).first():
        raise HTTPException(status_code=400, detail="El username ya existe")
    if db.query(models.Persona).filter(models.Persona.correo_personal == data.correo_personal).first():
        raise HTTPException(status_code=400, detail="El correo ya está registrado")
    if db.query(models.Persona).filter(models.Persona.numero_documento == data.numero_documento).first():
        raise HTTPException(status_code=400, detail="El número de documento ya existe")
    
    role = db.query(models.Rol).filter(models.Rol.nombre_rol == data.nombre_rol).first()
    if not role:
        raise HTTPException(status_code=400, detail=f"Rol '{data.nombre_rol}' no existe. Crea los roles primero")

    # Crear persona
    persona = models.Persona(
        tipo_documento    = data.tipo_documento,
        numero_documento  = data.numero_documento,
        primer_nombre     = data.primer_nombre,
        segundo_nombre    = data.segundo_nombre,
        primer_apellido   = data.primer_apellido,
        segundo_apellido  = data.segundo_apellido,
        correo_personal   = data.correo_personal,
        telefono_contacto = data.telefono_contacto,
    )
    db.add(persona)
    db.flush()
    # Crear usuario

    usuario = models.Usuario(
        username            = data.username,
        password_hash       = hash_password(data.password),
        correo_notificacion = data.correo_notificacion,
        id_persona          = persona.id_persona,
        id_rol              = role.id_rol,
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    
    # Enviar credenciales por correo
    try:
        enviar_credenciales(
            nombre           = f"{persona.primer_nombre} {persona.primer_apellido}",
            email            = data.correo_notificacion or persona.correo_personal,
            username         = data.username,
            password_temporal= data.password,
        )
    except Exception as e:
        # Si el correo falla no rompemos el registro, solo lo logueamos
        print(f"⚠️ No se pudo enviar el correo: {e}")
    return build_usuario_out(usuario)


@router.post("/login", response_model=schemas.Token)
def login(
        data: OAuth2PasswordRequestForm = Depends(), 
        db: Session = Depends(database.get_db),
):
    user = db.query(models.Usuario).filter(models.Usuario.username == data.username).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    if user.estado != "ACTIVO":
        raise HTTPException(status_code=403, detail="Usuario inactivo o bloqueado")

    user.ultimo_acceso = datetime.utcnow()
    db.commit()
    token = create_access_token(data={"sub": user.username, "rol": user.rol.nombre_rol})
    return schemas.Token(
        access_token = token,
        token_type = "bearer",
        user = build_usuario_out(user)
    )


@router.put("/change-password")
def change_password(
        data: schemas.CambioPassword,
        user: models.Usuario = Depends(get_current_user),
        db: Session = Depends(database.get_db)
):
    if not verify_password(data.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Contraseña actual incorrecta")

    user.password_hash = hash_password(data.new_password)
    db.commit()
    return {"mensaje": "Contraseña actualizada correctamente"}

@router.get("/me", response_model=schemas.UsuarioOut)
def me(user: models.Usuario = Depends(get_current_user)):
    return build_usuario_out(user)
