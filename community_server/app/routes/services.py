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
    """
    List all services.

    Returns all services stored in the database,
    regardless of their active status.

    Responses:
        200:
            Description: Successful response.
            Content: List of service objects.
    """
    return db.query(models.Services).all()

@router.get("/get_services/")
async def get_services(db: Session = Depends(get_db)):
    """
    Get active services with health check validation.

    Retrieves all services marked as active and performs
    an HTTPS health check against each service endpoint.

    The health check is executed at:
        https://xrtourguide/communityserver/health_check/

    Only services responding with HTTP 200 are returned.

    Responses:
        200:
            Description: List of active and healthy services.
            Content: List of service objects.
    """
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
    """
    Get service domain by service ID.

    Retrieves the domain associated with a specific service.

    Path Parameters:
        service_id (int): Unique identifier of the service.

    Responses:
        200:
            Description: Service domain.
            Content: String containing the domain.
    """
    return db.query(models.Services).filter(models.Services.id == service_id).first().domain

@router.get("/register_service")
def register_service(request: Request):
    """
    Display service registration form.

    Renders an HTML page containing a form
    for creating a new service entry.

    Responses:
        200:
            Description: HTML registration form.
            Content: HTML page.
    """
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
    """
    Add a new service.

    Creates a new service record using form data
    and persists it into the database.

    Form Parameters:
        name (str): Name of the service.
        domain (str): Domain of the service.
        active (bool): Initial active status.

    Responses:
        200:
            Description: Service successfully created.
            Content: HTML page with updated services list.
    """
    new_service = models.Services(name=name, domain=domain, active=active)
    db.add(new_service)
    db.commit()
    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services}
    )

@router.post("/delete_service/{service_id}")
def delete_service(service_id: int, request: Request, db: Session = Depends(get_db)):
    """
    Delete a service by ID.

    Removes a service from the database
    using its unique identifier.

    Path Parameters:
        service_id (int): Unique identifier of the service.

    Errors:
        404: Service not found.

    Responses:
        200:
            Description: Service successfully deleted.
            Content: HTML page with confirmation message.
    """
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
    """
    Toggle service active status.

    Switches the active state of a service.
    If the service is active, it becomes inactive,
    and vice versa.

    Path Parameters:
        service_id (int): Unique identifier of the service.

    Errors:
        404: Service not found.

    Responses:
        200:
            Description: Service status updated.
            Content: HTML page with status message.
    """
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
