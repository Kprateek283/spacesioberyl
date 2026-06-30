package bff

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

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

	// NOTE: Hardcoding uploaderID to 1 (Admin/QA) since JWT middleware is temporarily bypassed for BFF.
	uploaderID := 1 

	doc, err := h.service.UploadProjectDocument(ctx, projectID, uploaderID, documentType, fileHeader.Filename, file, fileHeader.Size, contentType)
	if err != nil {
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
	
	// NOTE: Hardcoding userID to 1 since JWT is temporarily bypassed
	userID := 1

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
	
	// NOTE: Hardcoding userID to 1 since JWT is temporarily bypassed
	userID := 1

	resp, err := h.service.GetPersonalTimeline(ctx, userID)
	if err != nil {
		logger.Log.Error("Failed to fetch personal timeline", "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// RegisterRoutes registers the unified BFF endpoints
func RegisterRoutes(r chi.Router, h *BFFHandler) {
	// Note: Authentication middleware (JWT verification) should ideally wrap these routes 
	// based on the system's global middleware configuration.
	r.Route("/api/v1/projects", func(r chi.Router) {
		r.Get("/pipeline", h.GetPipeline)
		r.Get("/{id}/details", h.GetProjectDetails)
		r.Post("/{id}/docs", h.UploadProjectDocument)
	})

	r.Route("/api/v1/workspace", func(r chi.Router) {
		r.Get("/action-items", h.GetActionItems)
		r.Get("/personal-timeline", h.GetPersonalTimeline)
	})
}
