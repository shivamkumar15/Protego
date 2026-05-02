# Aegixa 🛡️

**Aegixa** (formerly Protego) is a powerful, personal safety guardian application built with Flutter. It provides real-time SOS alerts, emergency contact management, and location tracking to ensure you are never alone in an emergency.

## ✨ Features

- 🚨 **One-Tap SOS**: Instantly trigger an emergency alert to your designated contacts.
- 📍 **Live Location Tracking**: Share your precise coordinates with your guardians in real-time.
- 📞 **Emergency Contacts**: Manage and quickly reach out to your trusted network.
- 🎙️ **SOS Recordings**: Automatically record audio during an SOS event for evidence and situational awareness.
- 🔐 **Secure Authentication**: Robust login and signup system using Firebase Auth (Phone and Email support).
- 🌓 **Dynamic Themes**: Beautiful Light and Dark modes for better accessibility.
- 🌍 **Integrated Maps**: View your surroundings and locate emergency services easily.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
- [Firebase Account](https://firebase.google.com/)
- [Supabase Account](https://supabase.com/)

### Setup

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/shivamkumar15/Aegixa.git
    cd Aegixa
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Configure Firebase**:
    - Create a new project in the Firebase Console.
    - Add Android/iOS apps and download `google-services.json` and `GoogleService-Info.plist`.
    - Place `google-services.json` in `android/app/`.
    - Place `GoogleService-Info.plist` in `ios/Runner/`.

4.  **Configure Supabase**:
    - Update the Supabase URL and Anon Key in `lib/main.dart`.

5.  **Run the app**:
    ```bash
    flutter run
    ```

## 🛠️ Tech Stack

- **Frontend**: Flutter / Dart
- **Backend/Auth**: Firebase & Supabase
- **Database**: Supabase / Sqflite (Local)
- **Maps**: Flutter Map / Geolocator

## 📂 Project Structure

- `lib/screens`: All UI screens (Home, Login, SOS, etc.)
- `lib/services`: Backend and utility services.
- `assets`: Application icons and images.

---

Built with ❤️ for personal safety.
