import os
import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Form, Request
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session
import httpx
from app.auth import get_current_user_from_session
import app.model.models as models
from app.model.database import SessionLocal
from app.email_utils import send_credentials_retrieval_email

router = APIRouter()

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")
templates = Jinja2Templates(directory=TEMPLATES_DIR)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/list_services/")
async def list_services(db: Session = Depends(get_db)):
    return db.query(models.Services).all()

@router.get("/get_services/")
async def get_services(db: Session = Depends(get_db)):
    services = db.query(models.Services).filter(models.Services.active == True).all()

    async with httpx.AsyncClient() as client:
        results = []
        for s in services:
            try:
                r = await client.get(f"https://{s.domain}/health_check/")
                if r.status_code == 200:
                    results.append(s)
            except Exception:
                pass

    return results

@router.get("/get_service/{service_id}")
async def get_service(service_id: int, db: Session = Depends(get_db)):
    return db.query(models.Services).filter(models.Services.id == service_id).first().domain

@router.get("/register_service")
def register_service(
    request: Request,
    db: Session = Depends(get_db)
):
    try:
        current_user = get_current_user_from_session(request, db)
        if current_user.role != models.UserRole.ADMIN:
            return RedirectResponse(url="/", status_code=303)
    except HTTPException as e:
        print(f"Exception: {e}", flush=True)
        return RedirectResponse(url="/login", status_code=303)
    
    return templates.TemplateResponse(
        "register_service.html",
        {"request": request}
    )

@router.post("/add_service/")
def add_service(
    request: Request,
    name: str = Form(...),
    domain: str = Form(...),
    requester_email: str = Form(...),
    active: bool = Form(...),
    db: Session = Depends(get_db)
):
    try:
        current_user = get_current_user_from_session(request, db)
        if current_user.role != models.UserRole.ADMIN:
            raise HTTPException(status_code=403, detail="Admin access required")
    except HTTPException:
        return RedirectResponse(url="/login", status_code=303)
    
    existing = db.query(models.Services).filter(models.Services.domain == domain).first()
    if existing:
        services = db.query(models.Services).all()
        return templates.TemplateResponse(
            "home.html",
            {
                "request": request,
                "services": services,
                "error": f"Domain {domain} is already registered"
            }
        )
    
    new_service = models.Services(
        name=name,
        domain=domain,
        requester_email=requester_email,
        active=active
    )
    
    db.add(new_service)
    db.commit()
    db.refresh(new_service)
    
    api_key, api_secret = new_service.generate_credentials()
    
    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=24)
    
    credentials_token = models.ServiceCredentialsToken(
        token=token,
        service_id=new_service.id,
        expires_at=expires_at,
        api_secret_plain=api_secret
    )
    
    db.add(credentials_token)
    db.commit()
    
    email_sent = send_credentials_retrieval_email(
        to_email=requester_email,
        service_name=name,
        token=token,
        expires_in_hours=24
    )
    
    services = db.query(models.Services).all()
    
    if not email_sent:
        return templates.TemplateResponse(
            "home.html",
            {
                "request": request,
                "services": services,
                "error": "Service registered but failed to send email. Contact administrator."
            }
        )
    
    return templates.TemplateResponse(
        "home.html",
        {
            "request": request,
            "services": services,
            "message": f"Service registered successfully. Credentials sent to {requester_email}"
        }
    )

@router.post("/delete_service/{service_id}")
def delete_service(
    service_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    try:
        current_user = get_current_user_from_session(request, db)
        if current_user.role != models.UserRole.ADMIN:
            raise HTTPException(status_code=403, detail="Admin access required")
    except HTTPException:
        return RedirectResponse(url="/login", status_code=303)
    
    service = db.query(models.Services).filter(models.Services.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")
    
    db.delete(service)
    db.commit()

    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services, "message": "Service deleted successfully"}
    )

@router.post("/status_service/{service_id}")
def status_service(
    service_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    try:
        current_user = get_current_user_from_session(request, db)
        if current_user.role != models.UserRole.ADMIN:
            raise HTTPException(status_code=403, detail="Admin access required")
    except HTTPException:
        return RedirectResponse(url="/login", status_code=303)
    
    service = db.query(models.Services).filter(models.Services.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")
    
    service.active = not service.active
    db.commit()

    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services, "message": "Service status updated"}
    )

@router.post("/regenerate_credentials/{service_id}")
async def regenerate_credentials(
    service_id: int,
    request: Request,
    db: Session = Depends(get_db)
):
    try:
        current_user = get_current_user_from_session(request, db)
        if current_user.role != models.UserRole.ADMIN:
            raise HTTPException(status_code=403, detail="Admin access required")
    except HTTPException:
        return RedirectResponse(url="/login", status_code=303)
    
    service = db.query(models.Services).filter(models.Services.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")
    
    db.query(models.ServiceCredentialsToken).filter(
        models.ServiceCredentialsToken.service_id == service_id,
        models.ServiceCredentialsToken.used == False
    ).update({"used": True})
    
    api_key, api_secret = service.generate_credentials()
    service.credentials_retrieved = False
    
    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=24)
    
    credentials_token = models.ServiceCredentialsToken(
        token=token,
        service_id=service.id,
        expires_at=expires_at,
        api_secret_plain=api_secret
    )
    
    db.add(credentials_token)
    db.commit()
    
    email_sent = send_credentials_retrieval_email(
        to_email=service.requester_email,
        service_name=service.name,
        token=token,
        expires_in_hours=24
    )
    
    if not email_sent:
        raise HTTPException(
            status_code=500,
            detail="Credentials regenerated but failed to send email"
        )
    
    return {
        "message": "Credentials regenerated and email sent",
        "email_sent_to": service.requester_email
    }

@router.get("/retrieve-credentials", response_class=HTMLResponse)
async def retrieve_credentials_page(
    request: Request,
    token: str,
    db: Session = Depends(get_db)
):
    credentials_token = db.query(models.ServiceCredentialsToken).filter(
        models.ServiceCredentialsToken.token == token
    ).first()
    
    if not credentials_token:
        return templates.TemplateResponse(
            "credentials_error.html",
            {
                "request": request,
                "error_type": "invalid",
                "message": "Invalid or non-existent token"
            }
        )
    
    if credentials_token.used:
        return templates.TemplateResponse(
            "credentials_error.html",
            {
                "request": request,
                "error_type": "used",
                "message": "This token has already been used. Credentials can only be retrieved once."
            }
        )
    
    if datetime.utcnow() > credentials_token.expires_at:
        return templates.TemplateResponse(
            "credentials_error.html",
            {
                "request": request,
                "error_type": "expired",
                "message": "This token has expired. Please contact the administrator to regenerate credentials."
            }
        )
    
    service = db.query(models.Services).filter(
        models.Services.id == credentials_token.service_id
    ).first()
    
    if not service or not service.api_key:
        return templates.TemplateResponse(
            "credentials_error.html",
            {
                "request": request,
                "error_type": "error",
                "message": "Service not found or credentials not generated"
            }
        )
    
    api_secret = credentials_token.api_secret_plain
    
    credentials_token.used = True
    credentials_token.api_secret_plain = None
    service.credentials_retrieved = True
    db.commit()
    
    return templates.TemplateResponse(
        "credentials_success.html",
        {
            "request": request,
            "service_name": service.name,
            "domain": service.domain,
            "api_key": service.api_key,
            "api_secret": api_secret
        }
    )