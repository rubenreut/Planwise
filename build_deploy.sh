#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_PATH="/Users/rubenreut/Momentum/Momentum/Momentum.xcodeproj"
SCHEME_NAME="Momentum"
DEVICE_ID="00008140-000105483E2A801C"
BUNDLE_ID="com.rubenreut.Momentum"
APP_NAME="Momentum"

# Performance tracking
SCRIPT_START_TIME=$(date +%s)

# Function to print colored output
print_status() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to measure operation time
measure_time() {
    local start_time=$1
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    echo "${elapsed}s"
}

# Function to clean derived data if needed
clean_derived_data() {
    print_warning "Cleaning DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/Momentum-*
    rm -rf ~/Library/Caches/org.swift.swiftpm
}

# Function to parse and handle build errors
handle_build_error() {
    local error_output="$1"
    
    # Check for common error patterns
    if echo "$error_output" | grep -q "No such module"; then
        print_warning "Module import error detected. Checking dependencies..."
        clean_derived_data
        return 1
    elif echo "$error_output" | grep -q "Command PhaseScriptExecution failed"; then
        print_warning "Script phase error. Cleaning and retrying..."
        clean_derived_data
        return 1
    elif echo "$error_output" | grep -q "Code Signing Error"; then
        print_error "Code signing issue detected. Please check your provisioning profile."
        return 2
    fi
    
    return 0
}

# Function to build with retry logic
build_with_retry() {
    local attempt=1
    local max_attempts=3
    local build_output
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Build attempt $attempt of $max_attempts..."
        
        # Capture build output
        build_output=$(xcodebuild build \
            -project "$PROJECT_PATH" \
            -scheme "$SCHEME_NAME" \
            -destination "id=$DEVICE_ID" \
            -parallelizeTargets \
            -quiet 2>&1)
        
        if [ $? -eq 0 ]; then
            return 0
        else
            print_error "Build failed on attempt $attempt"
            
            # Try to handle the error
            handle_build_error "$build_output"
            local error_handled=$?
            
            if [ $error_handled -eq 2 ]; then
                # Unrecoverable error
                echo "$build_output"
                return 1
            elif [ $attempt -lt $max_attempts ]; then
                print_warning "Retrying build..."
                sleep 2
            else
                print_error "Build failed after $max_attempts attempts"
                echo "$build_output"
                return 1
            fi
        fi
        
        ((attempt++))
    done
}

# Main execution
main() {
    print_status "🚀 Momentum Build & Deploy Script"
    print_status "================================="
    
    # Check if device is connected - skip devicectl check since xcodebuild will handle it
    print_status "Using device ID: $DEVICE_ID"
    
    # Find build directory dynamically
    print_status "📍 Finding build directory..."
    BUILD_DIR=$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -showBuildSettings 2>/dev/null | grep -m 1 " BUILD_DIR = " | awk '{print $3}')
    
    if [ -z "$BUILD_DIR" ]; then
        print_error "Could not determine build directory"
        exit 1
    fi
    
    print_status "Build directory: $BUILD_DIR"
    
    # Clean
    local clean_start=$(date +%s)
    print_status "🧹 Cleaning..."
    xcodebuild clean -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -destination "id=$DEVICE_ID" -quiet 2>&1
    if [ $? -eq 0 ]; then
        print_success "Clean completed ($(measure_time $clean_start))"
    else
        print_error "Clean failed"
        exit 1
    fi
    
    # Build with retry logic
    local build_start=$(date +%s)
    print_status "🔨 Building with parallel compilation..."
    if build_with_retry; then
        print_success "Build completed ($(measure_time $build_start))"
    else
        exit 1
    fi
    
    # Install
    local install_start=$(date +%s)
    print_status "📱 Installing on device..."
    # Use the newer device ID for devicectl
    DEVICECTL_ID="27966A7F-00A2-4FE7-9D0E-A9BE1EE7DE1C"
    install_output=$(xcrun devicectl device install app --device "$DEVICECTL_ID" "$BUILD_DIR/Debug-iphoneos/$APP_NAME.app" 2>&1)
    
    if [ $? -eq 0 ]; then
        print_success "Installation completed ($(measure_time $install_start))"
    else
        print_error "Installation failed"
        echo "$install_output"
        exit 1
    fi
    
    # Launch with console output
    local launch_start=$(date +%s)
    print_status "🚀 Launching with console output..."
    print_status "📋 Console logs will appear below (Ctrl+C to stop):"
    print_status "=================================================="
    
    # Launch the app with console output visible and capture logs
    xcrun devicectl device process launch --device "$DEVICECTL_ID" "$BUNDLE_ID" --console --terminate-existing 2>&1 | while IFS= read -r line; do
        echo "$line"
        # Capture debug output
        if [[ "$line" == *"🚀"* ]] || [[ "$line" == *"📱"* ]] || [[ "$line" == *"✅"* ]] || [[ "$line" == *"❌"* ]] || [[ "$line" == *"🗄️"* ]]; then
            echo "[DEBUG] $line"
        fi
    done
    
    # Note: The above command will stream logs until interrupted
    print_success "Launch completed ($(measure_time $launch_start))"
    
    # Total time
    local total_time=$(measure_time $SCRIPT_START_TIME)
    print_status "✅ Total time: $total_time"
}

# Trap errors and provide helpful messages
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main