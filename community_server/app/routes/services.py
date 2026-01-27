import os
from fastapi import APIRouter, Depends, HTTPException, Form, Request
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
import httpx

import app.model.models as models
from app.model.database import SessionLocal

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
    """List all services"""
    return db.query(models.Services).all()

@router.get("/get_services/")
async def get_services(db: Session = Depends(get_db)):
    """Get all active services with health check"""
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
    """Get service domain by ID"""
    return db.query(models.Services).filter(models.Services.id == service_id).first().domain

@router.get("/register_service")
def register_service(request: Request):
    """Display service registration form"""
    return templates.TemplateResponse(
        "register_service.html",
        {"request": request}
    )

@router.post("/add_service/")
def add_service(
    request: Request,
    name: str = Form(...),
    domain: str = Form(...),
    active: bool = Form(...),
    db: Session = Depends(get_db)
):
    """Add new service"""
    new_service = models.Services(name=name, domain=domain, active=active)
    db.add(new_service)
    db.commit()
    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services,}
    )

@router.post("/delete_service/{service_id}")
def delete_service(service_id: int, request: Request, db: Session = Depends(get_db)):
    """Delete a service by ID"""
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
def status_service(service_id: int, request: Request, db: Session = Depends(get_db)):
    """Toggle service active status"""
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