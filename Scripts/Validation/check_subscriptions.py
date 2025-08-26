#!/usr/bin/env python3
"""
Check App Store Connect subscriptions for the app
"""

import requests
import jwt
import time
import json
from datetime import datetime, timedelta

# You'll need to fill these in from App Store Connect
API_KEY_ID = "YOUR_KEY_ID"  # From App Store Connect
ISSUER_ID = "YOUR_ISSUER_ID"  # Your Team ID from App Store Connect  
PRIVATE_KEY_PATH = "AuthKey_YOUR_KEY_ID.p8"  # Download from App Store Connect

# Your app info
APP_ID = "YOUR_APP_ID"  # The App Store Connect app ID (not bundle ID)
BUNDLE_ID = "com.rubenreut.Momentum"

def generate_token():
    """Generate JWT token for App Store Connect API"""
    try:
        with open(PRIVATE_KEY_PATH, 'r') as f:
            private_key = f.read()
    except FileNotFoundError:
        print("❌ Private key file not found. Please download from App Store Connect")
        print("   1. Go to Users and Access > Keys")
        print("   2. Create a new key with 'App Manager' role")
        print("   3. Download the .p8 file")
        print("   4. Update PRIVATE_KEY_PATH in this script")
        return None
    
    # Create JWT token
    header = {
        "alg": "ES256",
        "kid": API_KEY_ID,
        "typ": "JWT"
    }
    
    payload = {
        "iss": ISSUER_ID,
        "exp": int(time.time()) + (20 * 60),  # 20 minutes
        "aud": "appstoreconnect-v1"
    }
    
    token = jwt.encode(payload, private_key, algorithm="ES256", headers=header)
    return token

def check_subscriptions():
    """Check subscription products in App Store Connect"""
    token = generate_token()
    if not token:
        return
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    print(f"🔍 Checking subscriptions for bundle ID: {BUNDLE_ID}")
    print("=" * 50)
    
    # First, get the app
    apps_url = f"https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]={BUNDLE_ID}"
    response = requests.get(apps_url, headers=headers)
    
    if response.status_code != 200:
        print(f"❌ Failed to get app: {response.status_code}")
        print(response.json())
        return
    
    apps_data = response.json()
    if not apps_data['data']:
        print(f"❌ No app found with bundle ID: {BUNDLE_ID}")
        return
    
    app = apps_data['data'][0]
    app_id = app['id']
    app_name = app['attributes']['name']
    
    print(f"✅ Found app: {app_name} (ID: {app_id})")
    print()
    
    # Get in-app purchases
    iap_url = f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/inAppPurchasesV2"
    response = requests.get(iap_url, headers=headers)
    
    if response.status_code != 200:
        print(f"❌ Failed to get in-app purchases: {response.status_code}")
        print(response.json())
        return
    
    iap_data = response.json()
    subscriptions = [iap for iap in iap_data['data'] if iap['attributes']['productType'] == 'AUTO_RENEWABLE_SUBSCRIPTION']
    
    if not subscriptions:
        print("⚠️  No auto-renewable subscriptions found!")
        print()
        print("To fix this:")
        print("1. Go to App Store Connect > Your App > Monetization > Subscriptions")
        print("2. Create subscription group if needed")
        print("3. Add these subscriptions:")
        print("   - Product ID: com.rubenreut.planwise.pro.monthly")
        print("   - Product ID: com.rubenreut.planwise.pro.annual")
        return
    
    print(f"📦 Found {len(subscriptions)} subscriptions:")
    print()
    
    for sub in subscriptions:
        attrs = sub['attributes']
        print(f"  Product ID: {attrs['productId']}")
        print(f"  Name: {attrs['name']}")
        print(f"  State: {attrs['state']}")
        print(f"  Type: {attrs['productType']}")
        print()
    
    # Check for expected product IDs
    expected_ids = ["com.rubenreut.planwise.pro.monthly", "com.rubenreut.planwise.pro.annual"]
    found_ids = [sub['attributes']['productId'] for sub in subscriptions]
    
    missing_ids = [id for id in expected_ids if id not in found_ids]
    if missing_ids:
        print("⚠️  Missing expected subscriptions:")
        for id in missing_ids:
            print(f"   - {id}")
    else:
        print("✅ All expected subscriptions found!")

if __name__ == "__main__":
    print("🚀 App Store Connect Subscription Checker")
    print("=" * 50)
    print()
    
    if API_KEY_ID == "YOUR_KEY_ID":
        print("❌ Please configure API credentials first!")
        print()
        print("Steps:")
        print("1. Go to https://appstoreconnect.apple.com")
        print("2. Navigate to Users and Access > Keys")
        print("3. Create a new key with 'App Manager' role")
        print("4. Download the .p8 file")
        print("5. Update the variables at the top of this script:")
        print("   - API_KEY_ID")
        print("   - ISSUER_ID (your Team ID)")
        print("   - PRIVATE_KEY_PATH")
        print("   - APP_ID (from App Store Connect, not bundle ID)")
    else:
        check_subscriptions()