import json, os, re, sqlite3

from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool
from starlette.exceptions import HTTPException

DB = os.environ["SQLITE_PATH"]
NOTE = "SELECT n.id, u.username AS author, n.body, n.created_at FROM notes n JOIN users u ON u.id = n.user_id"
VALID_ID = re.compile(r"[1-9][0-9]*")

app = FastAPI()


def get_db():
    db = sqlite3.connect(DB, check_same_thread=False)
    try:
        yield db
    finally:
        db.close()


def note(r):
    return {"id": r[0], "author": r[1], "body": r[2], "created_at": r[3]}


def error(status, message):
    return JSONResponse({"error": message}, status_code=status)


@app.exception_handler(HTTPException)
def http_error(request, exc):
    return error(exc.status_code, "not found" if exc.status_code == 404 else "error")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/notes")
def list_notes(db: sqlite3.Connection = Depends(get_db)):
    return {"notes": [note(r) for r in db.execute(f"{NOTE} ORDER BY n.id DESC LIMIT 20")]}


@app.get("/notes/{note_id}")
def one_note(note_id: str, db: sqlite3.Connection = Depends(get_db)):
    if not VALID_ID.fullmatch(note_id):
        return error(400, "invalid id")
    r = db.execute(f"{NOTE} WHERE n.id = ?", (int(note_id),)).fetchone()
    return {"note": note(r)} if r else error(404, "not found")


def find_user(token):
    db = sqlite3.connect(DB)
    try:
        return db.execute("SELECT id, username FROM users WHERE token = ?", (token,)).fetchone()
    finally:
        db.close()


def insert(user_id, body):
    db = sqlite3.connect(DB)
    try:
        row = db.execute("INSERT INTO notes (user_id, body) VALUES (?, ?) RETURNING id, created_at", (user_id, body)).fetchone()
        db.commit()
        return row
    finally:
        db.close()


@app.post("/notes")
async def create_note(request: Request):
    auth = request.headers.get("authorization", "")
    user = await run_in_threadpool(find_user, auth[7:]) if auth.startswith("Bearer ") else None
    if not user:
        return error(401, "unauthorized")
    try:
        data = json.loads(await request.body())
    except ValueError:
        return error(400, "bad json")
    raw = data.get("body") if isinstance(data, dict) else None
    body = raw.strip() if isinstance(raw, str) else ""
    if not body or len(body) > 500:
        return error(400, "invalid body")
    note_id, created_at = await run_in_threadpool(insert, user[0], body)
    return JSONResponse({"note": {"id": note_id, "author": user[1], "body": body, "created_at": created_at}}, status_code=201)
