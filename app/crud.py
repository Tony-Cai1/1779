from sqlalchemy.orm import Session
from datetime import date, timedelta
from sqlalchemy import desc

from . import models, schemas
from .auth import get_password_hash


def create_user(db: Session, user_in: schemas.UserCreate) -> models.User:
    hashed = get_password_hash(user_in.password)
    db_user = models.User(
        username=user_in.username,
        password_hash=hashed,
        role=user_in.role,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def create_book(db: Session, book_in: schemas.BookCreate) -> models.Book:
    db_book = models.Book(**book_in.dict())
    db.add(db_book)
    db.commit()
    db.refresh(db_book)
    return db_book


def list_books(db: Session):
    return db.query(models.Book).all()


def update_book(db: Session, book_id: int, book_in: schemas.BookUpdate):
    book = db.query(models.Book).get(book_id)
    if not book:
        return None
    for field, value in book_in.dict(exclude_unset=True).items():
        setattr(book, field, value)
    db.commit()
    db.refresh(book)
    return book


def delete_book(db: Session, book_id: int) -> bool:
    book = db.query(models.Book).get(book_id)
    if not book:
        return False
    db.delete(book)
    db.commit()
    return True


def borrow_book(db: Session, user_id: int, book_id: int, days: int = 14):
    book = db.query(models.Book).get(book_id)
    if not book or not book.available:
        return None
    today = date.today()
    due = today + timedelta(days=days)
    tx = models.Transaction(
        user_id=user_id,
        book_id=book_id,
        borrow_date=today,
        due_date=due,
        status="borrowed",
    )
    book.available = False
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


def return_book(db: Session, user_id: int, book_id: int):
    # find the most recent active borrowing for this user and book
    tx = (
        db.query(models.Transaction)
        .filter(
            models.Transaction.user_id == user_id,
            models.Transaction.book_id == book_id,
            models.Transaction.status == "borrowed",
        )
        .order_by(models.Transaction.borrow_date.desc())
        .first()
    )

    if not tx:
        return None

    # set return_date and status based on due_date
    tx.return_date = date.today()
    if tx.return_date > tx.due_date:
        tx.status = "overdue"
    else:
        tx.status = "returned"

    # mark the book as available again
    book = db.query(models.Book).get(book_id)
    if book:
        book.available = True

    db.commit()
    db.refresh(tx)
    return tx


def list_transactions_for_user(db: Session, user_id: int):
    return (
        db.query(models.Transaction)
        .filter(models.Transaction.user_id == user_id)
        .order_by(desc(models.Transaction.borrow_date))
        .all()
    )

def list_transactions_admin(
    db: Session,
    status: str | None = None,
    user_id: int | None = None,
    unreturned_only: bool = False,
):
    # join transactions with users and books
    query = (
        db.query(
            models.Transaction,
            models.User.username,
            models.Book.title,
        )
        .join(models.User, models.Transaction.user_id == models.User.id)
        .join(models.Book, models.Transaction.book_id == models.Book.id)
    )

    if user_id is not None:
        query = query.filter(models.Transaction.user_id == user_id)

    if unreturned_only:
        query = query.filter(models.Transaction.status.in_(["borrowed", "overdue"]))
    elif status is not None:
        query = query.filter(models.Transaction.status == status)

    query = query.order_by(desc(models.Transaction.borrow_date))

    rows = query.all()

    results: list[dict] = []
    for tx, username, book_title in rows:
        results.append(
            {
                "id": tx.id,
                "user_id": tx.user_id,
                "username": username,
                "book_id": tx.book_id,
                "book_title": book_title,
                "borrow_date": tx.borrow_date,
                "due_date": tx.due_date,
                "return_date": tx.return_date,
                "status": tx.status,
            }
        )

    return results

