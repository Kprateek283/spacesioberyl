package middleware

import (
	"net/http"
	"strconv"
)

// Pagination defaults. List endpoints apply these so a query never scans and
// returns an entire table unbounded (backend-bugs #30).
const (
	DefaultPageLimit = 50
	MaxPageLimit     = 200
)

// Paginate reads ?limit= and ?offset= with sane defaults and an upper cap.
// Invalid or missing values fall back to the defaults rather than erroring, so
// existing callers that pass nothing keep working (bounded to DefaultPageLimit).
func Paginate(r *http.Request) (limit, offset int) {
	limit = DefaultPageLimit
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 {
		limit = v
	}
	if limit > MaxPageLimit {
		limit = MaxPageLimit
	}
	if v, err := strconv.Atoi(r.URL.Query().Get("offset")); err == nil && v > 0 {
		offset = v
	}
	return limit, offset
}
