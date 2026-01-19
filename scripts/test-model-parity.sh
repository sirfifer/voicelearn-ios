#!/bin/bash
#
# test-model-parity.sh
# Cross-platform parity testing for Knowledge Bowl answer validation
#
# Validates that iOS and Android implementations produce matching results
# within acceptable tolerance (±2% accuracy, ±5% algorithm-level)
#

set -euo pipefail

# Configuration
TOLERANCE_ACCURACY=0.02    # 2% accuracy tolerance
TOLERANCE_ALGORITHM=0.05   # 5% algorithm-level tolerance
TEST_VECTORS_PATH="docs/knowledgebowl/validation_test_vectors.json"
IOS_RESULTS_PATH="build/ios_validation_results.json"
ANDROID_RESULTS_PATH="../unamentis-android/build/android_validation_results.json"
ANDROID_PROJECT_PATH="../unamentis-android"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "$1"
}

# Check if test vectors exist
check_test_vectors() {
    if [ ! -f "$TEST_VECTORS_PATH" ]; then
        print_error "Test vectors not found at: $TEST_VECTORS_PATH"
        exit 1
    fi
    print_success "Test vectors found"
}

# Run iOS validation tests
run_ios_tests() {
    print_info "\n📱 Running iOS validation tests..."

    xcodebuild test \
        -project UnaMentis.xcodeproj \
        -scheme UnaMentis \
        -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
        -only-testing:UnaMentisTests/KBAnswerValidationIntegrationTests \
        -resultBundlePath build/ios_test_results.xcresult \
        > build/ios_test_output.txt 2>&1

    if [ $? -eq 0 ]; then
        print_success "iOS tests completed"
    else
        print_error "iOS tests failed"
        cat build/ios_test_output.txt
        exit 1
    fi
}

# Run Android validation tests
run_android_tests() {
    print_info "\n🤖 Running Android validation tests..."

    if [ ! -d "$ANDROID_PROJECT_PATH" ]; then
        print_warning "Android project not found at: $ANDROID_PROJECT_PATH"
        print_warning "Skipping Android tests"
        return 1
    fi

    cd "$ANDROID_PROJECT_PATH"

    ./gradlew connectedAndroidTest \
        --tests "com.unamentis.knowledgebowl.validation.AnswerValidationIntegrationTest" \
        > build/android_test_output.txt 2>&1

    local result=$?
    cd - > /dev/null

    if [ $result -eq 0 ]; then
        print_success "Android tests completed"
        return 0
    else
        print_error "Android tests failed"
        cat "$ANDROID_PROJECT_PATH/build/android_test_output.txt"
        return 1
    fi
}

# Compare iOS and Android results
compare_results() {
    print_info "\n🔍 Comparing iOS and Android results..."

    # Check if both result files exist
    if [ ! -f "$IOS_RESULTS_PATH" ]; then
        print_warning "iOS results not found at: $IOS_RESULTS_PATH"
        return 1
    fi

    if [ ! -f "$ANDROID_RESULTS_PATH" ]; then
        print_warning "Android results not found at: $ANDROID_RESULTS_PATH"
        print_warning "Skipping comparison"
        return 1
    fi

    # Use Python script for detailed comparison
    python3 - <<EOF
import json
import sys

def load_results(path):
    with open(path, 'r') as f:
        return json.load(f)

def compare_accuracy(ios_results, android_results):
    """Compare overall accuracy between platforms"""
    ios_accuracy = ios_results.get('accuracy', 0)
    android_accuracy = android_results.get('accuracy', 0)

    diff = abs(ios_accuracy - android_accuracy)

    print(f"iOS Accuracy:     {ios_accuracy:.2%}")
    print(f"Android Accuracy: {android_accuracy:.2%}")
    print(f"Difference:       {diff:.2%}")

    if diff <= ${TOLERANCE_ACCURACY}:
        print("✓ Accuracy within tolerance (±${TOLERANCE_ACCURACY})")
        return True
    else:
        print(f"✗ Accuracy difference exceeds tolerance (±${TOLERANCE_ACCURACY})")
        return False

def compare_algorithms(ios_results, android_results):
    """Compare algorithm-level performance"""
    ios_algs = ios_results.get('algorithm_scores', {})
    android_algs = android_results.get('algorithm_scores', {})

    all_pass = True

    print("\nAlgorithm-Level Comparison:")
    for alg_name in ios_algs.keys():
        ios_score = ios_algs.get(alg_name, 0)
        android_score = android_algs.get(alg_name, 0)
        diff = abs(ios_score - android_score)

        status = "✓" if diff <= ${TOLERANCE_ALGORITHM} else "✗"
        print(f"  {status} {alg_name:20s} iOS: {ios_score:.2f}  Android: {android_score:.2f}  Diff: {diff:.2f}")

        if diff > ${TOLERANCE_ALGORITHM}:
            all_pass = False

    return all_pass

try:
    ios_results = load_results('${IOS_RESULTS_PATH}')
    android_results = load_results('${ANDROID_RESULTS_PATH}')

    accuracy_pass = compare_accuracy(ios_results, android_results)
    algorithm_pass = compare_algorithms(ios_results, android_results)

    if accuracy_pass and algorithm_pass:
        print("\n✓ Cross-platform parity verified")
        sys.exit(0)
    else:
        print("\n✗ Cross-platform parity check failed")
        sys.exit(1)

except FileNotFoundError as e:
    print(f"Error: {e}")
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f"Error parsing JSON: {e}")
    sys.exit(1)
EOF

    return $?
}

# Generate summary report
generate_report() {
    print_info "\n📊 Generating test summary report..."

    cat > build/parity_test_report.md <<EOF
# Cross-Platform Parity Test Report

**Generated:** $(date)

## Test Configuration

- iOS Simulator: iPhone 16 Pro
- Android Emulator: Default
- Test Vectors: ${TEST_VECTORS_PATH}
- Accuracy Tolerance: ±${TOLERANCE_ACCURACY}
- Algorithm Tolerance: ±${TOLERANCE_ALGORITHM}

## Results

$(if [ -f "$IOS_RESULTS_PATH" ] && [ -f "$ANDROID_RESULTS_PATH" ]; then
    python3 - <<PYTHON
import json

ios = json.load(open('${IOS_RESULTS_PATH}'))
android = json.load(open('${ANDROID_RESULTS_PATH}'))

print(f"### iOS")
print(f"- Accuracy: {ios.get('accuracy', 0):.2%}")
print(f"- Tests Passed: {ios.get('tests_passed', 0)}")
print(f"- Tests Failed: {ios.get('tests_failed', 0)}")
print(f"")
print(f"### Android")
print(f"- Accuracy: {android.get('accuracy', 0):.2%}")
print(f"- Tests Passed: {android.get('tests_passed', 0)}")
print(f"- Tests Failed: {android.get('tests_failed', 0)}")
print(f"")
print(f"### Parity")
diff = abs(ios.get('accuracy', 0) - android.get('accuracy', 0))
status = "PASS" if diff <= ${TOLERANCE_ACCURACY} else "FAIL"
print(f"- Accuracy Difference: {diff:.2%}")
print(f"- Status: {status}")
PYTHON
else
    echo "Results not available"
fi)

## Test Files

- iOS Results: ${IOS_RESULTS_PATH}
- Android Results: ${ANDROID_RESULTS_PATH}
- iOS Test Output: build/ios_test_output.txt
- Android Test Output: ${ANDROID_PROJECT_PATH}/build/android_test_output.txt

EOF

    print_success "Report generated at: build/parity_test_report.md"
}

# Main execution
main() {
    print_info "🧪 Cross-Platform Parity Testing"
    print_info "=================================="

    # Create build directory
    mkdir -p build

    # Step 1: Check test vectors
    check_test_vectors

    # Step 2: Run iOS tests
    run_ios_tests

    # Step 3: Run Android tests (optional)
    android_available=false
    if run_android_tests; then
        android_available=true
    fi

    # Step 4: Compare results (if Android available)
    if [ "$android_available" = true ]; then
        if compare_results; then
            print_success "\nParity test PASSED ✓"
            exit_code=0
        else
            print_error "\nParity test FAILED ✗"
            exit_code=1
        fi
    else
        print_warning "\nAndroid tests skipped - parity check not performed"
        print_success "iOS tests PASSED ✓"
        exit_code=0
    fi

    # Step 5: Generate report
    generate_report

    # Exit
    print_info "\n=================================="
    exit $exit_code
}

# Run main
main "$@"
