package main

import (
	"database/sql"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"

	_ "github.com/mattn/go-sqlite3"
)

const noteSQL = "SELECT n.id, u.username, n.body, n.created_at FROM notes n JOIN users u ON u.id = n.user_id"

type Note struct {
	ID        int64  `json:"id"`
	Author    string `json:"author"`
	Body      string `json:"body"`
	CreatedAt string `json:"created_at"`
}

var (
	db      *sql.DB
	validID = regexp.MustCompile(`^[1-9][0-9]*$`)
)

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func fail(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, map[string]string{"status": "ok"})
}

func list(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(noteSQL + " ORDER BY n.id DESC LIMIT 20")
	if err != nil {
		fail(w, 500, "internal server error")
		return
	}
	defer rows.Close()
	notes := []Note{}
	for rows.Next() {
		var n Note
		if err := rows.Scan(&n.ID, &n.Author, &n.Body, &n.CreatedAt); err != nil {
			fail(w, 500, "internal server error")
			return
		}
		notes = append(notes, n)
	}
	writeJSON(w, 200, map[string][]Note{"notes": notes})
}

func one(w http.ResponseWriter, r *http.Request) {
	idText := r.PathValue("id")
	if !validID.MatchString(idText) {
		fail(w, 400, "invalid id")
		return
	}
	id, err := strconv.ParseInt(idText, 10, 64)
	if err != nil {
		fail(w, 404, "not found")
		return
	}
	var n Note
	err = db.QueryRow(noteSQL+" WHERE n.id = ?", id).Scan(&n.ID, &n.Author, &n.Body, &n.CreatedAt)
	if err == sql.ErrNoRows {
		fail(w, 404, "not found")
		return
	} else if err != nil {
		fail(w, 500, "internal server error")
		return
	}
	writeJSON(w, 200, map[string]Note{"note": n})
}

func create(w http.ResponseWriter, r *http.Request) {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		fail(w, 401, "unauthorized")
		return
	}
	var userID int64
	var username string
	err := db.QueryRow("SELECT id, username FROM users WHERE token = ?", auth[7:]).Scan(&userID, &username)
	if err == sql.ErrNoRows {
		fail(w, 401, "unauthorized")
		return
	} else if err != nil {
		fail(w, 500, "internal server error")
		return
	}
	raw, err := io.ReadAll(r.Body)
	if err != nil {
		fail(w, 400, "bad json")
		return
	}
	var parsed any
	if err := json.Unmarshal(raw, &parsed); err != nil {
		fail(w, 400, "bad json")
		return
	}
	obj, _ := parsed.(map[string]any)
	text, _ := obj["body"].(string)
	body := strings.TrimSpace(text)
	if body == "" || utf8.RuneCountInString(body) > 500 {
		fail(w, 400, "invalid body")
		return
	}
	n := Note{Author: username, Body: body}
	err = db.QueryRow("INSERT INTO notes (user_id, body) VALUES (?, ?) RETURNING id, created_at", userID, body).Scan(&n.ID, &n.CreatedAt)
	if err != nil {
		fail(w, 500, "internal server error")
		return
	}
	writeJSON(w, 201, map[string]Note{"note": n})
}

func main() {
	var err error
	db, err = sql.Open("sqlite3", os.Getenv("SQLITE_PATH"))
	if err != nil {
		panic(err)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", health)
	mux.HandleFunc("GET /notes", list)
	mux.HandleFunc("POST /notes", create)
	mux.HandleFunc("GET /notes/{id}", one)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { fail(w, 404, "not found") })
	panic(http.ListenAndServe(os.Getenv("HOST")+":"+os.Getenv("PORT"), mux))
}
