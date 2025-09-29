import sys, os
from fastapi import Request
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, Form
from sqlalchemy.orm import Session
import model.models as models
from model.database import SessionLocal, engine
import dotenv
from pydantic import BaseModel
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from fastapi.requests import Request as FastAPIRequest
from fastapi.responses import RedirectResponse


dotenv.load_dotenv()

models.Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    db = SessionLocal()
    try:
        default_name = os.getenv("DEFAULT_USER_NAME")
        default_email = os.getenv("DEFAULT_USER_EMAIL")
        default_password = os.getenv("DEFAULT_USER_PASSWORD")

        if default_name and default_email and default_password:
            existing_user = db.query(models.User).filter(models.User.email == default_email).first()
            if not existing_user:
                new_user = models.User(
                    name=default_name,
                    email=default_email,
                )
                new_user.set_password(default_password)
                db.add(new_user)
                print("Utente di default aggiunto")
            else:
                print("Utente di default già presente")
        else:
            print("Variabili di default utente non settate")

        existing_service = db.query(models.Services).filter(models.Services.domain == "default").first()
        if not existing_service:
            new_service = models.Services(
                name="default",
                domain="default",
                active=True
            )
            db.add(new_service)
            print("Servizio di default aggiunto")
        else:
            print("Servizio di default già presente")

        db.commit()
        yield
    finally:
        db.close()

app = FastAPI(lifespan=lifespan)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

templates = Jinja2Templates(directory=TEMPLATES_DIR)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/", response_class=HTMLResponse)
async def root(request: FastAPIRequest, db: Session = Depends(get_db)):
    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        request=request, name="login.html", context={"services": services}
    )

@app.get("/list_services/")
async def list_services(db: Session = Depends(get_db)):
    return db.query(models.Services).all()

@app.get("/list_users/")
async def list_users(db: Session = Depends(get_db)):
    return db.query(models.User).all()

@app.post("/login/", response_class=HTMLResponse)
async def login(
    request: FastAPIRequest,
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user or not user.verify_password(password):
        return templates.TemplateResponse("home.html", {"request": request, "message": "Invalid credentials"})

    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "message": f"Welcome {user.name}!", "services": services})

@app.get("/register_service")
def register_service(request: Request):
    return templates.TemplateResponse(
        "register_service.html",
        {"request": request}
    )

@app.post("/add_service/")
def add_service(
    request: Request,
    name: str = Form(...),
    domain: str = Form(...),
    active: bool = Form(...),
    db: Session = Depends(get_db)
):
    new_service = models.Services(name=name, domain=domain, active=active)
    db.add(new_service)
    db.commit()
    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services,}
    )

@app.post("/delete_service/{service_id}")
def delete_service(service_id: int, request: Request, db: Session = Depends(get_db)):
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

@app.post("/status_service/{service_id}")
def status_service(service_id: int, request: Request, db: Session = Depends(get_db)):
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