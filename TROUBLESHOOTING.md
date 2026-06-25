# Troubleshooting Guide

## Issue: Blank Screen After Login

### Symptoms
- User logs in successfully with demo account
- Completes onboarding
- Navigation bar appears at bottom (Home, Explore, Rewards, Profile)
- Main content area is blank/gray

### Possible Causes

#### 1. Content Not Rendering
The student home content may not be rendering due to:
- Issue with CustomScrollView or SafeArea
- Aurora background covering content
- Data not loading from mock providers

#### 2. Supabase Not Configured
If Supabase is not configured, the app falls back to demo mode but some data might not load properly.

### Debugging Steps

1. **Check Browser Console**
   - Open Chrome DevTools (F12)
   - Look for any JavaScript errors
   - Check for missing data errors

2. **Test Other Tabs**
   - Click "Explore" tab
   - Click "Rewards" tab
   - Click "Profile" tab
   - See if any of these show content

3. **Check If Data Is Loading**
   - Open DevTools → Console
   - Look for "MockData" references
   - Check if providers are returning data

4. **Verify Onboarding Completion**
   - Check if `onboardingComplete` is true
   - Check if `role` is set to `student`

### Quick Fixes

#### Fix 1: Force Refresh
```bash
# Stop the app
# Clear browser cache
# Run again
flutter run -d chrome
```

#### Fix 2: Check MockData
The app should work with MockData even without Supabase. Verify MockData is being used:

```dart
// In lib/data/app_state.dart
final lessonsProvider = Provider<List<Lesson>>((ref) => MockData.lessons);
final assignedLessonsProvider = Provider<List<Lesson>>((ref) => MockData.assigned);
final learnerProvider = Provider<LearnerProfile>((ref) => MockData.learner);
```

#### Fix 3: Bypass Onboarding (for Testing)
Temporarily modify auth to skip straight to student home:

```dart
// In lib/data/supabase_auth.dart
// In _applyLocalDemoSession method, ensure:
onboardingComplete = true;  // ✅ Should be true
role = account.role;        // ✅ Should be set
```

#### Fix 4: Check Shell Page Rendering
The issue might be with how the shell renders. Try adding debug borders:

```dart
// In lib/widgets/shell_page.dart
// Temporarily add a visible container to test
Container(
  color: Colors.red.withOpacity(0.3), // Make it visible
  child: child,
)
```

### Common Issues

#### Issue: "Cannot find navigation context"
**Cause:** Router not initialized properly  
**Fix:** Ensure ProviderScope wraps MaterialApp.router

#### Issue: "User not authenticated"
**Cause:** Auth state not syncing  
**Fix:** Call `syncAuth()` after onboarding

#### Issue: "Blank screen with navigation"
**Cause:** Content widgets not rendering  
**Fix:** Check SafeArea, CustomScrollView, or data providers

### Testing Without Supabase

The app should work fine without Supabase using MockData. To test:

1. **Don't set environment variables**
2. **Run the app:**
   ```bash
   flutter run -d chrome
   ```
3. **Expected behavior:**
   - App shows "⚠️ Supabase not configured" in console
   - Demo account should still work
   - MockData should provide all lesson data

### Verification Checklist

After logging in with demo account, verify:

- [ ] Navigation bar appears (4 tabs visible)
- [ ] "Home" tab is selected (highlighted)
- [ ] Top shows "Hi, [name]! 👋"
- [ ] Hero card shows level and XP
- [ ] "Continue learning" section shows lessons
- [ ] Scroll works (can scroll up/down)

### If Still Blank

1. **Check Flutter Doctor**
   ```bash
   flutter doctor -v
   ```

2. **Clean and Rebuild**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d chrome
   ```

3. **Try Different Browser**
   ```bash
   # Try Edge
   flutter run -d edge
   
   # Try with web-server
   flutter run -d web-server
   ```

4. **Check for Widget Errors**
   Open Chrome DevTools → Elements tab → Look for any widget rendering issues

5. **Enable Verbose Logging**
   ```dart
   // In main.dart, add:
   debugPrint('StudentHome building...');
   // Check if this appears in console
   ```

### Getting Help

If issue persists:

1. **Screenshot the issue** ✅ (Already have this!)
2. **Check browser console** for errors
3. **Share console output** (full Flutter run output)
4. **Try the test steps** above and report results

### Next Actions

Based on your screenshot:
1. Try clicking the "Explore" tab - does it show content?
2. Check browser console (F12) - any errors?
3. Try scrolling up/down - is there content off-screen?

---

## Other Common Issues

### Issue: "flutter_web_plugins not found"
**Status:** ✅ FIXED  
**Solution:** Added to pubspec.yaml

### Issue: "dotenv not defined"
**Status:** ✅ FIXED  
**Solution:** Removed flutter_dotenv dependency

### Issue: Environment variables not working
**Solution:** Use --dart-define flags:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key
```

### Issue: Sentry errors
**Solution:** Sentry is optional. App works without it.

---

## Debug Mode Commands

```bash
# Run with verbose logging
flutter run -d chrome -v

# Run with DevTools
flutter run -d chrome --devtools

# Check for issues
flutter analyze

# Format code
flutter format lib/

# Run tests
flutter test
```

---

## Contact & Support

For more help:
- Check [SETUP.md](./SETUP.md) for configuration
- See [PRODUCTION_READINESS_REPORT.md](./PRODUCTION_READINESS_REPORT.md) for known issues
- Review [PHASE_1_COMPLETE.md](./PHASE_1_COMPLETE.md) for recent changes
