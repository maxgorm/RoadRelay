# DriveBrief - Hackathon Project

> CarPlay-enabled iOS app that summarizes your notifications and sends them via SMS using Teli AI.

## Quick Start

See [flutter_app/README.md](flutter_app/README.md) for detailed setup instructions.

```bash
cd flutter_app
flutter pub get
cp .env.example .env
# Edit .env with your API key
cd ios && pod install && cd ..
flutter run
```

## Demo

1. Run the Flutter app on iOS Simulator
2. Open CarPlay: **I/O → External Displays → CarPlay**
3. Tap **DriveBrief** icon
4. Tap **"Send Summary Text"**
5. Check your phone for the SMS!

## Project Structure

```
CarPlaySafety/
├── flutter_app/      # Main Flutter + iOS project
│   ├── lib/          # Flutter Dart code
│   ├── ios/          # Native iOS + CarPlay
│   ├── assets/       # Sample notifications JSON
│   └── test/         # Unit tests
├── spec.md           # Original project specification
└── README.md         # This file
```

## Features

- 🚗 **CarPlay Integration** - Single-tap summary from your car
- 🤖 **Teli AI Summarization** - Smart, priority-based briefings  
- 📱 **SMS Delivery** - Get your summary on your phone
- 🔒 **Privacy First** - Sensitive content auto-redacted
- 📊 **Debug Tools** - Full logging and status tracking

## Tech Stack

- **Flutter** 3.0+ with Provider state management
- **Swift** for native iOS CarPlay
- **Teli AI API** for summarization and SMS
- **MethodChannel** for Flutter ↔ Native communication

## Hackathon Context

Built for the DriveBrief Hackathon. Notifications are simulated via JSON (no iOS Notification Center access). Uses provided Teli API key for demo purposes.
