from sqlalchemy import Column, Integer, String, Boolean
from .database import Base
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class Services(Base):
    __tablename__ = "services"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False)
    domain = Column(String(100), nullable=False, unique=True)
    active = Column(Boolean, default=True, nullable=True)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), nullable=False)
    email = Column(String(100), nullable=False, unique=True)
    password = Column(String(100), nullable=False)
    name = Column(String(100), nullable=True)
    surname = Column(String(100), nullable=True)
    active = Column(Boolean, default=True, nullable=True)
    city = Column(String(100), nullable=True)
    description = Column(String(100), nullable=True)

    def __repr__(self):
        return f"User(username={self.username}, email={self.email})"

    def set_password(self, raw_password):
        self.password = pwd_context.hash(raw_password)

    def verify_password(self, raw_password):
        return pwd_context.verify(raw_password, self.password)