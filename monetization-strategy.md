# Monetization Strategy

## 💰 Pricing Structure

### Free Tier - "Momentum Basic"
- ✅ Full scheduling features
- ✅ 3 default categories + 2 custom
- ✅ 3 months of history
- ✅ 10 AI requests per day
- ✅ Basic widget (today view)
- ✅ CloudKit sync
- ✅ Reminders
- ❌ Custom themes
- ❌ Analytics/insights
- ❌ Unlimited AI
- ❌ Advanced widgets

### Premium Tier - "Momentum Pro"
**$4.99/month or $39.99/year (save 33%)**

- ✅ Everything in Basic
- ✅ Unlimited categories
- ✅ Unlimited history
- ✅ Unlimited AI requests
- ✅ All widgets
- ✅ Custom themes
- ✅ Analytics & insights
- ✅ Export to PDF
- ✅ Priority support
- ✅ Early access to new features
- ✅ No watermark on exports

### Future: Momentum Suite
**$9.99/month or $79.99/year**
- All apps in ecosystem
- Cross-app insights
- Advanced correlations
- API access
- Family sharing (up to 5)

## 📊 Implementation Details

### RevenueCat Setup
```swift
// Product IDs (must match App Store Connect)
let monthlyID = "com.rubnereut.momentum.monthly"
let yearlyID = "com.rubnereut.momentum.yearly"
let lifetimeID = "com.rubnereut.momentum.lifetime" // $99.99

// Entitlements
let premiumEntitlement = "premium"
```

### Paywall Triggers
1. **Hard Limits Hit:**
   - 11th AI request in day
   - Viewing history > 3 months
   - Accessing themes

2. **Soft Prompts:**
   - After 7 days of active use
   - After 50 completed time blocks
   - In settings menu

3. **Value Moments:**
   - After AI saves their day
   - Weekly report shows progress
   - When they hit a streak

### Paywall Design
```
Header: "Unlock Your Full Potential"
Hero: AI assistant icon or theme preview

Benefits:
✨ Unlimited AI scheduling assistant
📊 Track your progress over time
🎨 Beautiful themes to match your style
📱 Advanced widgets for your home screen
🔒 All your data, forever

[Start Free Trial] - if offered
[Continue - $4.99/mo]
[Save 33% - $39.99/yr] <- highlighted

"Restore Purchase" (small text)
"Terms" | "Privacy" (footer)
```

## 📈 Conversion Optimization

### Free Trial Strategy
- 7-day free trial for yearly only
- Require payment method upfront
- Send reminder 2 days before charge
- Show trial status in app

### Pricing Psychology
- Yearly emphasized (better value)
- Monthly as "reference price"
- Lifetime for power users
- Limited-time launch pricing

### Social Proof
- "Join 10,000+ productive people"
- App Store reviews in paywall
- Success stories/testimonials
- "Featured by Apple" badge

## 💡 Retention Tactics

### Engagement Loops
1. Daily: Check off time blocks
2. Weekly: Review analytics
3. Monthly: See progress trends
4. Quarterly: New themes released

### Win-Back Campaigns
- "We miss you" notification after 7 days inactive
- Special offer for lapsed users
- Feature highlights they haven't tried
- Success stories from similar users

### Churn Prevention
- Grace period for failed payments
- Downgrade options before cancel
- Pause subscription option
- Exit survey to understand why

## 📊 Metrics to Track

### Acquisition
- Install to trial start: Target 15%
- Trial to paid: Target 50%
- Install to paid: Target 7.5%
- Paywall views to purchase: Target 4%

### Revenue
- Monthly Recurring Revenue (MRR)
- Average Revenue Per User (ARPU)
- Customer Lifetime Value (CLV)
- Churn rate: Target < 10%/month

### Engagement
- Daily Active Users (DAU)
- AI requests per user
- Time blocks created
- Features used

## 🚀 Launch Strategy

### Week 1: Soft Launch
- $0.99 "launch week only"
- Limited to first 1000 users
- Gather feedback
- Fix critical bugs

### Week 2-4: Price Testing
- A/B test $3.99 vs $4.99
- Test free trial vs no trial
- Optimize paywall copy
- Monitor conversion rates

### Month 2+: Optimization
- Introduce yearly plan
- Add lifetime option
- Theme store launches
- Referral program

## 💸 Revenue Projections

### Conservative (Year 1)
- 10,000 downloads
- 5% conversion rate
- 500 premium users
- $2,500 MRR
- $30,000 annual

### Realistic (Year 1)
- 50,000 downloads
- 7.5% conversion
- 3,750 premium users
- $18,750 MRR
- $225,000 annual

### Optimistic (Year 1)
- 100,000 downloads
- 10% conversion
- 10,000 premium users
- $50,000 MRR
- $600,000 annual

## 🎯 Monetization Experiments

### A/B Tests Queue
1. Price points: $2.99 vs $4.99 vs $6.99
2. Trial length: 3 vs 7 vs 14 days
3. Paywall timing: Day 1 vs Day 7
4. Benefits order on paywall
5. Annual discount: 20% vs 33% vs 50%

### Feature Gating Tests
- AI requests: 5 vs 10 vs 20 free/day
- History: 1 vs 3 vs 6 months free
- Categories: 3 vs 5 free
- Widgets: 1 vs all free

### Upsell Opportunities
- Theme packs: $1.99 each
- Extra AI requests: $0.99 for 20
- Priority support: +$2/month
- Data export packs: $0.99

## 🔐 Implementation Security

### Receipt Validation
- Server-side validation required
- Cache validation results
- Graceful degradation on failure
- Regular receipt refresh

### Entitlement Management
```swift
func checkPremiumStatus() {
    Purchases.shared.getCustomerInfo { info, error in
        let isPremium = info?.entitlements["premium"]?.isActive == true
        UserDefaults.standard.set(isPremium, forKey: "isPremium")
    }
}
```

### Fraud Prevention
- Device fingerprinting
- Unusual pattern detection
- Geographic restrictions
- Family sharing limits

## 📱 App Store Optimization

### Keywords for Premium
- "pro planner"
- "premium scheduler"
- "AI calendar"
- "productivity premium"
- "time blocking pro"

### Screenshot Strategy
- Show premium features
- Before/after comparisons
- AI assistant in action
- Beautiful themes
- Analytics dashboards

### Review Strategy
- Prompt after successful week
- Premium users only
- Never after problems
- Max once per version