package app

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	// Shared infrastructure
	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/cache"
	"github.com/spacesioberyl/system-v1/internal/config"
	"github.com/spacesioberyl/system-v1/internal/logger"
	appmiddleware "github.com/spacesioberyl/system-v1/internal/middleware"

	// Module 1: IAM
	iam "github.com/spacesioberyl/system-v1/internal/iam"
	iamHandler "github.com/spacesioberyl/system-v1/internal/iam/handler"
	iamRepo "github.com/spacesioberyl/system-v1/internal/iam/repository"
	iamService "github.com/spacesioberyl/system-v1/internal/iam/service"

	// Module 2: HR
	hr "github.com/spacesioberyl/system-v1/internal/hr"
	hrHandler "github.com/spacesioberyl/system-v1/internal/hr/handler"
	hrRepo "github.com/spacesioberyl/system-v1/internal/hr/repository"
	hrService "github.com/spacesioberyl/system-v1/internal/hr/service"

	// Module 3: CRM
	crm "github.com/spacesioberyl/system-v1/internal/crm"
	crmHandler "github.com/spacesioberyl/system-v1/internal/crm/handler"
	crmRepo "github.com/spacesioberyl/system-v1/internal/crm/repository"
	crmService "github.com/spacesioberyl/system-v1/internal/crm/service"

	// Module 4: Logistics
	logisticsModule "github.com/spacesioberyl/system-v1/internal/logistics"
	logHandler "github.com/spacesioberyl/system-v1/internal/logistics/handler"
	logRepo "github.com/spacesioberyl/system-v1/internal/logistics/repository"
	logService "github.com/spacesioberyl/system-v1/internal/logistics/service"

	// Module 5: Execution
	executionModule "github.com/spacesioberyl/system-v1/internal/execution"
	execHandler "github.com/spacesioberyl/system-v1/internal/execution/handler"
	execRepo "github.com/spacesioberyl/system-v1/internal/execution/repository"
	execService "github.com/spacesioberyl/system-v1/internal/execution/service"
)

type Application struct {
	Router *chi.Mux
	DB     *pgxpool.Pool
	Config *config.Config
}

func New(db *pgxpool.Pool, cfg *config.Config) *Application {
	app := &Application{
		Router: chi.NewRouter(),
		DB:     db,
		Config: cfg,
	}

	// Chi's built-in middleware
	app.Router.Use(chimiddleware.Logger)
	app.Router.Use(chimiddleware.Recoverer)
	app.Router.Use(chimiddleware.RealIP) // Ensures r.RemoteAddr is the real client IP
	app.Router.Use(appmiddleware.CORS)

	// System routes
	app.registerSystemRoutes()

	// Wire all modules
	app.registerIAM()
	app.registerHR()
	app.registerCRM()
	app.registerLogistics()
	app.registerExecution()

	return app
}

// registerSystemRoutes sets up system/utility endpoints
func (a *Application) registerSystemRoutes() {
	// Health check
	a.Router.Get("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	// Event test (existing POC: publishes to sync_queue)
	a.Router.Post("/api/v1/test/ping", a.handlePing)
}

// handlePing is the existing POC endpoint for testing the RabbitMQ pipeline
func (a *Application) handlePing(w http.ResponseWriter, r *http.Request) {
	err := cache.Client.Set(r.Context(), "last_ping", "event_fired", 0).Err()
	if err != nil {
		logger.Log.Error("Failed to write to Redis", "error", err)
	}

	_ = broker.PublishEvent(r.Context(), broker.QueueSyncQueue, map[string]string{
		"type":    "test_ping",
		"message": "System operational",
	})

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":   "Event published",
		"redis":    "last_ping set",
		"rabbitmq": "sync_queue message sent",
	})
}

// =====================================================
// MODULE WIRING
// =====================================================

func (a *Application) registerIAM() {
	repo := iamRepo.NewIAMRepository(a.DB)
	svc := iamService.NewIAMService(repo, a.Config.JWTSecret)
	handler := iamHandler.NewIAMHandler(svc)
	iam.RegisterRoutes(a.Router, handler)
	logger.Log.Info("Module 1 (IAM + Ghost Mode) registered")
}

func (a *Application) registerHR() {
	attRepo := hrRepo.NewAttendanceRepository(a.DB)
	expRepo := hrRepo.NewExpenseRepository(a.DB)
	leaveRepo := hrRepo.NewLeaveRepository(a.DB)

	attSvc := hrService.NewAttendanceService(attRepo, a.Config.OfficeIP)
	expSvc := hrService.NewExpenseService(expRepo)
	leaveSvc := hrService.NewLeaveService(leaveRepo)

	attHandler := hrHandler.NewAttendanceHandler(attSvc)
	expHandler := hrHandler.NewExpenseHandler(expSvc)
	leaveHandler := hrHandler.NewLeaveHandler(leaveSvc)

	hr.RegisterRoutes(a.Router, attHandler, expHandler, leaveHandler)
	logger.Log.Info("Module 2 (HR + Leave Management) registered")
}

func (a *Application) registerCRM() {
	leadRepo := crmRepo.NewLeadRepository(a.DB)
	followUpRepo := crmRepo.NewFollowUpRepository(a.DB)
	quotationRepo := crmRepo.NewQuotationRepository(a.DB)
	complaintRepo := crmRepo.NewComplaintRepository(a.DB)

	leadSvc := crmService.NewLeadService(leadRepo, followUpRepo)
	followUpSvc := crmService.NewFollowUpService(followUpRepo)
	quotationSvc := crmService.NewQuotationService(quotationRepo)
	complaintSvc := crmService.NewComplaintService(complaintRepo)

	leadHandler := crmHandler.NewLeadHandler(leadSvc)
	followUpHandler := crmHandler.NewFollowUpHandler(followUpSvc)
	quotationHandler := crmHandler.NewQuotationHandler(quotationSvc)
	complaintHandler := crmHandler.NewComplaintHandler(complaintSvc)

	crm.RegisterRoutes(a.Router, leadHandler, followUpHandler, quotationHandler, complaintHandler)
	logger.Log.Info("Module 3 (CRM + Client Support) registered")
}

func (a *Application) registerLogistics() {
	repo := logRepo.NewLogisticsRepository(a.DB)
	svc := logService.NewLogisticsService(repo)
	handler := logHandler.NewLogisticsHandler(svc)
	logisticsModule.RegisterRoutes(a.Router, handler)
	logger.Log.Info("Module 4 (Logistics) registered")
}

func (a *Application) registerExecution() {
	repo := execRepo.NewExecutionRepository(a.DB)
	handler := execHandler.NewExecutionHandler(repo)

	// Contractor Management sub-module
	contractorRepo := execRepo.NewContractorRepository(a.DB)
	contractorSvc := execService.NewContractorService(contractorRepo)
	contractorHandler := execHandler.NewContractorHandler(contractorSvc)

	executionModule.RegisterRoutes(a.Router, handler, contractorHandler)
	logger.Log.Info("Module 5 (Execution + Contractor Management) registered")
}

func (a *Application) Start() error {
	addr := fmt.Sprintf(":%s", a.Config.APIPort)
	logger.Log.Info("Starting Spacesio Beryl API Server", "address", addr)
	return http.ListenAndServe(addr, a.Router)
}
