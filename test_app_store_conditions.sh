#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BUNDLE_ID="com.rubenreut.momentum"
PROJECT_PATH="/Users/rubenreut/Momentum/Momentum/Momentum.xcodeproj"
SCHEME_NAME="Momentum"

echo -e "${BLUE}🍎 App Store Review Simulator${NC}"
echo -e "${BLUE}==============================${NC}"
echo ""

# Function to test on simulator
test_simulator() {
    local device_name="$1"
    local os_version="$2"
    
    echo -e "${BLUE}Testing on: $device_name (iOS $os_version)${NC}"
    
    # Boot the simulator
    echo -e "Booting simulator..."
    xcrun simctl boot "$device_name" 2>/dev/null || true
    
    # Uninstall existing app
    echo -e "Removing existing app..."
    xcrun simctl uninstall booted $BUNDLE_ID 2>/dev/null || true
    
    # Reset keychain and settings
    echo -e "Resetting simulator data..."
    xcrun simctl keychain booted reset
    
    # Build for simulator
    echo -e "Building for simulator..."
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$SCHEME_NAME" \
               -destination "platform=iOS Simulator,name=$device_name,OS=$os_version" \
               -configuration Release \
               clean build \
               ONLY_ACTIVE_ARCH=NO \
               -quiet
    
    # Install and launch
    echo -e "Installing app..."
    xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/Momentum-*/Build/Products/Release-iphonesimulator/Momentum.app
    
    echo -e "Launching app..."
    xcrun simctl launch --console booted $BUNDLE_ID
    
    echo -e "${GREEN}✓ Test complete for $device_name${NC}"
    echo ""
}

# Menu
echo -e "${YELLOW}Select test type:${NC}"
echo "1) Test on physical device (fresh install)"
echo "2) Test on iPhone SE simulator (smallest screen)"
echo "3) Test on iPhone 15 Pro simulator (standard)"
echo "4) Test on iPhone 15 Pro Max simulator (largest)"
echo "5) Test on iPad simulator"
echo "6) Run all simulator tests"
echo "7) Reset and test current simulator"
echo ""
read -p "Enter choice (1-7): " choice

case $choice in
    1)
        echo -e "${BLUE}Running fresh install on physical device...${NC}"
        ./test_fresh_install.sh
        ;;
    2)
        test_simulator "iPhone SE (3rd generation)" "17.5"
        ;;
    3)
        test_simulator "iPhone 15 Pro" "17.5"
        ;;
    4)
        test_simulator "iPhone 15 Pro Max" "17.5"
        ;;
    5)
        test_simulator "iPad Pro 11-inch (M4)" "17.5"
        ;;
    6)
        echo -e "${BLUE}Running all simulator tests...${NC}"
        test_simulator "iPhone SE (3rd generation)" "17.5"
        test_simulator "iPhone 15 Pro" "17.5"
        test_simulator "iPhone 15 Pro Max" "17.5"
        test_simulator "iPad Pro 11-inch (M4)" "17.5"
        ;;
    7)
        echo -e "${BLUE}Resetting current simulator...${NC}"
        # Uninstall app
        xcrun simctl uninstall booted $BUNDLE_ID 2>/dev/null || true
        # Reset keychain
        xcrun simctl keychain booted reset
        # Erase all content and settings
        read -p "Erase ALL simulator content? (y/n): " erase_all
        if [ "$erase_all" = "y" ]; then
            xcrun simctl erase booted
        fi
        echo -e "${GREEN}✓ Simulator reset complete${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}App Store Review Testing Tips:${NC}"
echo "• Always test with a clean install"
echo "• Test all device sizes (especially iPhone SE)"
echo "• Test with poor network conditions"
echo "• Test with device in different languages"
echo "• Test with accessibility features enabled"
echo "• Test memory warnings (Device > Trigger Memory Warning in Simulator)"
echo "• Test with Background App Refresh disabled"
echo "• Test with Low Power Mode enabled"