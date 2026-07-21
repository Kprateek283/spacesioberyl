package middleware

import (
	"net/http"
	"net/url"
)

// allowedLocalOrigins are the development hosts always permitted.
var allowedLocalOrigins = map[string]struct{}{
	"localhost": {},
	"127.0.0.1": {},
	"::1":       {},
	"10.0.2.2":  {},
}

// CORS returns middleware that reflects the request Origin when it is allowed.
// The allow-list is the fixed local set plus extraOrigins (whole origin strings
// such as "https://app.example.com"), configured from CORS_ALLOWED_ORIGINS.
func CORS(extraOrigins []string) func(http.Handler) http.Handler {
	allowed := make(map[string]struct{}, len(extraOrigins))
	for _, o := range extraOrigins {
		allowed[o] = struct{}{}
	}

	isAllowed := func(origin string) bool {
		if _, ok := allowed[origin]; ok {
			return true
		}
		parsed, err := url.Parse(origin)
		if err != nil {
			return false
		}
		// Exact host match only. A prefix match (e.g. HasPrefix "localhost")
		// would also admit lookalikes like "localhost.attacker.com" (#20).
		_, ok := allowedLocalOrigins[parsed.Hostname()]
		return ok
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin != "" && isAllowed(origin) {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Vary", "Origin")
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, Origin, X-Requested-With")
				w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Type")
			}

			if r.Method == http.MethodOptions {
				if origin == "" || isAllowed(origin) {
					w.WriteHeader(http.StatusNoContent)
					return
				}
				w.WriteHeader(http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
