package bff

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/logger"
	"github.com/spacesioberyl/system-v1/internal/middleware"
	"github.com/spacesioberyl/system-v1/internal/storage"
)

// callerID returns the authenticated user's ID from the request context.
// ok is false when RequireAuth did not run or the claims are the wrong type.
func callerID(r *http.Request) (int, bool) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		return 0, false
	}
	return claims.UserID, true
}

type BFFHandler struct {
	service *BFFService
}

func NewBFFHandler(svc *BFFService) *BFFHandler {
	return &BFFHandler{service: svc}
}

// GetPipeline handles GET /api/v1/projects/pipeline
func (h *BFFHandler) GetPipeline(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	resp, err := h.service.GetPipeline(ctx)
	if err != nil {
		logger.Log.Error("Failed to fetch pipeline dashboard", "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		logger.Log.Error("Failed to encode pipeline response", "error", err)
	}
}

// GetProjectDetails handles GET /api/v1/projects/{id}/details
func (h *BFFHandler) GetProjectDetails(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	projectID, err := strconv.Atoi(idStr)
	if err != nil {
		logger.Log.Error("Invalid project ID format", "id", idStr)
		http.Error(w, "Invalid project ID", http.StatusBadRequest)
		return
	}

	resp, err := h.service.GetProjectDetails(ctx, projectID)
	if err != nil {
		logger.Log.Error("Failed to fetch project details", "error", err, "projectID", projectID)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		logger.Log.Error("Failed to encode project details response", "error", err)
	}
}

// UploadProjectDocument handles POST /api/v1/projects/{id}/docs
func (h *BFFHandler) UploadProjectDocument(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idStr := chi.URLParam(r, "id")
	projectID, err := strconv.Atoi(idStr)
	if err != nil {
		logger.Log.Error("Invalid project ID format", "id", idStr)
		http.Error(w, "Invalid project ID", http.StatusBadRequest)
		return
	}

	// Limit upload size to 10 MB
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		logger.Log.Error("Failed to parse multipart form", "error", err)
		http.Error(w, "Payload too large or invalid format", http.StatusBadRequest)
		return
	}

	file, fileHeader, err := r.FormFile("file")
	if err != nil {
		logger.Log.Error("Failed to retrieve file from form", "error", err)
		http.Error(w, "File is required in the 'file' field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	documentType := r.FormValue("document_type")
	if documentType == "" {
		documentType = "other" // fallback
	}

	contentType := fileHeader.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	uploaderID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	doc, err := h.service.UploadProjectDocument(ctx, projectID, uploaderID, documentType, fileHeader.Filename, file, fileHeader.Size, contentType)
	if err != nil {
		if errors.Is(err, ErrUnsupportedFileType) {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		logger.Log.Error("Failed to upload project document", "error", err, "projectID", projectID)
		http.Error(w, "Failed to upload document", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(doc); err != nil {
		logger.Log.Error("Failed to encode project document response", "error", err)
	}
}

// GetActionItems handles GET /api/v1/workspace/action-items
func (h *BFFHandler) GetActionItems(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	resp, err := h.service.GetActionItems(ctx, userID)
	if err != nil {
		logger.Log.Error("Failed to fetch action items", "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// GetPersonalTimeline handles GET /api/v1/workspace/personal-timeline
func (h *BFFHandler) GetPersonalTimeline(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	resp, err := h.service.GetPersonalTimeline(ctx, userID)
	if err != nil {
		logger.Log.Error("Failed to fetch personal timeline", "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// ServeFile streams a stored object out of the now-private bucket to an
// authenticated caller. It is the only read path for uploaded files, replacing
// the public bucket URLs (backend-bugs #12).
func (h *BFFHandler) ServeFile(w http.ResponseWriter, r *http.Request) {
	if _, ok := callerID(r); !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	key := chi.URLParam(r, "*")
	if key == "" {
		http.Error(w, "File key is required", http.StatusBadRequest)
		return
	}

	obj, contentType, err := storage.DownloadFile(r.Context(), key)
	if err != nil {
		logger.Log.Error("Failed to fetch file from storage", "error", err, "key", key)
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}
	defer obj.Close()

	w.Header().Set("Content-Type", contentType)
	if _, err := io.Copy(w, obj); err != nil {
		logger.Log.Error("Failed to stream file", "error", err, "key", key)
	}
}

// RegisterRoutes registers the unified BFF endpoints
func RegisterRoutes(r chi.Router, requireAuth func(http.Handler) http.Handler, h *BFFHandler) {
	r.Route("/api/v1/projects", func(r chi.Router) {
		// ALL project routes require authentication
		r.Use(requireAuth)

		r.Get("/pipeline", h.GetPipeline)
		r.Get("/{id}/details", h.GetProjectDetails)
		r.Post("/{id}/docs", h.UploadProjectDocument)
	})

	r.Route("/api/v1/workspace", func(r chi.Router) {
		// ALL workspace routes require authentication
		r.Use(requireAuth)

		r.Get("/action-items", h.GetActionItems)
		r.Get("/personal-timeline", h.GetPersonalTimeline)
	})

	// Authenticated file access for the private bucket (backend-bugs #12).
	r.Route("/api/v1/files", func(r chi.Router) {
		r.Use(requireAuth)
		r.Get("/*", h.ServeFile)
	})
}
