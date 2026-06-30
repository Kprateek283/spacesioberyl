#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Cleaning up backend state for a fresh test run..."
# We clear the PIN hashes so the authentication tests can verify the initial setup flows
docker exec spacesio-postgres-1 psql -U admin -d erp_v1 -c "UPDATE users SET pin_hash = NULL;" > /dev/null 2>&1 || echo "Warning: Could not connect to Postgres to clear PINs."

TESTS=(
    "integration_test/qa_auth_test.dart"
    "integration_test/qa_admin_dashboard_test.dart"
    "integration_test/qa_staff_home_test.dart"
    "integration_test/flow1_test.dart"
    "integration_test/flow2_logistics_test.dart"
    "integration_test/flow3_execution_test.dart"
)

echo "Starting E2E Integration Test Suite..."
echo ""

for test_file in "${TESTS[@]}"; do
    echo "============================================="
    echo "Running: $test_file"
    echo "============================================="
    
    # Run the flutter test on the Linux desktop target
    if flutter test -d linux "$test_file"; then
        echo "✅ SUCCESS: $test_file"
    else
        echo "❌ FAILED: $test_file"
        exit 1 # Exit on first failure, remove this if you want it to run all tests regardless
    fi
    echo ""
done

echo "🎉 All tests completed successfully!"
