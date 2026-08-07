package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"golang.org/x/crypto/bcrypt"
)

var historyRequestsTotal = promauto.NewCounter(prometheus.CounterOpts{
	Name: "backend_history_requests_total",
	Help: "Total number of requests to the /history endpoint",
})

type MetricSnapshot struct {
	ID           int64     `json:"id"`
	RecordedAt   time.Time `json:"recorded_at"`
	AllocBytes   uint64    `json:"alloc_bytes"`
	NumGoroutine int       `json:"num_goroutine"`
}

var db *sql.DB
var sessionSecret []byte

func main() {
	var err error
	db, err = sql.Open("pgx", buildDSN())
	if err != nil {
		log.Fatalf("failed to open database: %v", err)
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	if err := ensureSchema(ctx); err != nil {
		log.Fatalf("failed to ensure schema: %v", err)
	}

	// Session cookies are signed with a key derived from the DB password
	// already injected via External Secrets, so every backend replica in
	// an environment signs/verifies with the same key without needing a
	// separate secret or credential path.
	secretHash := sha256.Sum256([]byte(os.Getenv("DB_PASSWORD") + "server-sorcery-session-v1"))
	sessionSecret = secretHash[:]

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handleHealthz)
	mux.HandleFunc("GET /history", handleHistory)
	mux.HandleFunc("POST /register", handleRegister)
	mux.HandleFunc("POST /login", handleLogin)
	mux.HandleFunc("POST /logout", handleLogout)
	mux.Handle("GET /metrics", promhttp.Handler())

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	addr := ":" + port
	log.Printf("routes registered: /health /history /register /login /logout /metrics")
	log.Printf("listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}

func buildDSN() string {
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	if port == "" {
		port = "5432"
	}
	user := os.Getenv("DB_USER")
	password := os.Getenv("DB_PASSWORD")
	dbname := os.Getenv("DB_NAME")
	sslmode := os.Getenv("DB_SSLMODE")
	if sslmode == "" {
		sslmode = "require"
	}

	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		host, port, user, password, dbname, sslmode)
}

func ensureSchema(ctx context.Context) error {
	_, err := db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS metrics_history (
			id            BIGSERIAL PRIMARY KEY,
			recorded_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
			alloc_bytes   BIGINT NOT NULL,
			num_goroutine INTEGER NOT NULL
		)
	`)
	if err != nil {
		return err
	}

	_, err = db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS users (
			id            BIGSERIAL PRIMARY KEY,
			email         TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL,
			created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
		)
	`)
	return err
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		http.Error(w, "database unreachable", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
}

// handleHistory records a snapshot of the process's current runtime metrics
// and returns the most recent snapshots, newest first.
func handleHistory(w http.ResponseWriter, r *http.Request) {
	historyRequestsTotal.Inc()
	ctx := r.Context()

	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)

	_, err := db.ExecContext(ctx,
		`INSERT INTO metrics_history (alloc_bytes, num_goroutine) VALUES ($1, $2)`,
		mem.Alloc, runtime.NumGoroutine(),
	)
	if err != nil {
		log.Printf("failed to record snapshot: %v", err)
		http.Error(w, "failed to record snapshot", http.StatusInternalServerError)
		return
	}

	rows, err := db.QueryContext(ctx,
		`SELECT id, recorded_at, alloc_bytes, num_goroutine
		 FROM metrics_history
		 ORDER BY recorded_at DESC
		 LIMIT 50`,
	)
	if err != nil {
		log.Printf("failed to query history: %v", err)
		http.Error(w, "failed to query history", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	history := []MetricSnapshot{}
	for rows.Next() {
		var m MetricSnapshot
		if err := rows.Scan(&m.ID, &m.RecordedAt, &m.AllocBytes, &m.NumGoroutine); err != nil {
			log.Printf("failed to scan row: %v", err)
			http.Error(w, "failed to read history", http.StatusInternalServerError)
			return
		}
		history = append(history, m)
	}
	if err := rows.Err(); err != nil {
		log.Printf("row iteration error: %v", err)
		http.Error(w, "failed to read history", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(history); err != nil {
		log.Printf("failed to encode response: %v", err)
	}
}

type authRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func handleRegister(w http.ResponseWriter, r *http.Request) {
	var req authRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" || len(req.Password) < 8 {
		http.Error(w, "email is required and password must be at least 8 characters", http.StatusBadRequest)
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("failed to hash password: %v", err)
		http.Error(w, "failed to register", http.StatusInternalServerError)
		return
	}

	ctx := r.Context()
	_, err = db.ExecContext(ctx,
		`INSERT INTO users (email, password_hash) VALUES ($1, $2)`,
		email, string(hash),
	)
	if err != nil {
		if isUniqueViolation(err) {
			http.Error(w, "email already registered", http.StatusConflict)
			return
		}
		log.Printf("failed to insert user: %v", err)
		http.Error(w, "failed to register", http.StatusInternalServerError)
		return
	}

	log.Printf("AUTH: user registered: %s", email)
	w.WriteHeader(http.StatusCreated)
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	var req authRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" || req.Password == "" {
		http.Error(w, "email and password are required", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	var hash string
	err := db.QueryRowContext(ctx, `SELECT password_hash FROM users WHERE email = $1`, email).Scan(&hash)
	if errors.Is(err, sql.ErrNoRows) {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	if err != nil {
		log.Printf("failed to query user: %v", err)
		http.Error(w, "failed to login", http.StatusInternalServerError)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)); err != nil {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    signSession(email),
		Path:     "/",
		HttpOnly: true,
		Secure:   isRequestSecure(r),
		SameSite: http.SameSiteLaxMode,
		MaxAge:   86400,
	})

	log.Printf("AUTH: user logged in: %s", email)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"email": email})
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	email, ok := currentUser(r)

	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Secure:   isRequestSecure(r),
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})

	if ok {
		log.Printf("AUTH: user logged out: %s", email)
	} else {
		log.Printf("AUTH: logout called with no active session")
	}
	w.WriteHeader(http.StatusOK)
}

// currentUser is a small helper other routes can use later to check who
// (if anyone) is logged in. Not wired into any existing route.
func currentUser(r *http.Request) (string, bool) {
	c, err := r.Cookie("session")
	if err != nil {
		return "", false
	}
	return verifySession(c.Value)
}

func isRequestSecure(r *http.Request) bool {
	return r.Header.Get("X-Forwarded-Proto") == "https"
}

func signSession(email string) string {
	expiry := time.Now().Add(24 * time.Hour).Unix()
	payload := fmt.Sprintf("%s|%d", email, expiry)
	mac := hmac.New(sha256.New, sessionSecret)
	mac.Write([]byte(payload))
	sig := hex.EncodeToString(mac.Sum(nil))
	return base64.RawURLEncoding.EncodeToString([]byte(payload)) + "." + sig
}

func verifySession(cookieValue string) (string, bool) {
	parts := strings.SplitN(cookieValue, ".", 2)
	if len(parts) != 2 {
		return "", false
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return "", false
	}
	mac := hmac.New(sha256.New, sessionSecret)
	mac.Write(payloadBytes)
	expectedSig := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(expectedSig), []byte(parts[1])) {
		return "", false
	}

	fields := strings.SplitN(string(payloadBytes), "|", 2)
	if len(fields) != 2 {
		return "", false
	}
	expiry, err := strconv.ParseInt(fields[1], 10, 64)
	if err != nil || time.Now().Unix() > expiry {
		return "", false
	}
	return fields[0], true
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == "23505"
	}
	return false
}
