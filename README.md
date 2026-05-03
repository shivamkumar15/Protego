# Aegixa

**Aegixa** is a Flutter-based personal safety app focused on fast SOS dispatch, live location sharing, emergency media capture, and in-app panic delivery.

## Features

- **SOS trigger flow** with hold-to-activate protection.
- **Live location sharing** to emergency contacts through Supabase-backed SOS sessions.
- **SOS inbox** so recipients can view incoming panic alerts, live map links, and saved media.
- **Voice and video evidence capture** during an SOS session.
- **Recipient media download** so received voice and video files can be saved locally and cleaned from remote storage afterward.
- **Panic notifications** with full-screen alerts, overlay support, and emergency sound.
- **FCM push delivery** for background and closed-app SOS notifications.
- **Emergency contact onboarding** with username-based in-app delivery.
- **Firebase Auth + Supabase** hybrid stack.
- **OEM battery guidance** for brands that aggressively restrict background delivery.

## Stack

- Flutter / Dart
- Firebase Auth
- Firebase Cloud Messaging
- Supabase Database, Storage, and Edge Functions
- Geolocator / Flutter Map

## Setup

1. Clone the repository.

```bash
git clone https://github.com/shivamkumar15/Aegixa.git
cd Aegixa
```

2. Install dependencies.

```bash
flutter pub get
```

3. Configure Firebase.

- Create a Firebase project.
- Add the Android app.
- Download `google-services.json` into `android/app/`.
- Update `lib/firebase_options.dart` if you are pointing to your own Firebase project.

4. Configure Supabase.

- Create a Supabase project.
- Update the Supabase URL and anon key in `lib/main.dart`.
- Run these SQL files in the Supabase SQL Editor:
  - `supabase_public_profiles_schema.sql`
  - `supabase_emergency_contacts_schema.sql`
  - `supabase_usernames_schema.sql`
  - `supabase_sos_alerts_schema.sql`
  - `supabase_push_notifications_schema.sql`

5. Configure SOS push delivery.

- Create a Firebase service account JSON from Firebase Console.
- Never commit or paste that JSON into the repo.
- Set it as a Supabase Edge Function secret.

```bash
npx supabase@latest login
npx supabase@latest link --project-ref ilwxanuvttrhxkgmaphq
npx supabase@latest secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat "/path/to/service-account.json")"
npx supabase@latest functions deploy send-sos-push --no-verify-jwt
```

6. Run the app.

```bash
flutter run
```

## Important Notes

- Android devices from Xiaomi, Vivo, Oppo, Realme, Huawei, and similar OEMs may require battery optimization or autostart changes for reliable emergency alerts.
- The app includes an onboarding warning, a battery optimization shortcut, and an OEM-specific guide screen to help users configure this.
- SOS media is uploaded for recipients, then downloaded locally by recipients and cleaned up remotely to reduce Supabase storage usage.

## Project Structure

- `lib/screens` UI screens including home, onboarding, SOS inbox, battery guide, and recordings.
- `lib/services` services for SOS alerts, media handling, push notifications, and device settings.
- `supabase/functions/send-sos-push` Edge Function used to send FCM push notifications.
- `supabase_*.sql` database setup files.

Built for personal safety and rapid emergency response.
