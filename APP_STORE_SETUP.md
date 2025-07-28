# App Store Setup Guide for Momentum

## Prerequisites
- Apple Developer Account ($99/year)
- App Store Connect access
- Xcode 15 or later

## Step 1: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **App Name**: Momentum - AI Scheduler
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.rubenreut.momentum`
   - **SKU**: `MOMENTUM001` (or any unique identifier)

## Step 2: Create Subscription Group

1. In your app, go to **Monetization** → **In-App Purchases**
2. Click **Create** under Subscription Groups
3. **Reference Name**: Premium
4. **Subscription Group Display Name**: Momentum Pro

## Step 3: Create Monthly Subscription

1. Click **Create** in your subscription group
2. Fill in:
   - **Reference Name**: Monthly Premium
   - **Product ID**: `com.rubenreut.momentum.premium.monthly`
   - **Subscription Duration**: 1 Month
   - **Price**: Tier 10 ($9.99 USD)

3. Add Localization:
   - **Display Name**: Momentum Pro Monthly
   - **Description**: Unlimited AI messages, image analysis, and premium features

## Step 4: Create Annual Subscription

1. Click **Create** in your subscription group
2. Fill in:
   - **Reference Name**: Annual Premium
   - **Product ID**: `com.rubenreut.momentum.premium.annual`
   - **Subscription Duration**: 1 Year
   - **Price**: Tier 50 ($79.99 USD)

3. Add Localization:
   - **Display Name**: Momentum Pro Annual
   - **Description**: Best value - save 33%! Unlimited AI messages and premium features

## Step 5: Configure Subscription Group

1. In the subscription group settings:
   - **Subscription Ranking**: 
     - Rank 1: Monthly ($9.99)
     - Rank 2: Annual ($79.99)
   - This ensures upgrades work correctly

## Step 6: Add App Information

1. **App Information** section:
   - **Subtitle**: Smart Time Blocking with AI
   - **Category**: Primary: Productivity, Secondary: Business

2. **App Privacy**:
   - Complete the privacy questionnaire
   - Add privacy policy URL: `https://momentum.app/privacy`

## Step 7: Set Up Xcode

1. Open your project in Xcode
2. Select your target → **Signing & Capabilities**
3. Ensure **In-App Purchase** capability is added
4. Select the StoreKit Configuration file:
   - Click the project navigator
   - Select `Momentum.storekit`
   - In the inspector, check "Use for App Store Connect"

## Step 8: Test with Sandbox

1. Create a Sandbox Tester:
   - App Store Connect → **Users and Access**
   - **Sandbox Testers** → **+**
   - Create test account with fake email

2. Test on device:
   - Sign out of App Store on device
   - Run app from Xcode
   - Make purchase with sandbox account

## Step 9: Submit for Review

### Required for Subscription Review:
1. **Screenshots** showing:
   - Paywall screen
   - Premium features in use
   - Subscription management

2. **Review Notes**:
   ```
   This app uses AI to help users schedule their day.
   
   Free users get 10 messages total to try the app.
   Premium subscription unlocks:
   - 500 daily AI messages
   - 20 daily image/PDF uploads
   - Advanced scheduling features
   
   Test credentials: [provide if needed]
   ```

3. **Subscription Terms**:
   - Add Terms of Service URL: `https://momentum.app/terms`
   - Add EULA if required

## Step 10: Important URLs

You need to host these pages:
- Privacy Policy: `https://momentum.app/privacy`
- Terms of Service: `https://momentum.app/terms`
- Support: `https://momentum.app/support`

## Testing Checklist

- [ ] Products load in the app
- [ ] Purchase flow completes
- [ ] Subscription shows as active
- [ ] Restore purchases works
- [ ] Message limit enforced (10 free)
- [ ] Premium features unlock after purchase
- [ ] Subscription management sheet opens

## Common Issues

1. **Products not loading**:
   - Wait 24 hours after creating in App Store Connect
   - Ensure agreements are signed in App Store Connect
   - Check bundle ID matches exactly

2. **Purchases failing**:
   - Use sandbox account, not real Apple ID
   - Ensure device is signed into sandbox account
   - Check internet connection

3. **Subscription not recognized**:
   - Call `Transaction.currentEntitlements` on app launch
   - Handle subscription renewal properly

## Price Points

- Monthly: $9.99 (Tier 10)
- Annual: $79.99 (Tier 50) - 33% savings

This gives users a strong incentive to choose annual while keeping monthly accessible.