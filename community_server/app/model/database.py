from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = f"mysql+pymysql://{os.getenv('CS_DB_USER')}:{os.getenv('CS_DB_PASSWORD')}@{os.getenv('CS_DB_HOST')}:{os.getenv('CS_DB_PORT')}/{os.getenv('CS_DB_NAME')}"

engine = create_engine(DATABASE_URL, echo=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()