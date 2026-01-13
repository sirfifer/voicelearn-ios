#!/bin/bash
#
# UnaMentis App Store Validation Script
# Run this before submitting to TestFlight/App Store
#
# Usage: ./scripts/validate-for-appstore.sh [--quick] [--archive]
#   --quick   Skip test suite (faster validation)
#   --archive Create archive after validation
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCHEME="UnaMentis"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/UnaMentis.xcarchive"

# Parse arguments
SKIP_TESTS=false
CREATE_ARCHIVE=false
for arg in "$@"; do
  case $arg in
    --quick)
      SKIP_TESTS=true
      shift
      ;;
    --archive)
      CREATE_ARCHIVE=true
      shift
      ;;
  esac
done

# Helper functions
print_header() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_check() {
  echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "  ${RED}✗${NC} $1"
}

print_info() {
  echo -e "  ${BLUE}ℹ${NC} $1"
}

# Track validation results
ERRORS=0
WARNINGS=0

cd "$PROJECT_DIR"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     UnaMentis App Store Validation                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# Stage 1: Environment Check
# ============================================
print_header "Stage 1: Environment Check"

# Check Xcode
if command -v xcodebuild &> /dev/null; then
  XCODE_VERSION=$(xcodebuild -version | head -1)
  print_check "Xcode: $XCODE_VERSION"
else
  print_error "Xcode not found"
  exit 1
fi

# Check Swift
SWIFT_VERSION=$(swift --version 2>&1 | head -1)
print_check "Swift: $SWIFT_VERSION"

# Check xcbeautify (optional)
if command -v xcbeautify &> /dev/null; then
  print_check "xcbeautify: installed"
  USE_XCBEAUTIFY=true
else
  print_warning "xcbeautify not installed (run: brew install xcbeautify)"
  USE_XCBEAUTIFY=false
fi

# ============================================
# Stage 2: Required Files Check
# ============================================
print_header "Stage 2: Required Files Check"

# Privacy Manifest
if [ -f "UnaMentis/PrivacyInfo.xcprivacy" ]; then
  print_check "PrivacyInfo.xcprivacy exists"

  # Validate XML
  if plutil -lint UnaMentis/PrivacyInfo.xcprivacy > /dev/null 2>&1; then
    print_check "Privacy manifest is valid XML"
  else
    print_error "Privacy manifest has invalid XML"
    ((ERRORS++))
  fi
else
  print_error "PrivacyInfo.xcprivacy is MISSING (required since Spring 2024)"
  ((ERRORS++))
fi

# Info.plist
if [ -f "UnaMentis/Info.plist" ]; then
  print_check "Info.plist exists"

  # Check required keys
  MICROPHONE_DESC=$(plutil -extract NSMicrophoneUsageDescription raw UnaMentis/Info.plist 2>/dev/null || echo "")
  if [ -n "$MICROPHONE_DESC" ]; then
    print_check "NSMicrophoneUsageDescription: set"
  else
    print_error "NSMicrophoneUsageDescription: MISSING"
    ((ERRORS++))
  fi

  SPEECH_DESC=$(plutil -extract NSSpeechRecognitionUsageDescription raw UnaMentis/Info.plist 2>/dev/null || echo "")
  if [ -n "$SPEECH_DESC" ]; then
    print_check "NSSpeechRecognitionUsageDescription: set"
  else
    print_warning "NSSpeechRecognitionUsageDescription: not set"
    ((WARNINGS++))
  fi
else
  print_error "Info.plist is MISSING"
  ((ERRORS++))
fi

# Entitlements
if [ -f "UnaMentis/UnaMentis.entitlements" ]; then
  print_check "UnaMentis.entitlements exists"
else
  print_warning "UnaMentis.entitlements not found"
  ((WARNINGS++))
fi

# App Icons
if [ -d "UnaMentis/Assets.xcassets/AppIcon.appiconset" ]; then
  ICON_COUNT=$(ls UnaMentis/Assets.xcassets/AppIcon.appiconset/*.png 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ICON_COUNT" -gt 0 ]; then
    print_check "App icons: $ICON_COUNT image(s) found"
  else
    print_warning "App icons: no PNG files in appiconset"
    ((WARNINGS++))
  fi
else
  print_warning "AppIcon.appiconset not found"
  ((WARNINGS++))
fi

# ============================================
# Stage 3: Security Check
# ============================================
print_header "Stage 3: Security Check"

# Check for hardcoded API keys
if grep -rE "(sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16})" --include="*.swift" UnaMentis/ 2>/dev/null | grep -v "Test" | grep -v "Mock" | grep -v "example" > /dev/null; then
  print_error "Potential hardcoded API keys found!"
  ((ERRORS++))
else
  print_check "No hardcoded API keys detected"
fi

# Check RemoteLogHandler
if grep -q "#if DEBUG" UnaMentis/Core/Logging/RemoteLogHandler.swift 2>/dev/null; then
  print_check "Remote logging is DEBUG-only"
else
  print_warning "Remote logging may be enabled in release"
  ((WARNINGS++))
fi

# Check for print statements
PRINT_COUNT=$(grep -rn "print(" --include="*.swift" UnaMentis/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$PRINT_COUNT" -gt 20 ]; then
  print_warning "$PRINT_COUNT print() statements found (consider using Logger)"
  ((WARNINGS++))
else
  print_check "Print statement count acceptable ($PRINT_COUNT)"
fi

# ============================================
# Stage 4: Build Check
# ============================================
print_header "Stage 4: Build Check (Release Configuration)"

mkdir -p "$BUILD_DIR"

print_info "Building for iOS Simulator..."

BUILD_CMD="xcodebuild build \
  -scheme $SCHEME \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Release \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO"

if $USE_XCBEAUTIFY; then
  eval "$BUILD_CMD 2>&1 | xcbeautify"
else
  eval "$BUILD_CMD 2>&1 | grep -E '(error:|warning:|Build Succeeded|BUILD SUCCEEDED)'" || true
fi

if [ ${PIPESTATUS[0]} -eq 0 ]; then
  print_check "Release build succeeded"
else
  print_error "Release build failed"
  ((ERRORS++))
fi

# ============================================
# Stage 5: Test Suite
# ============================================
if [ "$SKIP_TESTS" = false ]; then
  print_header "Stage 5: Test Suite"

  print_info "Running tests..."

  TEST_CMD="xcodebuild test \
    -scheme $SCHEME \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -enableCodeCoverage YES \
    CODE_SIGNING_ALLOWED=NO"

  if $USE_XCBEAUTIFY; then
    eval "$TEST_CMD 2>&1 | xcbeautify"
  else
    eval "$TEST_CMD 2>&1 | grep -E '(Test Suite|Test Case|Executed|passed|failed)'" || true
  fi

  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    print_check "All tests passed"
  else
    print_error "Some tests failed"
    ((ERRORS++))
  fi
else
  print_header "Stage 5: Test Suite (SKIPPED)"
  print_info "Use without --quick to run tests"
fi

# ============================================
# Stage 6: Archive (Optional)
# ============================================
if [ "$CREATE_ARCHIVE" = true ]; then
  print_header "Stage 6: Create Archive"

  print_info "Creating archive..."

  ARCHIVE_CMD="xcodebuild archive \
    -scheme $SCHEME \
    -destination 'generic/platform=iOS' \
    -archivePath '$ARCHIVE_PATH' \
    -configuration Release \
    -skipPackagePluginValidation \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY='-'"

  if $USE_XCBEAUTIFY; then
    eval "$ARCHIVE_CMD 2>&1 | xcbeautify"
  else
    eval "$ARCHIVE_CMD 2>&1 | grep -E '(error:|warning:|ARCHIVE SUCCEEDED)'" || true
  fi

  if [ -d "$ARCHIVE_PATH" ]; then
    print_check "Archive created: $ARCHIVE_PATH"

    # Get size
    APP_SIZE=$(du -sh "$ARCHIVE_PATH/Products/Applications/UnaMentis.app" 2>/dev/null | cut -f1)
    print_info "App size: $APP_SIZE"
  else
    print_error "Archive creation failed"
    ((ERRORS++))
  fi
fi

# ============================================
# Summary
# ============================================
print_header "Validation Summary"

echo ""
if [ $ERRORS -gt 0 ]; then
  echo -e "  ${RED}ERRORS:   $ERRORS${NC}"
else
  echo -e "  ${GREEN}ERRORS:   0${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
  echo -e "  ${YELLOW}WARNINGS: $WARNINGS${NC}"
else
  echo -e "  ${GREEN}WARNINGS: 0${NC}"
fi

echo ""

if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ✓ VALIDATION PASSED - Ready for TestFlight                    ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Open Xcode and select Product > Archive"
  echo "  2. In Organizer, click 'Distribute App'"
  echo "  3. Select 'TestFlight & App Store' or 'TestFlight Internal Only'"
  echo "  4. Follow the upload wizard"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  ✗ VALIDATION FAILED - Fix errors before submission            ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Please fix the errors listed above and run validation again."
  echo ""
  exit 1
fi
