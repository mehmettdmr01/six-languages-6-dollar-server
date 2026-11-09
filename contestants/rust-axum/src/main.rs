use axum::{
    body::Bytes,
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};
use serde::Serialize;
use serde_json::{json, Value};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool};

const LIST: &str = "SELECT n.id, u.username AS author, n.body, n.created_at FROM notes n JOIN users u ON u.id = n.user_id ORDER BY n.id DESC LIMIT 20";
const ONE: &str = "SELECT n.id, u.username AS author, n.body, n.created_at FROM notes n JOIN users u ON u.id = n.user_id WHERE n.id = ?";

#[derive(Serialize, sqlx::FromRow)]
struct Note {
    id: i64,
    author: String,
    body: String,
    created_at: String,
}

#[derive(Serialize)]
struct NoteList {
    notes: Vec<Note>,
}

#[derive(Serialize)]
struct OneNote {
    note: Note,
}

fn fail(status: StatusCode, message: &str) -> Response {
    (status, Json(json!({ "error": message }))).into_response()
}

async fn health() -> Response {
    Json(json!({ "status": "ok" })).into_response()
}

async fn list(State(db): State<SqlitePool>) -> Response {
    match sqlx::query_as::<_, Note>(LIST).fetch_all(&db).await {
        Ok(notes) => Json(NoteList { notes }).into_response(),
        Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "internal server error"),
    }
}

async fn one(State(db): State<SqlitePool>, Path(id): Path<String>) -> Response {
    let valid = !id.is_empty() && !id.starts_with('0') && id.bytes().all(|b| b.is_ascii_digit());
    if !valid {
        return fail(StatusCode::BAD_REQUEST, "invalid id");
    }
    let Ok(n) = id.parse::<i64>() else {
        return fail(StatusCode::NOT_FOUND, "not found");
    };
    match sqlx::query_as::<_, Note>(ONE).bind(n).fetch_optional(&db).await {
        Ok(Some(note)) => Json(OneNote { note }).into_response(),
        Ok(None) => fail(StatusCode::NOT_FOUND, "not found"),
        Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "internal server error"),
    }
}

async fn create(State(db): State<SqlitePool>, headers: HeaderMap, raw: Bytes) -> Response {
    let token = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "));
    let user = match token {
        Some(t) => match sqlx::query_as::<_, (i64, String)>("SELECT id, username FROM users WHERE token = ?")
            .bind(t)
            .fetch_optional(&db)
            .await
        {
            Ok(u) => u,
            Err(_) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "internal server error"),
        },
        None => None,
    };
    let Some((user_id, username)) = user else {
        return fail(StatusCode::UNAUTHORIZED, "unauthorized");
    };
    let parsed: Value = match serde_json::from_slice(&raw) {
        Ok(v) => v,
        Err(_) => return fail(StatusCode::BAD_REQUEST, "bad json"),
    };
    let body = parsed.get("body").and_then(Value::as_str).map(str::trim).unwrap_or("");
    if body.is_empty() || body.chars().count() > 500 {
        return fail(StatusCode::BAD_REQUEST, "invalid body");
    }
    // fetch_all steps the statement to the end, so the row is committed before the 201 goes out
    let inserted = sqlx::query_as::<_, (i64, String)>("INSERT INTO notes (user_id, body) VALUES (?, ?) RETURNING id, created_at")
        .bind(user_id)
        .bind(body)
        .fetch_all(&db)
        .await
        .map(|rows| rows.into_iter().next());
    match inserted {
        Ok(Some((id, created_at))) => (
            StatusCode::CREATED,
            Json(OneNote { note: Note { id, author: username, body: body.to_string(), created_at } }),
        )
            .into_response(),
        _ => fail(StatusCode::INTERNAL_SERVER_ERROR, "internal server error"),
    }
}

#[tokio::main]
async fn main() {
    let path = std::env::var("SQLITE_PATH").expect("SQLITE_PATH");
    let host = std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".into());
    let port = std::env::var("PORT").unwrap_or_else(|_| "80".into());
    let db = SqlitePool::connect_with(SqliteConnectOptions::new().filename(&path)).await.expect("database");
    let app = Router::new()
        .route("/health", get(health))
        .route("/notes", get(list).post(create))
        .route("/notes/{id}", get(one))
        .fallback(|| async { fail(StatusCode::NOT_FOUND, "not found") })
        .with_state(db);
    let listener = tokio::net::TcpListener::bind(format!("{host}:{port}")).await.expect("bind");
    axum::serve(listener, app).await.expect("serve");
}
