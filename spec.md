# DriveBrief Hackathon – Master Build Prompt

> **API KEY (for demo only):** `hackathon-sms-api-key-h4ck-2024-a1b2-c3d4e5f67890`

---

## Prompt to the “All‑Powerful AI Model”

Build a complete, runnable hackathon project that implements the following.

---

## Goal

Create an **iOS app built primarily in Flutter** that includes a **CarPlay component**.

When the user taps the app icon on **CarPlay** (in the CarPlay Simulator), the app:

1. Loads a **local JSON list of simulated notifications** (provided in the repo)
2. Sends those notifications as **context to Teli AI** to produce a concise, **driving‑safe summary** (30–60 seconds)
3. Uses **Teli SMS** to send the user a **text message containing the summary**
4. Shows **status + the last summary** inside the Flutter app on the phone

---

## Hackathon Assumptions

* Unlimited free **Teli AI** access
* Demo will use **Xcode CarPlay Simulator** on macOS
* **No real iOS Notification Center access** — notifications are simulated via JSON

---

## Non‑Goals / Constraints

* ❌ Do **NOT** attempt to read iOS Notification Center or other apps’ notifications
* ✅ Keep CarPlay UI **extremely minimal & driving‑safe**

  * Essentially one action: **“Generate & Text Summary”**
* The **CarPlay tap must trigger the workflow**

  * If CarPlay cannot directly invoke Flutter code, implement a **small native iOS bridge** via `MethodChannel` or shared storage

---

## Deliverables (Must Output All of This)

A **full GitHub‑ready repository** with:

```
/flutter_app/        # Flutter project
/ios/                # Native iOS runner with CarPlay support
/backend_optional/   # Only if absolutely necessary (prefer none)
README.md
```

Additional requirements:

* Sample JSON file with **15–30 notifications**
* Working **CarPlay Simulator integration**

---

## CarPlay Requirements

* A **CarPlay app icon** appears on the CarPlay Simulator home
* Opening it shows a simple UI with **one primary action**:

  * **“Send Summary Text”**
* Tapping triggers:

  * Summarization
  * SMS send

---

## Teli API Integration

**Base URL**

```
https://api.teli.ai
```

**Header**

```
X-API-Key: YOUR_API_KEY
```

---

## Configuration & Secrets

* ❌ Never hardcode API keys
* Use `.env` or config files excluded by `.gitignore`
* On iOS:

  * Load via `.xcconfig` or runtime environment

---

## Flutter UI Requirements

Flutter home screen must show:

* User **phone number input** (E.164)
* **“Test Send Summary”** button (runs workflow without CarPlay)
* Scrolling view of **JSON notifications**
* **Last summary** text
* **Last SMS status** with timestamps & API errors

---

## Error Handling (Required)

* Graceful failures with **user‑readable messages**
* Network timeouts
* Invalid phone number handling
* API error response parsing

---

## Logging

* Log every step:

  * Load JSON → Summarize → Send SMS → Success/Fail
* Show logs inside Flutter in a **debug panel**

---

## Architecture Requirements

### Flutter Handles

* Reading JSON notifications from assets
* Calling the **summarize** function
* Calling the **send SMS** function
* Displaying results

### iOS Native Handles

* CarPlay templates
* Triggering workflow

### Flutter ↔ iOS Bridge

* Use a `MethodChannel` named:

```dart
carplay_bridge
```

* Native CarPlay tap calls:

```dart
invokeMethod("sendSummaryFromCarPlay")
```

* Flutter receives call and runs workflow

#### Fallback (If Needed)

* Native writes a timestamp trigger to `UserDefaults`
* Flutter polls on resume / foreground
* Primary path must still attempt `MethodChannel`

---

## JSON Notification Simulator

File location:

```
flutter_app/assets/notifications.json
```

Example structure:

```json
[
  {
    "id": "n1",
    "app": "Slack",
    "sender": "Sam",
    "title": "Build blocked",
    "body": "CI failing on main. Can you take a look?",
    "timestamp": "2026-01-31T11:45:00-05:00",
    "priority": "high",
    "category": "work",
    "sensitive": false
  }
]
```

Include diverse sources:

* Slack
* Email
* Calendar
* Messages
* Weather
* Bank alerts (**sensitive**)
* 2FA alerts (**sensitive**)

### Sensitive Handling

* If `sensitive=true`:

  * ❌ Do not include raw content
  * Use phrasing like: *“Sensitive alert from {app}”*
* Sensitive items:

  * Redacted in narration
  * Omitted from SMS unless user enables **“Include sensitive”** toggle

---

## Teli AI Integration (Must Implement)

### Bootstrap (Idempotent)

On first run:

1. Create organization
2. Create user
3. Create SMS agent
4. Store IDs securely

On later runs:

* Reuse stored IDs

### Endpoints (Ground Truth)

```
POST /v1/organizations
{
  "name": "...",
  "contact_email": "..."
}
```

```
POST /v1/organizations/{org_id}/users
{
  "name": "...",
  "email": "...",
  "permission": "admin"
}
```

```
POST /v1/agents
{
  "agent_type": "sms",
  "agent_name": "DriveBrief Summarizer",
  "starting_message": "...",
  "prompt": "...",
  "organization_id": "...",
  "user_id": "..."
}
```

### SMS Sending

* Prefer **direct transactional SMS endpoint** if available
* Otherwise use:

```
POST /v1/campaigns
```

* Single contact campaign
* Dynamically set `starting_message` to summary

Reliability > elegance (hackathon rules)

---

## Summarizer Prompt (Required)

The summarizer **must return JSON** with:

* `sms_text` (≤ 480 chars)
* `narration_script` (≤ 60 seconds)
* `action_items` (0–5 items)

### Rules

* Redact sensitive notifications
* Prioritize:

  1. High priority
  2. Most recent
  3. Group by category

### Prompt Template

```
You are DriveBrief, an assistant that converts a list of incoming notifications
into a driving-safe briefing.

Output strictly valid JSON with keys:
- sms_text
- narration_script
- action_items

Keep sms_text under 480 characters.
Keep narration_script under 60 seconds.

If sensitive=true, redact the content and say
"Sensitive alert from {app}" instead.
```

---

## CarPlay Implementation (Must Implement)

* Use native **iOS CarPlay templates**
* Provide CarPlay scene in `Info.plist`
* Implement `CPTemplateApplicationSceneDelegate`

### UI

* `CPListTemplate`
* One item:

  * **Title:** Send Summary Text
  * **Subtitle:** Ready / Last run time

### On Tap

* Trigger Flutter workflow via `MethodChannel`
* Show temporary **“Sending…”** state
* Update subtitle:

  * **Sent ✓** or **Failed ✗**

If callback sync is hard:

* Native shows *Triggered*
* Flutter app shows definitive result

---

## Flutter Implementation Details

* Use `http` package for REST
* Use `flutter_dotenv` for secrets
* Use `shared_preferences` or secure storage for:

  * `org_id`
  * `user_id`
  * `agent_id`
  * `last_summary`
  * `last_status`

### Pages

* Home (inputs + actions + status)
* Notifications viewer
* Debug logs

### Toggles

* **Include sensitive content in SMS** (default OFF)

---

## README – Run Instructions (Must Be Thorough)

### Prereqs

* Flutter
* Xcode
* iOS Simulator

### Steps

1. `flutter pub get`
2. Set **Teli API key** in `.env`
3. Run iOS simulator
4. Open CarPlay simulator:

   * iOS Simulator → **I/O → External Displays → CarPlay**
5. Tap CarPlay icon

Mention limitation:

* Notifications are JSON‑simulated for hackathon

---

## Quality Bar

* ✅ Code must compile
* ❌ No placeholder TODOs for core features
* ✅ Unit tests required for:

  * JSON parsing
  * Sensitive redaction logic
  * Summarizer request formatting

---

## Final Instruction to AI Model

**Now generate the full repository contents**, including:

* All code files
* All configuration templates
* README
* Sample JSON
* Any scripts needed

❌ Do NOT output explanations

✅ Output the **repository file tree**, followed by **each file’s full contents**
