package main

import (
	"errors"
	"log/slog"
	"fmt"
	"context"
	"bytes"
	"time"
	"database/sql"
	"os/signal"
	"syscall"
	"log"
	"net/http"
	"os"

	_ "github.com/lib/pq"
	httplog "github.com/clear-route/blog-post-vault-zero-to-hero/demo-app/internal/http"
)

func main() {
	dbHost, ok := os.LookupEnv("DB_HOST")
	if !ok {
		log.Fatal("DB_HOST missing")
	}

	dbPort, ok := os.LookupEnv("DB_PORT")
	if !ok {
		log.Fatal("DB_PORT missing")
	}

	dbUser, ok := os.LookupEnv("DB_USER")
	if !ok {
		log.Fatal("DB_USER missing")
	}

	dbPassword,  ok := os.LookupEnv("DB_PASSWORD")
	if !ok {
		log.Fatal("DB_PASSWORD missing")
	}

	dbName,  ok := os.LookupEnv("DB_NAME")
	if !ok {
		log.Fatal("DB_NAME missing")
	}

	connectionString := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	db, err := sql.Open("postgres", connectionString)
	if err != nil {
		log.Fatalf("Failed to open the database: %v", err)
	}

	defer db.Close()

	mux := &http.ServeMux{}
	mux.HandleFunc("/", httplog.LoggingMiddleware(func(w http.ResponseWriter, r *http.Request) {
		var resp bytes.Buffer

		connected := "true"
		if err := db.Ping(); err != nil {
			connected = fmt.Sprintf("false (%v)", err)
		}

		resp.WriteString("<html>\n<head>\n<title>Demo-App</title>\n</head>\n<body>\n")

		resp.WriteString(fmt.Sprintf("DB: %s:%s<br>", dbHost, dbPort))
		resp.WriteString(fmt.Sprintf("User: %s<br>", dbUser))
		resp.WriteString(fmt.Sprintf("Password: %s<br>", dbPassword))
		resp.WriteString(fmt.Sprintf("Ping: %v<br>", connected))

		resp.WriteString("</body>\n</html>\n")

		w.Write(resp.Bytes())

	}))

	done := make(chan os.Signal, 1)
	signal.Notify(done, syscall.SIGINT, syscall.SIGTERM)

	server := &http.Server{
		Addr:              "0.0.0.0:9090",
		Handler:           mux,
		ReadHeaderTimeout: 3 * time.Second,
	}

	go func() {
		slog.Info("start listening", slog.String("address", server.Addr))

		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("error while listening", slog.String("error", err.Error()))
		}
	}()

	<-done
	slog.Info("shutting down server")

	//nolint: mnd
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatal("error while shutting down server: %w", err)
	}

	log.Println("Exiting")
}