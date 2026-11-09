package com.example.notes;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestController
public class NotesController {
    record Note(long id, String author, String body, String created_at) {}

    private static final String NOTE = "SELECT n.id, u.username AS author, n.body, n.created_at FROM notes n JOIN users u ON u.id = n.user_id";
    private static final RowMapper<Note> ROW = (rs, i) -> new Note(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4));

    private final JdbcTemplate jdbc;
    private final ObjectMapper json;

    NotesController(JdbcTemplate jdbc, ObjectMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    static ResponseEntity<Map<String, String>> error(int status, String message) {
        return ResponseEntity.status(status).body(Map.of("error", message));
    }

    @GetMapping("/health")
    Map<String, String> health() {
        return Map.of("status", "ok");
    }

    @GetMapping("/notes")
    Map<String, List<Note>> list() {
        return Map.of("notes", jdbc.query(NOTE + " ORDER BY n.id DESC LIMIT 20", ROW));
    }

    @GetMapping("/notes/{id}")
    ResponseEntity<?> one(@PathVariable String id) {
        if (!id.matches("[1-9][0-9]*")) return error(400, "invalid id");
        long n;
        try {
            n = Long.parseLong(id);
        } catch (NumberFormatException e) {
            return error(404, "not found");
        }
        List<Note> found = jdbc.query(NOTE + " WHERE n.id = ?", ROW, n);
        return found.isEmpty() ? error(404, "not found") : ResponseEntity.ok(Map.of("note", found.get(0)));
    }

    @PostMapping("/notes")
    ResponseEntity<?> create(@RequestHeader(value = "Authorization", required = false) String auth,
                             @RequestBody(required = false) String raw) {
        List<Map<String, Object>> users = auth != null && auth.startsWith("Bearer ")
                ? jdbc.queryForList("SELECT id, username FROM users WHERE token = ?", auth.substring(7))
                : List.of();
        if (users.isEmpty()) return error(401, "unauthorized");
        JsonNode tree;
        try {
            tree = json.readTree(raw == null ? "" : raw);
        } catch (Exception e) {
            return error(400, "bad json");
        }
        JsonNode text = tree == null ? null : tree.get("body");
        String body = text != null && text.isTextual() ? text.asText().strip() : "";
        if (body.isEmpty() || body.codePointCount(0, body.length()) > 500) return error(400, "invalid body");
        long userId = ((Number) users.get(0).get("id")).longValue();
        String username = (String) users.get(0).get("username");
        Map<String, Object> row = jdbc.queryForMap("INSERT INTO notes (user_id, body) VALUES (?, ?) RETURNING id, created_at", userId, body);
        Note note = new Note(((Number) row.get("id")).longValue(), username, body, (String) row.get("created_at"));
        return ResponseEntity.status(201).body(Map.of("note", note));
    }
}

@RestControllerAdvice
class NotFound {
    @ExceptionHandler({NoResourceFoundException.class, NoHandlerFoundException.class})
    ResponseEntity<Map<String, String>> notFound() {
        return NotesController.error(404, "not found");
    }
}
