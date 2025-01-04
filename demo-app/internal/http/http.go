package http

import (
	"log/slog"
	"net/http"
	"time"
)

// LoggingMiddleware is a simple http logging middleware.
func LoggingMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		next(w, r)

		slog.Info("received request",
			slog.String("method", r.Method),
			slog.String("path", r.RequestURI),
			slog.String("duration", time.Since(start).String()),
			slog.String("client", r.RemoteAddr),
		)
	})
}
