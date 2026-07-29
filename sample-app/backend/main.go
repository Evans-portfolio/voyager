package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
)

type MetricSnapshot struct {
	ID           int64     `json:"id"`
	RecordedAt   time.Time `json:"recorded_at"`
	AllocBytes   uint64    `json:"alloc_bytes"`
	NumGoroutine int       `json:"num_goroutine"`
}

var db *sql.DB

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

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handleHealthz)
	mux.HandleFunc("GET /history", handleHistory)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	addr := ":" + port
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
