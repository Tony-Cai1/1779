from pydantic import BaseModel
from typing import Optional
from datetime import date
from pydantic import BaseModel

class UserBase(BaseModel):
    username: str


class UserCreate(UserBase):
    password: str
    role: str  # "admin" or "member"


class UserOut(UserBase):
    id: int
    role: str

    class Config:
        orm_mode = True


class BookBase(BaseModel):
    title: str
    author: str
    isbn: Optional[str] = None
    genre: Optional[str] = None
    shelf_location: Optional[str] = None


class BookCreate(BookBase):
    pass


class BookUpdate(BaseModel):
    title: Optional[str] = None
    author: Optional[str] = None
    isbn: Optional[str] = None
    genre: Optional[str] = None
    shelf_location: Optional[str] = None
    available: Optional[bool] = None


class BookOut(BookBase):
    id: int
    available: bool

    class Config:
        orm_mode = True


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    username: Optional[str] = None
    role: Optional[str] = None


class BorrowRequest(BaseModel):
    book_id: int
    days: int = 14


class ReturnRequest(BaseModel):
    book_id: int
    

class TransactionOut(BaseModel):
    id: int
    user_id: int
    book_id: int
    borrow_date: date
    due_date: date
    return_date: date | None
    status: str

    class Config:
        from_attributes = True  # important for SQLAlchemy models

class AdminTransactionOut(BaseModel):
    id: int
    user_id: int
    username: str
    book_id: int
    book_title: str
    borrow_date: date
    due_date: date
    return_date: date | None
    status: str
