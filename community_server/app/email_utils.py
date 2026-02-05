# email_service.py
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
    
    subject = "Confirm your registration"
    
    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
            <h2>Hello {username}!</h2>
            <p>Thank you for registering. To complete your registration, click the link below:</p>
            <p style="margin: 30px 0;">
                <a href="{verification_link}" 
                   style="background-color: #4CAF50; color: white; padding: 14px 20px; 
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                    Confirm Email
                </a>
            </p>
            <p>Or copy and paste this link into your browser:</p>
            <p style="color: #666; font-size: 14px;">{verification_link}</p>
            <p style="color: #999; font-size: 12px; margin-top: 40px;">
                This link will expire in 24 hours.<br>
                If you did not request this registration, ignore this email.
            </p>
        </body>
    </html>
    """
    
    text_content = f"""
    Hello {username}!
    
    Thank you for registering. To complete your registration, click the link below:
    
    {verification_link}
    
    This link will expire in 24 hours.
    If you did not request this registration, ignore this email.
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
        print(f"Email sending error: {e}")
        return False

def send_forgot_password(email: str, token: str, username: str):
    reset_link = f"{BASE_URL}/reset-password/?token={token}"

    subject = "Reset your password"

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
            <h2>Hello {username}!</h2>
            <p>We received a request to reset your password.</p>

            <p style="margin: 30px 0;">
                <a href="{reset_link}"
                   style="background-color: #e53935; color: white; padding: 14px 20px;
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                    Reset Password
                </a>
            </p>

            <p>Or copy this link:</p>
            <p style="color: #666; font-size: 14px;">{reset_link}</p>

            <p style="color: #999; font-size: 12px; margin-top: 40px;">
                This link expires in 24 hours.<br>
                If you did not request a password reset, ignore this email.
            </p>
        </body>
    </html>
    """

    text_content = f"""
    Hello {username},

    To reset your password visit the following link:
    {reset_link}

    This link expires in 24 hours.
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = FROM_EMAIL
    msg["To"] = email

    msg.attach(MIMEText(text_content, "plain"))
    msg.attach(MIMEText(html_content, "html"))

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        return True
    except Exception as e:
        print(f"Email sending error: {e}")
        return False

def send_credentials_retrieval_email(
    to_email: str, 
    service_name: str, 
    token: str,
    expires_in_hours: int = 24
):
    retrieval_url = f"{BASE_URL}/retrieve-credentials?token={token}"
    
    subject = f"API Credentials Ready - {service_name}"
    
    html_body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background: #007bff; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }}
            .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 5px 5px; }}
            .button {{ 
                display: inline-block; 
                padding: 12px 30px; 
                background: #28a745; 
                color: white; 
                text-decoration: none; 
                border-radius: 5px;
                margin: 20px 0;
            }}
            .warning {{ 
                background: #fff3cd; 
                border-left: 4px solid #ffc107; 
                padding: 15px; 
                margin: 20px 0;
            }}
            .danger {{ 
                background: #f8d7da; 
                border-left: 4px solid #dc3545; 
                padding: 15px; 
                margin: 20px 0;
            }}
            .code {{ 
                background: #e9ecef; 
                padding: 10px; 
                border-radius: 3px; 
                font-family: monospace;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🔐 Service Registration Completed</h1>
            </div>
            <div class="content">
                <p>Hello,</p>
                
                <p>Your service <strong>{service_name}</strong> has been successfully registered in our Identity Provider.</p>
                
                <p>Click the button below to retrieve your API credentials:</p>
                
                <div style="text-align: center;">
                    <a href="{retrieval_url}" class="button">Retrieve API Credentials</a>
                </div>
                
                <div class="danger">
                    <strong>⚠️ IMPORTANT:</strong>
                    <ul>
                        <li>This link will <strong>expire in {expires_in_hours} hours</strong></li>
                        <li>The credentials will be shown <strong>only once</strong></li>
                        <li>After viewing, the link will become invalid</li>
                        <li>Save the credentials securely immediately</li>
                    </ul>
                </div>
                
                <div class="warning">
                    <strong>📋 What to do after retrieving credentials:</strong>
                    <ol>
                        <li>Copy the API Key and API Secret</li>
                        <li>Add them to your Django <code>.env</code> file</li>
                        <li>Never commit credentials to version control</li>
                        <li>Store them in a secure password manager</li>
                    </ol>
                </div>
                
                <p>If you didn't request this registration, please contact the administrator immediately.</p>
                
                <hr>
                <p style="color: #6c757d; font-size: 12px;">
                    If the button doesn't work, copy and paste this URL into your browser:<br>
                    <span class="code">{retrieval_url}</span>
                </p>
            </div>
        </div>
    </body>
    </html>
    """
    
    text_body = f"""
Service Registration Completed

Hello,

Your service "{service_name}" has been successfully registered in our Identity Provider.

Retrieve your API credentials here:
{retrieval_url}

⚠️ IMPORTANT:
- This link will expire in {expires_in_hours} hours
- The credentials will be shown only once
- After viewing, the link will become invalid
- Save the credentials securely immediately

What to do after retrieving credentials:
1. Copy the API Key and API Secret
2. Add them to your Django .env file
3. Never commit credentials to version control
4. Store them in a secure password manager

If you didn't request this registration, please contact the administrator immediately.
    """
    
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = FROM_EMAIL
    msg['To'] = to_email
    
    msg.attach(MIMEText(text_body, 'plain'))
    msg.attach(MIMEText(html_body, 'html'))
    
    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False