import resend
import os
from dotenv import load_dotenv

load_dotenv()

resend.api_key = os.getenv("RESEND_API_KEY")
EMAIL_FROM     = os.getenv("EMAIL_FROM", "onboarding@resend.dev")


def enviar_credenciales(nombre: str, email: str, username: str, password_temporal: str):
    """Envía las credenciales de acceso al usuario recién creado."""
    resend.Emails.send({
        "from"   : EMAIL_FROM,
        "to"     : [email],
        "subject": "Bienvenido al Sistema de Matrículas — Tus credenciales de acceso",
        "html"   : f"""
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: auto;">
            <h2 style="color: #003366;">Bienvenido, {nombre}</h2>
            <p>Tu cuenta ha sido creada en el Sistema de Gestión de Matrículas.</p>
            <p>Tus credenciales de acceso son:</p>
            <table style="border-collapse: collapse; width: 100%;">
                <tr>
                    <td style="padding: 8px; font-weight: bold;">Usuario:</td>
                    <td style="padding: 8px;">{username}</td>
                </tr>
                <tr style="background: #f5f5f5;">
                    <td style="padding: 8px; font-weight: bold;">Contraseña temporal:</td>
                    <td style="padding: 8px;">{password_temporal}</td>
                </tr>
            </table>
            <p style="color: #cc0000; margin-top: 16px;">
                Por seguridad, cambia tu contraseña después de iniciar sesión.
            </p>
            <p style="color: #666; font-size: 12px;">
                Este correo fue generado automáticamente. No respondas a este mensaje.
            </p>
        </div>
        """
    })
