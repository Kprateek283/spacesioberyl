package middleware

import "net/http"

// MaxRequestBytes caps the size of any request body read into memory. It sits a
// little above the BFF upload's own 10 MB file cap so multipart overhead still
// fits; every JSON handler is thereby bounded without per-handler wiring
// (backend-bugs #19).
const MaxRequestBytes = 11 << 20 // 11 MB

// LimitBody wraps every request body in an http.MaxBytesReader so an oversized
// payload is rejected instead of being read entirely into memory.
func LimitBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Body != nil {
			r.Body = http.MaxBytesReader(w, r.Body, MaxRequestBytes)
		}
		next.ServeHTTP(w, r)
	})
}
