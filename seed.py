import random
from datetime import date, timedelta

from app.db import SessionLocal
from app import models, auth


def ensure_admin(db):
    admin_username = "admin1"
    admin = db.query(models.User).filter_by(username=admin_username).first()
    if admin:
        print(f"Admin user '{admin_username}' already exists (id={admin.id})")
        return admin

    admin = models.User(
        username=admin_username,
        password_hash=auth.get_password_hash("admin123"),
        role="admin",
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    print(f"Created admin user '{admin_username}' with password 'admin123'")
    return admin


def ensure_members(db, count=20):
    members = []
    for i in range(1, count + 1):
        username = f"member{i}"
        user = db.query(models.User).filter_by(username=username).first()
        if user:
            print(f"Member user '{username}' already exists (id={user.id})")
        else:
            user = models.User(
                username=username,
                password_hash=auth.get_password_hash("member123"),
                role="member",
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            print(f"Created member user '{username}' with password 'member123'")
        members.append(user)
    return members


def ensure_books(db, count=100):
    existing_books = db.query(models.Book).count()
    if existing_books >= count:
        print(f"Books table already has {existing_books} records, skipping book seeding.")
        return db.query(models.Book).all()

    genres = ["Fiction", "Non-Fiction", "Science", "History", "Programming", "Fantasy"]
    books = []
    for i in range(1, count + 1):
        title = f"Sample Book {i}"
        author = f"Author {((i - 1) % 15) + 1}"
        isbn = f"ISBN-{1000000000 + i}"
        genre = random.choice(genres)
        shelf = f"Shelf-{((i - 1) % 10) + 1}"

        book = models.Book(
            title=title,
            author=author,
            isbn=isbn,
            genre=genre,
            shelf_location=shelf,
            available=True,  # may change later in transactions seeding
        )
        db.add(book)
        books.append(book)

    db.commit()
    # refresh with ids
    for book in books:
        db.refresh(book)

    print(f"Created {len(books)} books.")
    return books


def seed_transactions(db, members, books):
    existing_tx = db.query(models.Transaction).count()
    if existing_tx > 0:
        print(f"Transactions table already has {existing_tx} records, skipping transaction seeding.")
        return

    if not members:
        print("No members found, cannot seed transactions.")
        return

    today = date.today()
    tx_count = 0

    for book in books:
        # Decide scenario for this book
        r = random.random()

        # About 40 percent of books have no history
        if r < 0.4:
            # leave book.available as is (default True from ensure_books)
            continue

        member = random.choice(members)

        # borrow date in last 60 days
        borrow_days_ago = random.randint(5, 60)
        borrow_date = today - timedelta(days=borrow_days_ago)

        # loan duration between 7 and 21 days
        loan_length = random.randint(7, 21)
        due_date = borrow_date + timedelta(days=loan_length)

        # 0.3 range: returned on time
        # 0.2 range: returned overdue
        # 0.1 range: currently borrowed and not returned
        if r < 0.7:
            # returned on time
            return_offset = random.randint(1, loan_length)
            return_date = borrow_date + timedelta(days=return_offset)
            status = "returned"
            book.available = True

        elif r < 0.9:
            # returned late (overdue)
            extra_days = random.randint(1, 14)
            return_date = due_date + timedelta(days=extra_days)
            status = "overdue"
            book.available = True

        else:
            # currently borrowed, not yet returned
            return_date = None
            status = "borrowed"
            book.available = False

        tx = models.Transaction(
            user_id=member.id,
            book_id=book.id,
            borrow_date=borrow_date,
            due_date=due_date,
            return_date=return_date,
            status=status,
        )
        db.add(tx)
        tx_count += 1

    db.commit()
    print(f"Created {tx_count} transactions with mixed statuses (returned, overdue, borrowed).")


def main():
    db = SessionLocal()
    try:
        print("Seeding database...")

        admin = ensure_admin(db)
        members = ensure_members(db, count=20)
        books = ensure_books(db, count=100)
        seed_transactions(db, members, books)

        print("Seeding complete.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
