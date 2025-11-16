from sqlalchemy import Column, Integer, String, Boolean, Text, Date, ForeignKey, TIMESTAMP
from sqlalchemy.orm import relationship
from .db import Base
from datetime import datetime


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    role = Column(String(20), nullable=False)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)


class Book(Base):
    __tablename__ = "books"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(Text, nullable=False)
    author = Column(Text, nullable=False)
    isbn = Column(String(20), unique=True, index=True)
    genre = Column(String(50))
    available = Column(Boolean, default=True, nullable=False)
    shelf_location = Column(String(50))
    created_at = Column(TIMESTAMP, default=datetime.utcnow)


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    book_id = Column(Integer, ForeignKey("books.id"), nullable=False)
    borrow_date = Column(Date, nullable=False)
    due_date = Column(Date, nullable=False)
    return_date = Column(Date, nullable=True)
    status = Column(String(20), nullable=False)

    user = relationship("User")
    book = relationship("Book")

