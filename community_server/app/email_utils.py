import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional
import os
from dotenv import load_dotenv

load_dotenv()
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USERNAME = os.getenv("EMAIL_HOST_USER")
SMTP_PASSWORD = os.getenv("EMAIL_HOST_PASSWORD")
FROM_EMAIL = os.getenv("EMAIL_HOST_USER")
BASE_URL = os.getenv("BASE_URL")

def send_verification_email(email: str, token: str, username: str):
    
    verification_link = f"{BASE_URL}/verify-email?token={token}"
    
    subject = "Conferma la tua registrazione"
    
    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
            <h2>Ciao {username}!</h2>
            <p>Grazie per esserti registrato. Per completare la registrazione, clicca sul link qui sotto:</p>
            <p style="margin: 30px 0;">
                <a href="{verification_link}" 
                   style="background-color: #4CAF50; color: white; padding: 14px 20px; 
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                    Conferma Email
                </a>
            </p>
            <p>Oppure copia e incolla questo link nel tuo browser:</p>
            <p style="color: #666; font-size: 14px;">{verification_link}</p>
            <p style="color: #999; font-size: 12px; margin-top: 40px;">
                Questo link scadrà tra 24 ore.<br>
                Se non hai richiesto questa registrazione, ignora questa email.
            </p>
        </body>
    </html>
    """
    
    text_content = f"""
    Ciao {username}!
    
    Grazie per esserti registrato. Per completare la registrazione, clicca sul link qui sotto:
    
    {verification_link}
    
    Questo link scadrà tra 24 ore.
    Se non hai richiesto questa registrazione, ignora questa email.
    """
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = FROM_EMAIL
    msg["To"] = email
    
    part1 = MIMEText(text_content, "plain")
    part2 = MIMEText(html_content, "html")
    
    msg.attach(part1)
    msg.attach(part2)
    
    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USERNAME, SMTP_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Errore invio email: {e}")
        return False