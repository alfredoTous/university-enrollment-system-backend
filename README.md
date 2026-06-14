# Backend Deployment

Backend REST completo en Python con integración a PostgreSQL, desarrollado a partir de un esquema DML universitario. Expone ~18 endpoints gestionando matrículas, cursos y usuarios, con autenticación JWT para múltiples roles, generación de PDFs con WeasyPrint y envío de correos transaccionales con Resend. Implementado siguiendo principios de codificación segura, validación de entradas y consultas parametrizadas

---

### 1. Clone repo branch and move into project

```bash
git clone https://github.com/alfredoTous/university-enrollment-system-backend
cd university-enrollment-system-backend
```

---

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

---

### 3. PostgreSQL setup

Make sure PostgreSQL is running and create the database:

```bash
sudo -u postgres psql
```

```sql
CREATE DATABASE matriculas_db;
\q
```

---

### 4. Initialize database schema (required)

Execute DDL script to create tables and base structure:

```bash
sudo -u postgres psql -d matriculas_db -f d.sql
```

Then insert required roles or execute DML script:

```sql
INSERT INTO rol (nombre_rol, descripcion, es_especial) VALUES
('ADMINISTRADOR', 'Acceso total al sistema', TRUE),
('SUPERVISOR', 'Gestión académica y estudiantes', FALSE),
('ASISTENTE', 'Gestión de cobros y pagos', FALSE);
```

---

### 5. Environment variables

Create a `.env` file in the project root:

```env
DATABASE_URL=postgresql://postgres:tu_contraseña@localhost:5432/matriculas_db
SECRET_KEY=una_clave_secreta_larga_y_segura
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

---

### 6. Run server

```bash
uvicorn main:app --reload
```

---

## 🧠 Notas del proyecto

Este backend forma parte del sistema completo **https://github.com/Santrosherun/university-enrollment-system**, que incluye frontend y suite de pruebas. El desarrollo del backend se enfocó en la construcción de una API REST robusta, con énfasis en seguridad, separación de responsabilidades y diseño orientado a un sistema académico real.

---

## 🚀 Stack principal

- Python (FastAPI)
- PostgreSQL
- JWT Authentication
- WeasyPrint (PDF generation)
- Resend (email service)
