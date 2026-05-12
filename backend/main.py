from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


from routers import auth, users, codigos_detalle, programas, periodos, estudiantes, reglas_cobro, cobros, volante_pdf, reportes
import database


database.Base.metadata.create_all(bind=database.engine) # Create tables if don't exist

app  = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"], # Front end
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# Routers
app.include_router(auth.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(codigos_detalle.router, prefix="/api")
app.include_router(programas.router, prefix="/api")
app.include_router(periodos.router, prefix="/api")
app.include_router(estudiantes.router, prefix="/api")
app.include_router(reglas_cobro.router, prefix="/api")
app.include_router(cobros.router, prefix="/api")
app.include_router(volante_pdf.router, prefix="/api")
app.include_router(reportes.router, prefix="/api")


@app.get("/")
def root():
    return {"mensaje": "/api ON"}
