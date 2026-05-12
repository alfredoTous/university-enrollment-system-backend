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
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(codigos_detalle.router)
app.include_router(programas.router)
app.include_router(periodos.router)
app.include_router(estudiantes.router)
app.include_router(reglas_cobro.router)
app.include_router(cobros.router)
app.include_router(volante_pdf.router)
app.include_router(reportes.router)


@app.get("/")
def root():
    return {"mensaje": "API ON"}
