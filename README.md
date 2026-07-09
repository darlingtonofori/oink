# SMS Gateway

Self-hosted SMS gateway with a textbee-style UI: Dashboard, Messages, and
Settings tabs, backed by your own VPS instead of someone else's cloud.

## App structure

- **Dashboard** - device status, Gateway on/off, Receive SMS on/off, live
  sent/received/failed counts, link to your server's `/dashboard` page.
- **Messages** - All/Sent/Received tabs pulled from an on-device log, plus a
  compose button for sending a one-off SMS directly (bypasses the server).
- **Settings** - Device ID, Server URL, API key, Device name, Disconnect,
  Receive SMS, Poll interval, Send delay, Configure filters (allow/block
  list for incoming numbers), Sticky notification, About.

## How it works

- **Inbound**: SMS received on this phone -> forwarded to `{server}/api/inbound`
  (unless blocked by your filter settings).
- **Outbound**: phone polls `{server}/api/pending` every poll interval, sends
  via this SIM (with your configured delay between each), reports back to
  `{server}/api/status`.
- Your own backend queues messages by POSTing to `{server}/api/send` - see
  `server_example/server.js` for a matching Node.js backend with Groq AI
  auto-reply, Pollinations.ai image generation, and a live web dashboard.

## Push to GitHub + build via Actions

```bash
cd sms_gateway
git init
git add .
git commit -m "textbee-style UI: dashboard, messages, settings"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

Grab `app-release.apk` from the Actions tab -> the run -> Artifacts.

## Known build config (don't change without reason)

- Gradle 8.6 / AGP 8.3.0 / Kotlin 1.9.22 - matched to Flutter 3.22.x's own
  build tooling. Mismatching these three causes cryptic "Language version
  X no longer supported" errors from Flutter's own Gradle plugin, not your
  code.
- `minSdkVersion 23` - required by `flutter_foreground_task`. Lowering this
  breaks the manifest merge.
- `flutter_foreground_task` 6.5.0's `TaskHandler` callbacks take a
  `SendPort?` second parameter (`onStart`, `onRepeatEvent`, `onDestroy`) -
  newer/older versions of this package use a different signature
  (`TaskStarter`, or no second param at all). If you bump this package's
  version, check `~/.pub-cache/hosted/pub.dev/flutter_foreground_task-*/lib/models/task_handler.dart`
  for the actual signature first.
- `telephony` is unmaintained; no namespace declared in its own manifest,
  which is why `android/build.gradle` has a `subprojects` block injecting
  one automatically for AGP 8+.

## Project structure

```
lib/
  main.dart
  screens/
    root_nav_screen.dart      bottom nav shell (Dashboard/Messages/Settings)
    dashboard_screen.dart
    messages_screen.dart
    settings_screen.dart
  services/
    config_service.dart       shared_preferences wrapper (server, device, toggles)
    local_log_service.dart    on-device sent/received history
    filter_service.dart       allow/block list for incoming numbers
    api_service.dart          HTTP calls to your VPS
    gateway_controller.dart   permissions + start/stop + SMS listeners
    gateway_task_handler.dart background poll/send loop
android/                      AGP 8.3.0, Gradle 8.6, Kotlin 1.9.22, minSdk 23
server_example/server.js      Node backend: gateway API + Groq AI + image gen + dashboard
.github/workflows/build.yml   CI build -> APK artifact
```
