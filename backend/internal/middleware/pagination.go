package middleware

import (
	"net/http"
	"strconv"
)

// Pagination defaults. List endpoints apply these so a query never scans and
// returns an entire table unbounded (backend-bugs #30).
const (
	DefaultPageLimit = 10
	MaxPageLimit     = 200
)

// Page is the envelope every paginated list endpoint returns, so a client can
// tell how many records exist beyond the current window.
type Page[T any] struct {
	Items  []T `json:"items"`
	Total  int `json:"total"`
	Limit  int `json:"limit"`
	Offset int `json:"offset"`
}

// NewPage wraps a result window. A nil slice is normalised to an empty one so
// the JSON is always "items": [] rather than "items": null.
func NewPage[T any](items []T, total, limit, offset int) Page[T] {
	if items == nil {
		items = []T{}
	}
	return Page[T]{Items: items, Total: total, Limit: limit, Offset: offset}
}

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
