# Personal News Assistant

A Flutter mobile app for saving and organizing news articles from various sources. Features WhatsApp-style link previews, Android share sheet integration, and offline storage.

## Features

- **Save News Links**: Add articles by pasting URLs or sharing from other apps
- **Link Previews**: Automatic fetching of title, description, and images
- **Share Sheet Integration**: Share links directly from Chrome, YouTube, Twitter, etc.
- **Offline Storage**: All data stored locally using Hive database
- **Read Tracking**: Mark articles as read/unread
- **Smooth UI**: 60fps animations with Material Design 3

## Getting Started

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Dart SDK
- Android Studio / Xcode
- Physical Android device or emulator (API 21+)

### Installation

1. Clone the repository:
```bash
cd personal_news_assistant
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run code generation for Hive adapters:
```bash
dart run build_runner build
```

4. Run the app:
```bash
flutter run
```

### Building for Release

#### Android APK:
```bash
flutter build apk --release
```

#### Android App Bundle (for Play Store):
```bash
flutter build appbundle --release
```

## Play Store Setup

1. Create a Google Play Developer account
2. Create a new app in Play Console
3. Generate a signing keystore:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

4. Configure signing in `android/key.properties`
5. Upload to Internal Testing track

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/               # Data models (Hive)
│   └── news_article.dart
├── services/             # Business logic
│   ├── link_preview_service.dart
│   └── news_repository.dart
├── providers/            # Riverpod state management
│   └── news_provider.dart
├── screens/              # UI screens
│   ├── home_screen.dart
│   ├── add_article_screen.dart
│   └── article_detail_screen.dart
└── widgets/              # Reusable widgets
    └── link_preview_card.dart
```

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Database**: Hive (NoSQL)
- **HTTP Client**: Dart http
- **Image Caching**: cached_network_image
- **Share Receiver**: receive_sharing_intent

## License

Personal use only.
