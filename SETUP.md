# Kidversity Setup Guide

This guide will help you set up Kidversity for development and production.

## Prerequisites

- Flutter SDK 3.11.1 or higher
- Dart SDK
- A Supabase account ([supabase.com](https://supabase.com))
- (Optional) OpenAI API key for AI lesson generation
- (Optional) Sentry account for error tracking

---

## Step 1: Install Dependencies

```bash
flutter pub get
```

---

## Step 2: Set Up Supabase

### 2.1 Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up/login
2. Click "New Project"
3. Fill in project details:
   - **Name:** kidversity
   - **Database Password:** (generate a strong password)
   - **Region:** Choose closest to your users
4. Wait for project to be created (~2 minutes)

### 2.2 Get Supabase Credentials

1. In your Supabase project dashboard, go to **Settings** → **API**
2. Copy the following:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJhbGci...`)

### 2.3 Set Up Database Schema

1. In Supabase dashboard, go to **SQL Editor**
2. Click **New Query**
3. Copy the entire contents of `supabase/schema.sql`
4. Paste into the SQL editor
5. Click **Run** (bottom right)
6. Verify tables were created by going to **Table Editor**

You should see tables:
- user_profiles
- lessons
- lesson_progress
- lesson_assignments
- badges
- user_badges
- classes
- class_members
- uploaded_files
- xp_logs

### 2.4 Configure Storage Buckets

1. Go to **Storage** in Supabase dashboard
2. Create the following buckets:

**Bucket: lesson-files**
- Public: No
- Allowed MIME types: `.pptx, .pdf, .mp3, .wav`
- Max file size: 25 MB

**Bucket: user-avatars** (optional for future)
- Public: Yes
- Allowed MIME types: `.jpg, .png, .gif`
- Max file size: 2 MB

### 2.5 Configure Authentication

1. Go to **Authentication** → **Providers**
2. Enable **Email** provider (already enabled by default)
3. (Optional) Enable social providers:
   - Google OAuth
   - Apple Sign In
4. Go to **Authentication** → **URL Configuration**
5. Add your app URLs:
   - Site URL: `https://yourdomain.com` (or `http://localhost:3000` for dev)
   - Redirect URLs: Add your callback URLs

---

## Step 3: Configure Environment Variables

### 3.1 Create .env File

```bash
# Copy the example file
cp .env.example .env
```

### 3.2 Edit .env File

Open `.env` and fill in your credentials:

```env
# Supabase Configuration
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...your_key_here

# OpenAI Configuration (optional for now)
OPENAI_API_KEY=sk-...your_key_here

# Sentry Configuration (optional for now)
SENTRY_DSN=https://...your_dsn_here

# Environment
ENVIRONMENT=development

# API Configuration
API_BASE_URL=https://api.kidversity.app
API_TIMEOUT_SECONDS=30
```

**Important:** Never commit `.env` to git! It's already in `.gitignore`.

---

## Step 4: Run the App

### Development Mode (without backend)

The app can run in UI-preview mode without Supabase:

```bash
flutter run -d chrome
```

You'll see a warning about missing environment variables, but the app will still load with mock data.

### Development Mode (with backend)

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

Or for easier development, use:

```bash
# Windows (PowerShell)
$env:SUPABASE_URL="https://xxxxx.supabase.co"; $env:SUPABASE_ANON_KEY="eyJhbGci..."; flutter run -d chrome

# Linux/Mac
SUPABASE_URL=https://xxxxx.supabase.co SUPABASE_ANON_KEY=eyJhbGci... flutter run -d chrome
```

---

## Step 5: Set Up Error Tracking (Optional)

### 5.1 Create Sentry Account

1. Go to [sentry.io](https://sentry.io) and sign up
2. Create a new project
3. Choose **Flutter** as the platform
4. Copy the DSN (looks like: `https://xxxxx@sentry.io/xxxxx`)

### 5.2 Add to .env

```env
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx
```

---

## Step 6: Test Authentication

1. Run the app
2. Click "Sign Up"
3. Enter email and password
4. Check Supabase dashboard → **Authentication** → **Users**
5. You should see your new user!

---

## Step 7: Populate Test Data (Optional)

### 7.1 Create Sample Lessons

1. In Supabase dashboard, go to **Table Editor** → **lessons**
2. Click **Insert Row**
3. Fill in:
   - title: "Test Lesson"
   - subject: "Mandarin"
   - description: "A test lesson"
   - source: "uploaded"
   - status: "published"
   - author_name: "Test Teacher"
   - slides: `[]`
   - checkpoints: `[]`

### 7.2 Or Use SQL to Insert Mock Data

Go to **SQL Editor** and run:

```sql
INSERT INTO lessons (title, subject, description, source, status, author_name, color, emoji, slides, checkpoints)
VALUES (
  'Family Words in Mandarin',
  'Mandarin',
  'Learn to say mum, dad, sister and more with native-style audio.',
  'uploaded',
  'published',
  'Mrs. Ade',
  '#EA580C',
  '👨‍👩‍👧',
  '[]'::jsonb,
  '[]'::jsonb
);
```

---

## Step 8: Build for Production

### Web Build

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=ENVIRONMENT=production \
  --release
```

Output will be in `build/web/`

### Android Build

First, configure signing (see DEPLOYMENT.md), then:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=ENVIRONMENT=production
```

### iOS Build

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=ENVIRONMENT=production
```

---

## Common Issues

### Issue: "Missing required environment variables"

**Solution:** Make sure you've set SUPABASE_URL and SUPABASE_ANON_KEY either in `.env` or via `--dart-define` flags.

### Issue: "Failed to initialize Supabase"

**Solution:** 
- Check your Supabase URL and anon key are correct
- Verify your Supabase project is active (not paused)
- Check your internet connection

### Issue: "Build failed: flutter_web_plugins not found"

**Solution:** Run `flutter pub get` to install all dependencies including flutter_web_plugins.

### Issue: Row Level Security prevents data access

**Solution:** 
- Make sure you're authenticated (signed in)
- Check Supabase **Authentication** → **Policies** to verify RLS policies are correct
- For testing, you can temporarily disable RLS on a table (NOT recommended for production)

---

## Next Steps

1. **Authentication Flow:** The app now has real auth! Test sign up, sign in, and sign out.

2. **Migrate Mock Data:** Replace `MockData` usage in providers with real Supabase queries.

3. **File Upload:** Implement actual file upload in `create_screen.dart` using `file_picker` and Supabase Storage.

4. **AI Generation:** Integrate OpenAI API for lesson generation.

5. **Testing:** Write tests for your new backend integration.

---

## Development Tips

### Hot Reload with Environment Variables

Create a VS Code launch configuration (`.vscode/launch.json`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Kidversity (Dev)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=SUPABASE_URL=${env:SUPABASE_URL}",
        "--dart-define=SUPABASE_ANON_KEY=${env:SUPABASE_ANON_KEY}",
        "--dart-define=ENVIRONMENT=development"
      ]
    }
  ]
}
```

### Check Database Changes

Use Supabase's **Table Editor** to visually inspect data, or run SQL queries in **SQL Editor**.

### Monitor Errors

If you configured Sentry, check your Sentry dashboard for real-time error reports.

---

## Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Documentation](https://flutter.dev/docs)
- [Sentry Flutter SDK](https://docs.sentry.io/platforms/flutter/)

---

**Need help?** Check the [PRODUCTION_READINESS_REPORT.md](./PRODUCTION_READINESS_REPORT.md) for detailed implementation guidance.
