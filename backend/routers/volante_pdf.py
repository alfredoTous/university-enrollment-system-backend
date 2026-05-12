from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
from sqlalchemy import select
from weasyprint import HTML

import models
import database
from routers.auth import get_current_user

router = APIRouter(prefix="/volante", tags=["volante PDF"])


def generar_html(volante: models.VolanteMatricula) -> str:
    estudiante = volante.estudiante
    programa   = volante.programa
    periodo    = volante.periodo

    detalles_html = ""
    monto_total = 0.0
    for d in volante.detalles:
        subtotal = float(d.cantidad) * float(d.valor_unitario)
        monto_total += subtotal
        detalles_html += f"""
        <tr>
            <td>{d.codigo_detalle.codigo}</td>
            <td>{d.codigo_detalle.descripcion}</td>
            <td>{float(d.cantidad)}</td>
            <td>${float(d.valor_unitario):,.2f}</td>
            <td>${subtotal:,.2f}</td>
        </tr>
        """

    return f"""
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body       {{ font-family: Arial, sans-serif; font-size: 13px; margin: 40px; color: #222; }}
            h1         {{ color: #003366; font-size: 20px; margin-bottom: 4px; }}
            h2         {{ color: #003366; font-size: 15px; margin-top: 0; }}
            .header    {{ display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #003366; padding-bottom: 10px; margin-bottom: 20px; }}
            .seccion   {{ margin-bottom: 20px; }}
            .seccion h3{{ background: #003366; color: white; padding: 5px 10px; margin: 0 0 8px 0; font-size: 13px; }}
            .grid      {{ display: grid; grid-template-columns: 1fr 1fr; gap: 4px 20px; }}
            .campo     {{ margin-bottom: 4px; }}
            .label     {{ font-weight: bold; }}
            table      {{ width: 100%; border-collapse: collapse; }}
            th         {{ background: #003366; color: white; padding: 6px 8px; text-align: left; font-size: 12px; }}
            td         {{ padding: 5px 8px; border-bottom: 1px solid #ddd; }}
            .total     {{ text-align: right; font-size: 16px; font-weight: bold; color: #003366; margin-top: 10px; }}
            .footer    {{ margin-top: 30px; font-size: 11px; color: #666; border-top: 1px solid #ccc; padding-top: 8px; }}
            .badge     {{ display: inline-block; padding: 3px 10px; border-radius: 4px; font-weight: bold; background: #e8f4e8; color: #2a7a2a; }}
        </style>
    </head>
    <body>
        <div class="header">
            <div>
                <h1>Universidad Privada del Caribe</h1>
                <h2>Volante de Matrícula</h2>
            </div>
            <div style="text-align:right">
                <div><b>N°:</b> {volante.numero_volante}</div>
                <div><b>Fecha:</b> {str(volante.fecha_generacion)[:10]}</div>
                <div><span class="badge">{volante.estado}</span></div>
            </div>
        </div>

        <div class="seccion">
            <h3>Información del Estudiante</h3>
            <div class="grid">
                <div class="campo"><span class="label">Nombre:</span> {estudiante.primer_nombre} {estudiante.primer_apellido}</div>
                <div class="campo"><span class="label">Documento:</span> {estudiante.tipo_documento} {estudiante.numero_documento}</div>
                <div class="campo"><span class="label">Correo:</span> {estudiante.correo_electronico}</div>
                <div class="campo"><span class="label">Programa:</span> {programa.nombre_programa}</div>
            </div>
        </div>

        <div class="seccion">
            <h3>Información del Cobro</h3>
            <div class="grid">
                <div class="campo"><span class="label">Periodo:</span> {periodo.codigo_periodo}</div>
                <div class="campo"><span class="label">Semestre a cursar:</span> {volante.semestre_a_cursar}</div>
                <div class="campo"><span class="label">Modalidad:</span> {volante.modalidad_cobro}</div>
                <div class="campo"><span class="label">Tipo generación:</span> {volante.generacion_tipo}</div>
            </div>
        </div>

        <div class="seccion">
            <h3>Detalle de Cobros</h3>
            <table>
                <thead>
                    <tr>
                        <th>Código</th>
                        <th>Descripción</th>
                        <th>Cantidad</th>
                        <th>Valor Unitario</th>
                        <th>Subtotal</th>
                    </tr>
                </thead>
                <tbody>
                    {detalles_html}
                </tbody>
            </table>
            <div class="total">Total a pagar: ${monto_total:,.2f}</div>
        </div>

        <div class="footer">
            Documento generado automáticamente por el Sistema de Gestión de Matrículas.
            Este volante es válido para el periodo académico {periodo.codigo_periodo}.
        </div>
    </body>
    </html>
    """


@router.get("/{id_volante}/pdf")
def descargar_volante_pdf(
    id_volante  : int,
    db          : Session = Depends(database.get_db),
    current_user = Depends(get_current_user)
):
    """
    Genera y descarga el volante de matrícula en PDF.
    GET /volante/{id}/pdf
    Content-Type: application/pdf
    """
    volante = db.execute(
        select(models.VolanteMatricula).where(models.VolanteMatricula.id_volante == id_volante)
    ).scalars().first()
    if not volante:
        raise HTTPException(status_code=404, detail="Volante no encontrado")

    html = generar_html(volante)
    pdf  = HTML(string=html).write_pdf()

    return Response(
        content     = pdf,
        media_type  = "application/pdf",
        headers     = {"Content-Disposition": f"attachment; filename=volante_{volante.numero_volante}.pdf"}
    )
