package bff

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	crmRepo "github.com/spacesioberyl/system-v1/internal/crm/repository"
	execRepo "github.com/spacesioberyl/system-v1/internal/execution/repository"
	logRepo "github.com/spacesioberyl/system-v1/internal/logistics/repository"
)

// newTestService wires the BFF with real repositories against the test pool.
func newTestService(pool *pgxpool.Pool) *BFFService {
	return NewBFFService(pool,
		crmRepo.NewLeadRepository(pool),
		crmRepo.NewQuotationRepository(pool),
		logRepo.NewLogisticsRepository(pool),
		execRepo.NewExecutionRepository(pool),
	)
}

// These tests run the real BFF queries against a migrated and seeded database,
// proving the ghost-mode cash filter is actually wired into each call site —
// the unit tests in ghost_mode_test.go only cover the helper in isolation.
//
// They depend on db/seeds/dev_seed.sql, specifically:
//   - lead 2 "Kalyani Residency" has exactly one approved quotation, and it is cash
//   - order 2 (lead 2) is a cash order
//
// Set TEST_DATABASE_URL to point elsewhere; skipped when no database answers.
const seedCashLeadID = 2

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()

	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://admin:securepassword@localhost:5434/erp_v1?sslmode=disable"
	}

	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Skipf("no test database configured: %v", err)
	}
	if err := pool.Ping(context.Background()); err != nil {
		pool.Close()
		t.Skipf("test database unreachable, run migrations and db/seeds/dev_seed.sql: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
}

// findCard locates a pipeline card across every column of the board.
func findCard(resp *PipelineResponse, leadID int) *ProjectCard {
	for _, column := range [][]ProjectCard{resp.Leads, resp.Procurement, resp.Execution, resp.Completed} {
		for i := range column {
			if column[i].ID == leadID {
				return &column[i]
			}
		}
	}
	return nil
}

// TestPipelineHidesCashValue is the end-to-end version of the contract: the
// cash-only project reports zero value to a caller without ghost mode, and its
// real value to one with it.
func TestPipelineHidesCashValue(t *testing.T) {
	svc := newTestService(testPool(t))

	withoutGhost, err := svc.GetPipeline(ghostCtx("staff", false))
	if err != nil {
		t.Fatalf("GetPipeline without ghost mode: %v", err)
	}
	card := findCard(withoutGhost, seedCashLeadID)
	if card == nil {
		t.Fatalf("lead %d missing from the pipeline; is db/seeds/dev_seed.sql applied?", seedCashLeadID)
	}
	if card.Value != 0 {
		t.Errorf("%s reports value %d without ghost mode, want 0 — a cash quotation is leaking", card.ClientName, card.Value)
	}

	withGhost, err := svc.GetPipeline(ghostCtx("super_admin", true))
	if err != nil {
		t.Fatalf("GetPipeline with ghost mode: %v", err)
	}
	card = findCard(withGhost, seedCashLeadID)
	if card == nil {
		t.Fatalf("lead %d missing from the ghost-mode pipeline", seedCashLeadID)
	}
	if card.Value == 0 {
		t.Errorf("%s reports 0 with ghost mode, want the cash quotation total — the filter is inverted", card.ClientName)
	}
}

// TestProjectDetailsHidesCash covers the other two filtered call sites in
// GetProjectDetails: the quotation list and the order.
func TestProjectDetailsHidesCash(t *testing.T) {
	svc := newTestService(testPool(t))

	withoutGhost, err := svc.GetProjectDetails(ghostCtx("staff", false), seedCashLeadID)
	if err != nil {
		t.Fatalf("GetProjectDetails without ghost mode: %v", err)
	}
	for _, q := range withoutGhost.Quotes {
		if q.PaymentTermType == "cash" {
			t.Errorf("quotation %d is cash but was returned without ghost mode", q.ID)
		}
	}
	if o := withoutGhost.Order; o != nil && o.PaymentTermType != nil && *o.PaymentTermType == "cash" {
		t.Errorf("order %d is cash but was returned without ghost mode", withoutGhost.Order.ID)
	}

	withGhost, err := svc.GetProjectDetails(ghostCtx("super_admin", true), seedCashLeadID)
	if err != nil {
		t.Fatalf("GetProjectDetails with ghost mode: %v", err)
	}

	var sawCashQuote bool
	for _, q := range withGhost.Quotes {
		if q.PaymentTermType == "cash" {
			sawCashQuote = true
		}
	}
	if !sawCashQuote {
		t.Error("ghost mode did not reveal the seeded cash quotation on lead 2 — the filter is inverted or the seed drifted")
	}
	if withGhost.Order == nil {
		t.Error("ghost mode did not reveal the seeded cash order on lead 2")
	}
}
