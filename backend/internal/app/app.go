package app

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	// Shared infrastructure
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

	// Module 6: BFF (Backend-For-Frontend / Unified UX)
	bff "github.com/spacesioberyl/system-v1/internal/bff"
)

type Application struct {
	Router *chi.Mux
	DB     *pgxpool.Pool
	Config *config.Config
	srv    *http.Server

	// requireAuth is built once from the configured secret and shared by every module,
	// so the signing key never travels through the process environment.
	requireAuth func(http.Handler) http.Handler
}

func New(db *pgxpool.Pool, cfg *config.Config) *Application {
	app := &Application{
		Router:      chi.NewRouter(),
		DB:          db,
		Config:      cfg,
		requireAuth: appmiddleware.RequireAuth(cfg.JWTSecret),
	}

	// Chi's built-in middleware.
	// RealIP is deliberately NOT used: the API is directly exposed (no reverse
	// proxy strips forwarded headers), so trusting X-Forwarded-For/X-Real-IP
	// would let a client spoof its address and defeat rate limiting and the
	// attendance geofence. r.RemoteAddr (the socket peer) is the trusted source
	// (backend-bugs #4/#11).
	app.Router.Use(chimiddleware.Logger)
	app.Router.Use(chimiddleware.Recoverer)
	app.Router.Use(appmiddleware.LimitBody) // bound request bodies (backend-bugs #19)
	app.Router.Use(appmiddleware.CORS(cfg.CORSAllowedOrigins))

	// System routes
	app.registerSystemRoutes()

	// Wire all modules
	app.registerIAM()
	app.registerHR()
	app.registerCRM()
	app.registerLogistics()
	app.registerExecution()
	app.registerBFF()

	// Explicit server with timeouts. A bare ListenAndServe is Slowloris-exposed
	// and lets a stalled client pin a goroutine forever (backend-bugs #17).
	// WriteTimeout is generous to accommodate the slowest legitimate endpoints
	// (file upload, PDF generation) — tune with real measurements.
	app.srv = &http.Server{
		Addr:              fmt.Sprintf(":%s", cfg.APIPort),
		Handler:           app.Router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

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
}

// =====================================================
// MODULE WIRING
// =====================================================

func (a *Application) registerIAM() {
	repo := iamRepo.NewIAMRepository(a.DB)
	svc := iamService.NewIAMService(repo, a.Config.JWTSecret, a.Config.AppEnv)
	handler := iamHandler.NewIAMHandler(svc)
	iam.RegisterRoutes(a.Router, a.requireAuth, handler)
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

	hr.RegisterRoutes(a.Router, a.requireAuth, attHandler, expHandler, leaveHandler)

	// The attendance geofence is silently disabled when OFFICE_IP accepts every
	// address; make that loud rather than a silent security hole (backend-bugs #11).
	if a.Config.OfficeIP == "" || a.Config.OfficeIP == "0.0.0.0" {
		logger.Log.Warn("Attendance geofence DISABLED: OFFICE_IP accepts all addresses", "office_ip", a.Config.OfficeIP)
	}
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

	crm.RegisterRoutes(a.Router, a.requireAuth, leadHandler, followUpHandler, quotationHandler, complaintHandler)
	logger.Log.Info("Module 3 (CRM + Client Support) registered")
}

func (a *Application) registerLogistics() {
	repo := logRepo.NewLogisticsRepository(a.DB)
	svc := logService.NewLogisticsService(repo)
	handler := logHandler.NewLogisticsHandler(svc)
	logisticsModule.RegisterRoutes(a.Router, a.requireAuth, handler)
	logger.Log.Info("Module 4 (Logistics) registered")
}

func (a *Application) registerExecution() {
	repo := execRepo.NewExecutionRepository(a.DB)
	handler := execHandler.NewExecutionHandler(repo)

	// Contractor Management sub-module
	contractorRepo := execRepo.NewContractorRepository(a.DB)
	contractorSvc := execService.NewContractorService(contractorRepo)
	contractorHandler := execHandler.NewContractorHandler(contractorSvc)

	executionModule.RegisterRoutes(a.Router, a.requireAuth, handler, contractorHandler)
	logger.Log.Info("Module 5 (Execution + Contractor Management) registered")
}

func (a *Application) registerBFF() {
	svc := bff.NewBFFService(a.DB)
	handler := bff.NewBFFHandler(svc)
	bff.RegisterRoutes(a.Router, a.requireAuth, handler)
	logger.Log.Info("Module 6 (BFF / Unified UX) registered")
}

// Start blocks serving requests until the server is shut down. It returns
// http.ErrServerClosed after a graceful Shutdown, which the caller treats as a
// clean exit.
func (a *Application) Start() error {
	logger.Log.Info("Starting Spacesio Beryl API Server", "address", a.srv.Addr)
	return a.srv.ListenAndServe()
}

// Shutdown drains in-flight requests within ctx's deadline, then stops the
// server so main's deferred pool/broker closes can run (backend-bugs #17).
func (a *Application) Shutdown(ctx context.Context) error {
	logger.Log.Info("Shutting down API server, draining in-flight requests...")
	return a.srv.Shutdown(ctx)
}
