# Planwise - App Store Submission Checklist

## Pre-Submission Requirements

### Apple Developer Account
- [x] Apple Developer Program membership active ($99/year)
- [x] Agreements, Tax, and Banking completed
- [ ] Certificates and provisioning profiles configured
- [ ] App ID registered: com.rubenreut.momentum

### App Preparation
- [ ] Version number set (1.0.0)
- [ ] Build number incremented
- [x] Bundle ID correct: com.rubenreut.momentum
- [ ] Info.plist permissions explained:
  - Camera (for document scanning)
  - Microphone (for voice input)
  - Notifications (for reminders)
- [ ] Archive built successfully
- [ ] No compiler warnings (or documented why they exist)

### Testing Completed
- [ ] All features tested on real devices
- [ ] Tested on smallest (iPhone SE) and largest devices
- [ ] iPad compatibility verified
- [ ] iOS 17.0+ compatibility confirmed
- [ ] Memory leaks checked with Instruments
- [ ] Performance profiled
- [ ] Crash-free for 24 hours of testing
- [ ] Offline mode tested
- [ ] iCloud sync verified

## App Store Connect Configuration

### Basic Information
- [x] App Name: Planwise
- [x] Subtitle: Smart Time Blocking with AI
- [x] Primary Category: Productivity
- [x] Secondary Category: Business
- [ ] Content Rating: 4+ (no objectionable content)

### Pricing & Availability
- [ ] Base App: Free
- [ ] Available in all territories
- [x] In-App Purchases configured:
  - Planwise Pro (1 Month) - €12.99
  - Planwise Pro (1 Year) - €79.99

### Version Information
- [ ] What's New text prepared
- [ ] Support URL: Create dedicated support page
- [ ] Marketing URL: Optional
- [x] Privacy Policy URL: https://rubenreut.github.io/Planwise-legal/privacy-policy.html
- [x] Terms of Service URL: https://rubenreut.github.io/Planwise-legal/terms-of-service.html

### Screenshots
- [ ] iPhone 6.7" (1290 × 2796) - 8-10 screenshots
- [ ] iPad Pro 12.9" (2048 × 2732) - 8-10 screenshots
- [ ] Captions added to all screenshots
- [ ] Screenshots show best features first

### App Preview (Optional)
- [ ] 15-30 second video
- [ ] Shows core features in action
- [ ] Proper dimensions and format

### Description & Keywords
- [ ] Description under 4000 characters
- [ ] Keywords optimized (100 chars max)
- [ ] Promotional text (170 chars max)
- [ ] No competitor names or trademarks
- [ ] No price information in description

### App Icon
- [ ] 1024 × 1024 PNG without transparency
- [ ] Matches icon in app bundle
- [ ] Tested at all sizes
- [ ] No text or inappropriate content

### Review Information
- [ ] Demo account credentials provided
- [ ] Review notes explain:
  - How to test premium features
  - Any specific flows to test
  - TestFlight sandbox testing notes
- [ ] Contact information accurate

## Technical Requirements

### Build Configuration
- [ ] Release configuration used
- [ ] Debug symbols included (for crash reports)
- [ ] Bitcode enabled (if required)
- [ ] No development/test code
- [ ] API keys secured
- [ ] No hardcoded test data

### Privacy & Security
- [ ] App Transport Security configured
- [ ] No private APIs used
- [ ] User data encrypted
- [ ] Keychain used for sensitive data
- [ ] Privacy manifest included (if needed)

### Subscription Specifics
- [ ] Subscription terms clear in app
- [ ] Restore purchases works
- [ ] Subscription management links work
- [ ] Price displayed correctly
- [ ] No misleading subscription practices

## Common Rejection Reasons to Avoid

### Design
- [ ] No placeholder content
- [ ] No beta/test labels
- [ ] Professional UI throughout
- [ ] No broken layouts
- [ ] Proper error handling

### Functionality
- [ ] All features work as described
- [ ] No crashes or hangs
- [ ] No features "coming soon"
- [ ] Login not required for basic features
- [ ] No web views of websites

### Business
- [ ] Clear value proposition
- [ ] Accurate metadata
- [ ] Appropriate age rating
- [ ] No spam or duplicate apps
- [ ] Original content only

### Legal
- [ ] All content properly licensed
- [ ] No trademark violations  
- [ ] Privacy policy accessible
- [ ] Terms of service included
- [ ] GDPR compliant

## Post-Submission

### While In Review
- [ ] Monitor email for Apple communication
- [ ] Be ready to respond within 24 hours
- [ ] Have test account ready if requested
- [ ] Prepare for possible phone call

### If Rejected
- [ ] Read rejection reason carefully
- [ ] Fix all cited issues
- [ ] Reply professionally
- [ ] Resubmit promptly

### After Approval
- [ ] Download and test from App Store
- [ ] Monitor crash reports
- [ ] Respond to user reviews
- [ ] Plan first update
- [ ] Announce on social media
- [ ] Email beta testers

## Marketing Preparation

### App Store Optimization
- [ ] Research competitor keywords
- [ ] A/B test screenshots
- [ ] Monitor keyword rankings
- [ ] Track conversion rates

### Launch Materials
- [ ] Press release drafted
- [ ] Website updated
- [ ] Social media posts ready
- [ ] Email to waitlist prepared
- [ ] Product Hunt submission ready

### Support Setup
- [ ] FAQ page created
- [ ] Support email monitored
- [ ] Bug tracking system ready
- [ ] Feedback collection method

## Final Checks

- [ ] App runs without debugger attached
- [ ] No NSLog statements in production
- [ ] Version number makes sense
- [ ] Copyright year current
- [ ] All team members credited
- [ ] Celebration planned! 🎉

## Important Notes

1. **Review Time**: Allow 7-10 days for review
2. **Expedited Review**: Available for critical issues
3. **TestFlight**: Consider beta testing first
4. **Phased Release**: Consider gradual rollout
5. **Analytics**: Implement before launch

Remember: First impressions matter. Take time to polish everything!