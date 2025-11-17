from typing import List, Optional
import time

from fastapi import (
    FastAPI,
    Depends,
    HTTPException,
    status,
    WebSocket,
    WebSocketDisconnect,
    Query,
    Request,
)
from fastapi.security import OAuth2PasswordRequestForm
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Counter, Histogram, Gauge

from .db import Base, engine, get_db
from . import models, schemas, crud, auth


# Create tables on startup if they do not exist
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Library Management System")

# Initialize Prometheus Instrumentator
instrumentator = Instrumentator()
instrumentator.instrument(app).expose(app)

# Custom metrics for API usage tracking
api_request_counter = Counter(
    'lms_api_requests_total',
    'Total number of API requests',
    ['method', 'endpoint', 'status_code']
)

api_request_duration = Histogram(
    'lms_api_request_duration_seconds',
    'API request duration in seconds',
    ['method', 'endpoint']
)

api_endpoint_counter = Counter(
    'lms_api_endpoint_requests_total',
    'Total requests per endpoint',
    ['endpoint', 'method']
)

active_websocket_connections = Gauge(
    'lms_websocket_connections_active',
    'Number of active WebSocket connections'
)

# Middleware to track API metrics
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    
    response = await call_next(request)
    
    # Record metrics
    duration = time.time() - start_time
    endpoint = request.url.path
    method = request.method
    status_code = response.status_code
    
    api_request_counter.labels(
        method=method,
        endpoint=endpoint,
        status_code=status_code
    ).inc()
    
    api_request_duration.labels(
        method=method,
        endpoint=endpoint
    ).observe(duration)
    
    api_endpoint_counter.labels(
        endpoint=endpoint,
        method=method
    ).inc()
    
    return response


@app.get("/health")
def health_check():
    return {"status": "ok"}


# ------------- Authentication and Users -------------


@app.post("/auth/login", response_model=schemas.Token)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = auth.authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )
    token = auth.create_access_token({"sub": user.username, "role": user.role})
    return {"access_token": token, "token_type": "bearer"}


@app.post("/users/", response_model=schemas.UserOut)
def create_user(
    user_in: schemas.UserCreate,
    db: Session = Depends(get_db),
    _: models.User = Depends(auth.get_current_admin),
):
    """Admin only create a new user"""
    return crud.create_user(db, user_in)


# ------------- Books CRUD -------------


@app.get("/books/", response_model=List[schemas.BookOut])
def get_books(db: Session = Depends(get_db)):
    return crud.list_books(db)


@app.get("/books/{book_id}", response_model=schemas.BookOut)
def get_book(book_id: int, db: Session = Depends(get_db)):
    """Get a single book by its ID, including availability status"""
    book = crud.get_book(db, book_id)
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    return book


@app.post("/books/", response_model=schemas.BookOut)
def create_book(
    book_in: schemas.BookCreate,
    db: Session = Depends(get_db),
    _: models.User = Depends(auth.get_current_admin),
):
    return crud.create_book(db, book_in)


@app.put("/books/{book_id}", response_model=schemas.BookOut)
def update_book(
    book_id: int,
    book_in: schemas.BookUpdate,
    db: Session = Depends(get_db),
    _: models.User = Depends(auth.get_current_admin),
):
    book = crud.update_book(db, book_id, book_in)
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    return book


@app.delete("/books/{book_id}")
def delete_book(
    book_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(auth.get_current_admin),
):
    ok = crud.delete_book(db, book_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Book not found")
    return {"deleted": True}


# ------------- Borrow and Return -------------


@app.post("/borrow")
async def borrow_book(
    req: schemas.BorrowRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(auth.get_current_member),
):
    tx = crud.borrow_book(db, user_id=user.id, book_id=req.book_id, days=req.days)
    if not tx:
        raise HTTPException(status_code=400, detail="Book not available")

    # fetch updated book for availability broadcast
    book = db.query(models.Book).get(tx.book_id)
    if book:
        await manager.broadcast(
            {
                "event": "book_update",
                "book_id": book.id,
                "title": book.title,
                "available": book.available,
                "genre": book.genre,
                "shelf_location": book.shelf_location,
            }
        )

    return {
        "transaction_id": tx.id,
        "book_id": tx.book_id,
        "status": tx.status,
        "due_date": tx.due_date,
    }


@app.post("/return")
async def return_book(
    req: schemas.ReturnRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(auth.get_current_member),
):
    tx = crud.return_book(db, user_id=user.id, book_id=req.book_id)
    if not tx:
        raise HTTPException(
            status_code=400,
            detail="No active borrowing found for this user and book",
        )

    book = db.query(models.Book).get(tx.book_id)
    if book:
        await manager.broadcast(
            {
                "event": "book_update",
                "book_id": book.id,
                "title": book.title,
                "available": book.available,
                "genre": book.genre,
                "shelf_location": book.shelf_location,
            }
        )

    return {
        "transaction_id": tx.id,
        "book_id": tx.book_id,
        "status": tx.status,
        "return_date": tx.return_date,
    }


# ------------- Transactions -------------


@app.get("/me/transactions", response_model=List[schemas.TransactionOut])
def list_my_transactions(
    db: Session = Depends(get_db),
    user: models.User = Depends(auth.get_current_member),
):
    """
    Return all borrowing transactions for the currently logged in user,
    ordered by most recent borrow first.
    """
    return crud.list_transactions_for_user(db, user.id)


@app.get("/admin/transactions", response_model=List[schemas.AdminTransactionOut])
def admin_list_transactions(
    db: Session = Depends(get_db),
    _: models.User = Depends(auth.get_current_admin),
    status: Optional[str] = Query(
        None,
        description="Filter by status: borrowed, returned, or overdue",
    ),
    user_id: Optional[int] = Query(
        None,
        description="Filter by user id",
    ),
    unreturned_only: bool = Query(
        False,
        description="If true, only show books that have not been returned yet",
    ),
):
    if status is not None and status not in {"borrowed", "returned", "overdue"}:
        raise HTTPException(status_code=400, detail="Invalid status value")

    return crud.list_transactions_admin(
        db=db,
        status=status,
        user_id=user_id,
        unreturned_only=unreturned_only,
    )


# ------------- WebSocket for admin availability updates -------------


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        active_websocket_connections.set(len(self.active_connections))
        print(f"Admin WS connected. Total: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            active_websocket_connections.set(len(self.active_connections))
            print(f"Admin WS disconnected. Total: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        disconnected: List[WebSocket] = []
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                disconnected.append(connection)
        for ws in disconnected:
            self.disconnect(ws)


manager = ConnectionManager()


@app.websocket("/ws/admin")
async def admin_websocket(websocket: WebSocket):
    """
    WebSocket endpoint for admin dashboards.

    Connect with:
    ws://127.0.0.1:8000/ws/admin?token=JWT_TOKEN_HERE

    Only JWTs with role=admin are allowed.
    """
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return

    try:
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        role = payload.get("role")
        if role != "admin":
            await websocket.close(code=4403)
            return
    except JWTError:
        await websocket.close(code=4401)
        return

    await manager.connect(websocket)
    try:
        while True:
            # Optional: receive ping or other admin messages (currently ignored)
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
