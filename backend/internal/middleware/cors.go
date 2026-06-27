package middleware

import (
	"net/http"
	"net/url"
	"strings"
)

var allowedLocalOrigins = map[string]struct{}{
	"localhost":     {},
	"127.0.0.1":      {},
	"::1":            {},
	"10.0.2.2":       {},
}

// CORS enables browser access for local development origins.
func CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && isAllowedOrigin(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, Origin, X-Requested-With")
			w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Type")
		}

		if r.Method == http.MethodOptions {
			if origin == "" || isAllowedOrigin(origin) {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			w.WriteHeader(http.StatusForbidden)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func isAllowedOrigin(origin string) bool {
	parsed, err := url.Parse(origin)
	if err != nil {
		return false
	}

	host := parsed.Hostname()
	if _, ok := allowedLocalOrigins[host]; ok {
		return true
	}

	return strings.HasPrefix(host, "localhost")
}