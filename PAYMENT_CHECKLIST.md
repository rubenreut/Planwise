# Payment Implementation Checklist

## ✅ Completed in Code

- [x] SubscriptionManager with StoreKit 2
- [x] Message counter (10 free total)
- [x] Paywall UI with pricing
- [x] Monthly ($9.99) and Annual ($79.99) options
- [x] Image upload gated behind premium
- [x] Restore purchases functionality
- [x] Debug mode for testing
- [x] StoreKit configuration file

## 🔧 Required in App Store Connect

### 1. Create Subscriptions
- [ ] Create subscription group "Premium"
- [ ] Add Monthly subscription
  - Product ID: `com.rubenreut.momentum.premium.monthly`
  - Price: $9.99 (Tier 10)
- [ ] Add Annual subscription  
  - Product ID: `com.rubenreut.momentum.premium.annual`
  - Price: $79.99 (Tier 50)

### 2. Required URLs (You need to create these)
- [ ] Privacy Policy: https://momentum.app/privacy
- [ ] Terms of Service: https://momentum.app/terms
- [ ] Support: https://momentum.app/support

### 3. App Store Agreements
- [ ] Sign Paid Applications Agreement
- [ ] Set up banking and tax info
- [ ] Complete all contracts

## 🧪 Testing Steps

1. **Local Testing**:
   - Use [DEBUG] Enable Premium button
   - Verify message limit works
   - Test image upload restriction

2. **Sandbox Testing**:
   - Create sandbox tester account
   - Sign out of real App Store
   - Test purchase flow
   - Test restore purchases

3. **Production Testing**:
   - TestFlight with real products
   - Verify subscription renewal
   - Test on multiple devices

## 📱 What Users Experience

1. **Free Trial**:
   - 10 messages total (lifetime)
   - No image uploads
   - See remaining messages indicator

2. **Hit Limit**:
   - Paywall appears
   - Can't send more messages
   - Can still view schedule

3. **After Purchase**:
   - Unlimited messages
   - Image analysis enabled
   - "Premium" badge (optional)

## 🚀 Launch Checklist

- [ ] Remove DEBUG button
- [ ] Test with real money
- [ ] Prepare screenshots showing paywall
- [ ] Write App Store review notes
- [ ] Submit for review

## 💰 Revenue Projections

Assuming 1000 downloads/month:
- 10% conversion = 100 subscribers
- 70% monthly, 30% annual
- Monthly revenue: ~$900
- After Apple's cut (30%): ~$630/month

## 🐛 Common Issues

1. **Products not loading**: Wait 24h after App Store Connect setup
2. **Purchase fails**: Check sandbox account setup
3. **Subscription not active**: Verify Transaction.currentEntitlements

Remember: The 10 message limit is TOTAL, not daily. This creates urgency!