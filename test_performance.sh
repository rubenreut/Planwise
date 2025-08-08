#!/bin/bash

# Simple build and run script
cd /Users/rubenreut/Momentum/Momentum

echo "Building Momentum..."
xcodebuild -project Momentum.xcodeproj \
           -scheme Momentum \
           -destination "platform=iOS,id=00008140-000105483E2A801C" \
           -derivedDataPath build_output \
           clean build

echo "Installing and launching..."
xcrun devicectl device install app --device 00008140-000105483E2A801C build_output/Build/Products/Debug-iphoneos/Momentum.app
xcrun devicectl device process launch --device 00008140-000105483E2A801C com.rubenreut.momentum

echo "Done!"