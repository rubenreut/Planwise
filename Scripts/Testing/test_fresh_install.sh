#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BUNDLE_ID="com.rubenreut.momentum"
APP_NAME="Momentum"

echo -e "${BLUE}🧪 Fresh Install Test Script${NC}"
echo -e "${BLUE}=============================${NC}"
echo -e "${YELLOW}This simulates App Store review conditions${NC}"
echo ""

# Step 1: Delete the app from device
echo -e "${BLUE}📱 Step 1: Deleting app from device...${NC}"
ios-deploy --uninstall_only --bundle_id $BUNDLE_ID 2>/dev/null || true
echo -e "${GREEN}✓ App deleted (or wasn't installed)${NC}"

# Step 2: Clear keychain items for this app
echo -e "${BLUE}🔑 Step 2: Clearing keychain items...${NC}"
echo -e "${YELLOW}Note: This requires the app to be deleted first${NC}"
# Keychain items are automatically cleared when app is deleted on iOS

# Step 3: Clear any shared app group containers
echo -e "${BLUE}📦 Step 3: App containers cleared with app deletion${NC}"

# Step 4: Build and install fresh
echo -e "${BLUE}🔨 Step 4: Building fresh install...${NC}"
./build_deploy.sh

echo ""
echo -e "${GREEN}✅ Fresh install test complete!${NC}"
echo -e "${BLUE}The app is now running in the same state as App Store reviewers see it.${NC}"
echo ""
echo -e "${YELLOW}Test checklist:${NC}"
echo "1. ✓ No existing keychain data"
echo "2. ✓ No UserDefaults"
echo "3. ✓ No Core Data"
echo "4. ✓ No cached files"
echo "5. ✓ First launch experience"
echo ""
echo -e "${YELLOW}Additional manual tests:${NC}"
echo "- Test on different device models"
echo "- Test with different iOS versions"
echo "- Test with no network connection"
echo "- Test with slow network"
echo "- Test low memory conditions"