# DriveBrief - CarPlay Notification Summarizer

A Flutter iOS app with CarPlay integration that summarizes your notifications and sends them via SMS using Teli AI.

## Overview

DriveBrief is a hackathon project that demonstrates:
- **CarPlay Integration**: A minimal, driving-safe UI with a single action button
- **Teli AI Integration**: Summarizes notifications into concise, safe-to-read briefings
- **SMS Delivery**: Sends the summary to your phone via Teli SMS API
- **Flutter + Native Bridge**: Seamless communication between Flutter and native iOS CarPlay

## Features

- 📱 **Flutter App**: Full-featured phone interface with notification viewer, status display, and debug logs
- 🚗 **CarPlay Support**: One-tap summary generation from your car's display
- 🔒 **Sensitive Content Handling**: Automatic redaction of bank alerts, 2FA codes, etc.
- 📊 **Priority Sorting**: High-priority notifications are summarized first
- 📝 **Action Items**: AI-generated list of follow-up tasks

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CarPlay Simulator                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           "Send Summary Text" Button                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ MethodChannel (carplay_bridge)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Notifications│  │   Teli AI   │  │   Teli SMS          │ │
│  │   Service    │──▶│ Summarizer  │──▶│   Sender            │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Teli AI API   │
                    └─────────────────┘
```

## Prerequisites

- **macOS** with Xcode 15+
- **Flutter** 3.0+ installed and configured
- **iOS Simulator** (iOS 15.0+)
- **Teli API Key** (provided for hackathon)

## Quick Start

### 1. Clone and Setup

```bash
cd CarPlaySafety/flutter_app

# Install Flutter dependencies
flutter pub get

# Create .env file from template
cp .env.example .env
```

### 2. Configure API Key

Edit `.env` file:
```
TELI_API_KEY=hackathon-sms-api-key-h4ck-2024-a1b2-c3d4e5f67890
TELI_API_BASE_URL=https://api.teli.ai
```

### 3. iOS Setup

```bash
cd ios
pod install
cd ..
```

### 4. Run the App

```bash
# Open iOS simulator
open -a Simulator

# Run Flutter app
flutter run -d <simulator-id>
```

### 5. Enable CarPlay Simulator

1. In the iOS Simulator, go to **I/O → External Displays → CarPlay**
2. A CarPlay window will appear
3. Find the **DriveBrief** app icon and tap it
4. Tap **"Send Summary Text"** to trigger the workflow

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   ├── notification.dart     # Notification model
│   │   ├── summary_response.dart # AI summary model
│   │   ├── teli_credentials.dart # API credentials
│   │   └── sms_result.dart       # SMS result model
│   ├── services/
│   │   ├── notification_service.dart  # JSON loading
│   │   ├── teli_service.dart          # Teli API client
│   │   ├── logger_service.dart        # Debug logging
│   │   ├── app_state.dart             # State management
│   │   └── carplay_bridge.dart        # Native bridge
│   └── screens/
│       ├── home_screen.dart           # Main UI
│       ├── notifications_screen.dart  # Notification list
│       └── debug_screen.dart          # Debug logs
├── ios/
│   └── Runner/
│       ├── AppDelegate.swift          # iOS app delegate
│       ├── CarPlaySceneDelegate.swift # CarPlay UI
│       ├── CarPlayBridge.swift        # Native bridge
│       ├── Info.plist                 # CarPlay config
│       └── Runner.entitlements        # CarPlay entitlement
├── assets/
│   └── notifications.json             # Sample notifications
├── test/
│   ├── notification_test.dart
│   ├── summary_response_test.dart
│   ├── sensitive_redaction_test.dart
│   └── summarizer_request_test.dart
├── .env.example                       # Environment template
└── pubspec.yaml                       # Dependencies
```

## Flutter App Features

### Home Screen
- **Phone Number Input**: Enter your E.164 formatted phone number (+1234567890)
- **Include Sensitive Toggle**: Enable/disable sensitive content in SMS
- **Test Send Summary**: Manually trigger the workflow (same as CarPlay tap)
- **Status Display**: Shows last SMS status and errors
- **Last Summary**: Displays the generated summary text and action items

### Notifications Screen
- **Grouped by Category**: Work, personal, finance, etc.
- **Priority Indicators**: Color-coded by urgency
- **Sensitive Badges**: Visual indicator for redacted content
- **Detail View**: Tap to see full notification details

### Debug Screen
- **Live Logs**: Real-time logging of all operations
- **Copy/Clear**: Export logs for debugging
- **Error Highlighting**: Errors shown in red

## CarPlay Interface

The CarPlay UI is intentionally minimal for driving safety:

1. **App Icon**: DriveBrief appears on CarPlay home
2. **Single Action**: "Send Summary Text" button
3. **Status Feedback**: Shows "Sending...", "Sent ✓", or "Failed ✗"

## API Integration

### Teli AI Endpoints Used

```
POST /v1/organizations           # Create organization (bootstrap)
POST /v1/organizations/{id}/users # Create user (bootstrap)
POST /v1/agents                  # Create SMS agent (bootstrap)
POST /v1/chat/completions        # Generate summary
POST /v1/sms/send                # Send SMS
POST /v1/campaigns               # Fallback SMS method
```

### Summary Format

The AI generates JSON with:
- `sms_text`: ≤480 characters for SMS
- `narration_script`: 30-60 second read-aloud script
- `action_items`: 0-5 follow-up tasks

## Sensitive Content Handling

Notifications marked `sensitive: true` are automatically redacted:

| Field | Original | Redacted |
|-------|----------|----------|
| title | "Transaction Alert" | "Sensitive alert from Chase Bank" |
| body | "$500 at Amazon" | "[Content redacted for privacy]" |
| sender | "Chase" | "Redacted" |

Enable "Include Sensitive" toggle to send full content (at your own risk).

## Testing

Run unit tests:

```bash
flutter test
```

Tests cover:
- ✅ JSON notification parsing
- ✅ Sensitive content redaction
- ✅ Summary response validation
- ✅ Summarizer request formatting

## Troubleshooting

### CarPlay Not Showing

1. Ensure `Info.plist` has CarPlay scene configuration
2. Check `Runner.entitlements` has CarPlay entitlement
3. Restart the iOS Simulator

### MethodChannel Not Working

The app includes a fallback mechanism:
1. Native CarPlay writes to `UserDefaults`
2. Flutter polls on app resume
3. Check Debug logs for "Fallback trigger detected"

### API Errors

1. Verify `.env` has correct API key
2. Check network connectivity
3. Review Debug screen for detailed error messages

## Hackathon Notes

- **Notifications are simulated** via `notifications.json` - no real iOS Notification Center access
- **Teli API access** is provided for the hackathon
- **CarPlay requires Apple Developer entitlement** for production deployment

## License

Hackathon project - MIT License
