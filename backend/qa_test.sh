#!/bin/bash
# Spacesio Beryl QA Backend Test Script
BASE="http://localhost:8080/api/v1"
PASS=0
FAIL=0
ERRORS=""

test_endpoint() {
  local desc="$1" method="$2" url="$3" data="$4" expected_code="$5" token="$6"
  
  local args=(-s -o /tmp/qa_response.json -w "%{http_code}")
  args+=(-X "$method")
  if [ -n "$token" ]; then
    args+=(-H "Authorization: Bearer $token")
  fi
  args+=(-H "Content-Type: application/json")
  if [ -n "$data" ]; then
    args+=(-d "$data")
  fi
  args+=("$url")
  
  local code=$(curl "${args[@]}")
  local body=$(cat /tmp/qa_response.json 2>/dev/null)
  
  if [ "$code" = "$expected_code" ]; then
    PASS=$((PASS+1))
    echo "PASS [$code] $desc"
  else
    FAIL=$((FAIL+1))
    echo "FAIL [$code expected $expected_code] $desc"
    echo "  Response: $body"
    ERRORS="$ERRORS\nFAIL: $desc [got $code expected $expected_code] -- $body"
  fi
  echo "$body" > /tmp/qa_last_response.json
}

echo "=========================================="
echo "   SPACESIO BERYL QA - BACKEND TESTS"
echo "=========================================="

# 1. HEALTH CHECK
echo ""
echo "--- 1. System Health ---"
test_endpoint "Health Check" GET "http://localhost:8080/ping" "" "200"

# 2. IAM - Login
echo ""
echo "--- 2. IAM Module ---"
test_endpoint "Login (Admin)" POST "$BASE/login" '{"email":"admin@gmail.com","password":"admin123"}' "200"
ADMIN_TOKEN=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
ADMIN_REFRESH=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null)
REQUIRES_PIN=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('requires_pin_setup',''))" 2>/dev/null)
echo "  Token obtained: $([ -n "$ADMIN_TOKEN" ] && echo "YES" || echo "NO")"
echo "  Requires PIN Setup: $REQUIRES_PIN"

test_endpoint "Login (Staff)" POST "$BASE/login" '{"email":"staff@gmail.com","password":"staff123"}' "200"
STAFF_TOKEN=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

test_endpoint "Login (Invalid Creds)" POST "$BASE/login" '{"email":"bad@gmail.com","password":"wrong"}' "401"
test_endpoint "Login (Missing Fields)" POST "$BASE/login" '{}' "401"

# Get Me
test_endpoint "Get Me (Admin)" GET "$BASE/users/me" "" "200" "$ADMIN_TOKEN"
test_endpoint "Get Me (No Auth)" GET "$BASE/users/me" "" "401"

# List Users (Admin only)
test_endpoint "List Users (Admin)" GET "$BASE/users" "" "200" "$ADMIN_TOKEN"
test_endpoint "List Users (Staff - Forbidden)" GET "$BASE/users" "" "403" "$STAFF_TOKEN"

# Create User
test_endpoint "Create User" POST "$BASE/users" '{"name":"QA Test User","email":"qatest@test.com","password":"password123","role":"staff","department":"operations"}' "201" "$ADMIN_TOKEN"
test_endpoint "Create Duplicate User" POST "$BASE/users" '{"name":"QA Test User","email":"qatest@test.com","password":"password123","role":"staff","department":"operations"}' "409" "$ADMIN_TOKEN"
test_endpoint "Create User (Staff - Forbidden)" POST "$BASE/users" '{"name":"Test","email":"test2@test.com","password":"password123","role":"staff","department":"operations"}' "403" "$STAFF_TOKEN"

# Token Refresh
test_endpoint "Refresh Token" POST "$BASE/refresh" "{\"refresh_token\":\"$ADMIN_REFRESH\"}" "200"
test_endpoint "Refresh Token (Invalid)" POST "$BASE/refresh" '{"refresh_token":"bad_token"}' "401"

# Change Password
test_endpoint "Change Password (Wrong Old)" PATCH "$BASE/users/me/password" '{"old_password":"wrongold","new_password":"newpass123"}' "400" "$ADMIN_TOKEN"

# Forgot Password
test_endpoint "Forgot Password" POST "$BASE/password/forgot" '{"email":"admin@gmail.com"}' "200"
test_endpoint "Forgot Password (Non-existent)" POST "$BASE/password/forgot" '{"email":"nobody@test.com"}' "200"

# PIN Setup
test_endpoint "Setup PINs (Admin)" POST "$BASE/iam/setup-pins" '{"normal_pin":"1234","confirm_normal_pin":"1234","high_security_pin":"567890","confirm_high_security_pin":"567890"}' "200" "$ADMIN_TOKEN"
test_endpoint "Setup PINs (Staff - Forbidden)" POST "$BASE/iam/setup-pins" '{"normal_pin":"1234","confirm_normal_pin":"1234","high_security_pin":"567890","confirm_high_security_pin":"567890"}' "403" "$STAFF_TOKEN"
test_endpoint "Setup PINs (Mismatch)" POST "$BASE/iam/setup-pins" '{"normal_pin":"1234","confirm_normal_pin":"9999","high_security_pin":"567890","confirm_high_security_pin":"567890"}' "400" "$ADMIN_TOKEN"
test_endpoint "Setup PINs (Same PINs)" POST "$BASE/iam/setup-pins" '{"normal_pin":"1234","confirm_normal_pin":"1234","high_security_pin":"1234","confirm_high_security_pin":"1234"}' "400" "$ADMIN_TOKEN"

# Verify PIN
test_endpoint "Verify Normal PIN" POST "$BASE/iam/verify-pin" '{"pin":"1234"}' "200" "$ADMIN_TOKEN"
NORMAL_TOKEN=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
GHOST_MODE=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('ghost_mode',''))" 2>/dev/null)
echo "  Ghost Mode: $GHOST_MODE (expected: False)"

test_endpoint "Verify Ghost PIN" POST "$BASE/iam/verify-pin" '{"pin":"567890"}' "200" "$ADMIN_TOKEN"
GHOST_TOKEN=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
GHOST_MODE2=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('ghost_mode',''))" 2>/dev/null)
echo "  Ghost Mode: $GHOST_MODE2 (expected: True)"

test_endpoint "Verify Invalid PIN" POST "$BASE/iam/verify-pin" '{"pin":"9999"}' "401" "$ADMIN_TOKEN"

# Logout
test_endpoint "Logout" POST "$BASE/logout" "" "200" "$ADMIN_TOKEN"

# Re-login for further tests
curl -s -X POST "$BASE/login" -H "Content-Type: application/json" -d '{"email":"admin@gmail.com","password":"admin123"}' > /tmp/qa_response.json
ADMIN_TOKEN=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

# 3. HR MODULE
echo ""
echo "--- 3. HR Module ---"
# Attendance
test_endpoint "Check In" POST "$BASE/hr/attendance/check-in" '{}' "200" "$ADMIN_TOKEN"
test_endpoint "Check In (Duplicate)" POST "$BASE/hr/attendance/check-in" '{}' "400" "$ADMIN_TOKEN"
test_endpoint "Check Out" POST "$BASE/hr/attendance/check-out" "" "200" "$ADMIN_TOKEN"
test_endpoint "My Attendance" GET "$BASE/hr/attendance/me" "" "200" "$ADMIN_TOKEN"
test_endpoint "All Attendance (Admin)" GET "$BASE/hr/attendance" "" "200" "$ADMIN_TOKEN"
test_endpoint "List Overrides (Admin)" GET "$BASE/hr/attendance/overrides" "" "200" "$ADMIN_TOKEN"

# Expenses
test_endpoint "Create Expense" POST "$BASE/hr/expenses" '{"amount":500.0,"person_paid":"Test Person","context":"Test expense","expense_date":"2026-06-28"}' "201" "$ADMIN_TOKEN"
test_endpoint "List Expenses (Admin)" GET "$BASE/hr/expenses" "" "200" "$ADMIN_TOKEN"

# Leaves
test_endpoint "Request Leave" POST "$BASE/hr/leaves" '{"leave_type":"casual_leave","start_date":"2026-07-01","end_date":"2026-07-03","reason":"QA Testing"}' "201" "$ADMIN_TOKEN"
LEAVE_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
echo "  Leave ID: $LEAVE_ID"

test_endpoint "My Leaves" GET "$BASE/hr/leaves/me" "" "200" "$ADMIN_TOKEN"
test_endpoint "Edit Leave (Pending)" PATCH "$BASE/hr/leaves/$LEAVE_ID" '{"reason":"Updated QA reason"}' "200" "$ADMIN_TOKEN"
test_endpoint "All Leaves (Admin)" GET "$BASE/hr/leaves" "" "200" "$ADMIN_TOKEN"
test_endpoint "All Leaves (Admin, status filter)" GET "$BASE/hr/leaves?status=pending" "" "200" "$ADMIN_TOKEN"
test_endpoint "Admin Edit Leave" PATCH "$BASE/hr/leaves/$LEAVE_ID/admin-edit" '{"leave_type":"sick_leave"}' "200" "$ADMIN_TOKEN"
test_endpoint "Approve Leave" PATCH "$BASE/hr/leaves/$LEAVE_ID/status" '{"status":"approved","admin_remarks":"QA approved"}' "200" "$ADMIN_TOKEN"
test_endpoint "Edit Leave (Approved - Should Fail)" PATCH "$BASE/hr/leaves/$LEAVE_ID" '{"reason":"Should fail"}' "400" "$ADMIN_TOKEN"

# Request another leave to test cancel
test_endpoint "Request Leave (for cancel)" POST "$BASE/hr/leaves" '{"leave_type":"unpaid_leave","start_date":"2026-08-01","end_date":"2026-08-02","reason":"Cancel test"}' "201" "$ADMIN_TOKEN"
CANCEL_LEAVE_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
test_endpoint "Cancel Leave" PATCH "$BASE/hr/leaves/$CANCEL_LEAVE_ID/cancel" "" "200" "$ADMIN_TOKEN"

test_endpoint "Leave (Invalid Type)" POST "$BASE/hr/leaves" '{"leave_type":"invalid_type","start_date":"2026-07-01","end_date":"2026-07-03","reason":"Bad type"}' "400" "$ADMIN_TOKEN"
test_endpoint "Leave (Bad Dates)" POST "$BASE/hr/leaves" '{"leave_type":"casual_leave","start_date":"2026-07-05","end_date":"2026-07-03","reason":"Bad dates"}' "400" "$ADMIN_TOKEN"

# 4. CRM MODULE
echo ""
echo "--- 4. CRM Module ---"
# Leads
test_endpoint "Create Lead" POST "$BASE/crm/leads" '{"client_name":"QA Lead","client_phone":"+919876543210","client_email":"qa@test.com","source":"walk_in"}' "201" "$ADMIN_TOKEN"
LEAD_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
echo "  Lead ID: $LEAD_ID"

test_endpoint "List Leads" GET "$BASE/crm/leads" "" "200" "$ADMIN_TOKEN"
test_endpoint "Get Lead" GET "$BASE/crm/leads/$LEAD_ID" "" "200" "$ADMIN_TOKEN"
test_endpoint "Update Lead Status" PATCH "$BASE/crm/leads/$LEAD_ID/status" '{"status":"first_call"}' "200" "$ADMIN_TOKEN"
test_endpoint "Assign Lead" PATCH "$BASE/crm/leads/$LEAD_ID/assign" '{"assigned_to":1}' "200" "$ADMIN_TOKEN"

# Follow-ups
test_endpoint "Create Follow-up" POST "$BASE/crm/followups" '{"lead_id":'$LEAD_ID',"scheduled_for":"2026-07-01T10:00:00Z","notes":"QA follow-up"}' "201" "$ADMIN_TOKEN"
FU_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
test_endpoint "My Follow-up Queue" GET "$BASE/crm/followups/my-queue" "" "200" "$ADMIN_TOKEN"
test_endpoint "Complete Follow-up" PATCH "$BASE/crm/followups/$FU_ID/complete" '{"outcome_notes":"QA completed"}' "200" "$ADMIN_TOKEN"

# Quotations
test_endpoint "Create Quotation" POST "$BASE/crm/leads/$LEAD_ID/quotations" '{"payment_term_type":"100_advance","tax_rate":18,"line_items":[{"item_name":"QA Item","description":"Test","quantity":1,"unit_price":10000}]}' "201" "$ADMIN_TOKEN"
QUOTE_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
echo "  Quotation ID: $QUOTE_ID"

test_endpoint "List Quotations" GET "$BASE/crm/leads/$LEAD_ID/quotations" "" "200" "$ADMIN_TOKEN"
test_endpoint "Quotation (Empty Items)" POST "$BASE/crm/leads/$LEAD_ID/quotations" '{"payment_term_type":"100_advance","tax_rate":18,"line_items":[]}' "400" "$ADMIN_TOKEN"

test_endpoint "Approve Quotation (triggers Order)" PATCH "$BASE/crm/quotations/$QUOTE_ID/status" '{"status":"client_approved"}' "200" "$ADMIN_TOKEN"

# Wait for worker to create order
sleep 2

# Complaints
test_endpoint "Create Complaint (Lead)" POST "$BASE/crm/complaints" '{"title":"QA Complaint","description":"Test complaint","priority":"high","lead_id":'$LEAD_ID',"client_name":"QA Lead","client_phone":"+919876543210"}' "201" "$ADMIN_TOKEN"
COMPLAINT_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
test_endpoint "List Complaints" GET "$BASE/crm/complaints" "" "200" "$ADMIN_TOKEN"
test_endpoint "Assign Complaint" PATCH "$BASE/crm/complaints/$COMPLAINT_ID/assign" '{"assigned_to":1}' "200" "$ADMIN_TOKEN"
test_endpoint "Resolve Complaint" PATCH "$BASE/crm/complaints/$COMPLAINT_ID/status" '{"status":"resolved"}' "200" "$ADMIN_TOKEN"

# Mark lead as lost (edge case)
test_endpoint "Create Lead (for lost)" POST "$BASE/crm/leads" '{"client_name":"Lost Lead","client_phone":"+919000000000","source":"online"}' "201" "$ADMIN_TOKEN"
LOST_LEAD_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
test_endpoint "Mark Lead Lost (no reason)" PATCH "$BASE/crm/leads/$LOST_LEAD_ID/status" '{"status":"lost"}' "400" "$ADMIN_TOKEN"
test_endpoint "Mark Lead Lost (with reason)" PATCH "$BASE/crm/leads/$LOST_LEAD_ID/status" '{"status":"lost","lost_reason":"Budget constraints"}' "200" "$ADMIN_TOKEN"

# 5. LOGISTICS MODULE
echo ""
echo "--- 5. Logistics Module ---"
# Vendors
test_endpoint "Create Vendor" POST "$BASE/logistics/vendors" '{"company_name":"QA Plywood","phone":"+911234567890","contact_person":"QA Contact","default_payment_mode":"bank_transfer"}' "201" "$ADMIN_TOKEN"
VENDOR_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
test_endpoint "List Vendors" GET "$BASE/logistics/vendors" "" "200" "$ADMIN_TOKEN"
test_endpoint "Get Vendor" GET "$BASE/logistics/vendors/$VENDOR_ID" "" "200" "$ADMIN_TOKEN"

# Orders (auto-created from quotation approval)
test_endpoint "List Orders" GET "$BASE/logistics/orders" "" "200" "$ADMIN_TOKEN"
ORDER_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if isinstance(d,list) and len(d)>0 else '')" 2>/dev/null)
echo "  Order ID (from worker): $ORDER_ID"

if [ -n "$ORDER_ID" ] && [ "$ORDER_ID" != "" ]; then
  test_endpoint "Assign Order Manager" PATCH "$BASE/logistics/orders/$ORDER_ID/assign" '{"operations_manager_id":1}' "200" "$ADMIN_TOKEN"
  test_endpoint "Create Purchase Order" POST "$BASE/logistics/orders/$ORDER_ID/pos" '{"vendor_id":'$VENDOR_ID',"total_amount":5000,"expected_delivery_date":"2026-07-15"}' "201" "$ADMIN_TOKEN"
  
  # Dispatches
  test_endpoint "Create Dispatch" POST "$BASE/logistics/dispatches" '{"order_id":'$ORDER_ID',"operations_staff_id":1,"loading_responsibility":"company","transport_driver_name":"QA Driver","transport_vehicle_no":"KA-01-QA01"}' "201" "$ADMIN_TOKEN"
  DISPATCH_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
  test_endpoint "My Dispatches" GET "$BASE/logistics/dispatches/my-tasks" "" "200" "$ADMIN_TOKEN"
  test_endpoint "Log Dispatch Time" PATCH "$BASE/logistics/dispatches/$DISPATCH_ID/log" '{"type":"dispatch","notes":"QA dispatch"}' "200" "$ADMIN_TOKEN"
  test_endpoint "Log Delivery Time" PATCH "$BASE/logistics/dispatches/$DISPATCH_ID/log" '{"type":"delivery","notes":"QA delivery"}' "200" "$ADMIN_TOKEN"
else
  echo "SKIP: Order not found (worker may not have created it yet)"
fi

# 6. EXECUTION MODULE
echo ""
echo "--- 6. Execution Module ---"
# Installers
test_endpoint "Create Installer" POST "$BASE/execution/installers" '{"name":"QA Carpenter","phone":"+919988776655","expertise_area":"modular_kitchen","standard_rate":800,"preferred_payment_mode":"upi"}' "201" "$ADMIN_TOKEN"
INSTALLER_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
test_endpoint "List Installers" GET "$BASE/execution/installers" "" "200" "$ADMIN_TOKEN"

if [ -n "$ORDER_ID" ] && [ "$ORDER_ID" != "" ]; then
  # Create Installation
  test_endpoint "Create Installation" POST "$BASE/execution/orders/$ORDER_ID/installation" '{"technical_manager_id":1}' "201" "$ADMIN_TOKEN"
  JOB_ID=$(cat /tmp/qa_response.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
  echo "  Job ID: $JOB_ID"
  
  test_endpoint "List Jobs" GET "$BASE/execution/jobs" "" "200" "$ADMIN_TOKEN"
  test_endpoint "My Jobs" GET "$BASE/execution/jobs/my-tasks" "" "200" "$ADMIN_TOKEN"
  
  test_endpoint "Assign Installer" PATCH "$BASE/execution/jobs/$JOB_ID/assign" '{"installer_id":'$INSTALLER_ID',"agreed_installer_price":15000,"estimated_completion_date":"2026-07-20"}' "200" "$ADMIN_TOKEN"
  
  # Contractor Management
  test_endpoint "Update Installer Job Status" PATCH "$BASE/execution/contractors/jobs/$JOB_ID/status" '{"status":"accepted"}' "200" "$ADMIN_TOKEN"
  test_endpoint "Installer Check In" POST "$BASE/execution/contractors/jobs/$JOB_ID/check-in" '{"verification_notes":"QA verified on site"}' "201" "$ADMIN_TOKEN"
  test_endpoint "Installer Check Out" POST "$BASE/execution/contractors/jobs/$JOB_ID/check-out" "" "200" "$ADMIN_TOKEN"
  
  # Payments
  test_endpoint "Record Advance Payment" POST "$BASE/execution/contractors/jobs/$JOB_ID/payments" '{"amount":1500,"payment_type":"advance","payment_mode":"upi","transaction_reference":"QA-UPI-001"}' "201" "$ADMIN_TOKEN"
  
  # Financial Lock test: final_discharge BEFORE signoff should fail
  test_endpoint "Final Discharge (Before Signoff - Should Fail)" POST "$BASE/execution/contractors/jobs/$JOB_ID/payments" '{"amount":13500,"payment_type":"final_discharge","payment_mode":"bank_transfer","transaction_reference":"QA-NEFT-001"}' "400" "$ADMIN_TOKEN"
  
  # Sync Updates
  test_endpoint "Sync Site Updates" POST "$BASE/execution/jobs/$JOB_ID/updates/sync" '{"updates":[{"update_time":"2026-07-10T09:00:00Z","notes":"QA work started"}]}' "200" "$ADMIN_TOKEN"
  test_endpoint "Get Site Updates" GET "$BASE/execution/jobs/$JOB_ID/updates" "" "200" "$ADMIN_TOKEN"
  
  # Signoff
  test_endpoint "Client Signoff" PATCH "$BASE/execution/jobs/$JOB_ID/signoff" '{"client_signoff_url":"https://minio/signatures/qa_sig.png","status":"client_approved","client_feedback":"QA approved"}' "200" "$ADMIN_TOKEN"
  
  # Financial Lock test: final_discharge AFTER signoff should succeed
  test_endpoint "Final Discharge (After Signoff)" POST "$BASE/execution/contractors/jobs/$JOB_ID/payments" '{"amount":13500,"payment_type":"final_discharge","payment_mode":"bank_transfer","transaction_reference":"QA-NEFT-002"}' "201" "$ADMIN_TOKEN"
  
  test_endpoint "Get Ledger" GET "$BASE/execution/contractors/jobs/$JOB_ID/ledger" "" "200" "$ADMIN_TOKEN"
else
  echo "SKIP: Execution tests skipped (no order_id)"
fi

# 7. RabbitMQ Test
echo ""
echo "--- 7. Integration Tests ---"
test_endpoint "Test Ping (RabbitMQ)" POST "$BASE/test/ping" "" "200"

echo ""
echo "=========================================="
echo "   QA RESULTS"
echo "=========================================="
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
echo "  TOTAL:  $((PASS+FAIL))"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "--- Failed Tests ---"
  echo -e "$ERRORS"
fi
echo "=========================================="
