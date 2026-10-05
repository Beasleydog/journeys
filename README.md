# Journeys

A personal planning app built in Jac 0.37.23 with a shared server, web app, native mobile app, and CLI.

**Author:** Sam Schneider
**UMID:** 20371995

## What it does

- The home page is a conversational daily compass. Describe a skill you want to learn or a commitment you want to keep; the Gemini coach works with what you share. Motivation, current level, goals and daily time are optional. New journeys require an explicit creation request; unrelated activities in daily recaps do not create journeys.
- Each journey has a realistic daily practice and a tiny minimum step for busy days.
- Ramble about your day. The coach maps actual progress to the right journeys and proposes dated check-ins. Review before saving; intentions never count as completed work.
- Each journey has its own tab, searchable timeline, milestone markers, mood, minutes, next step, and a 28-day visual trail.
- Streaks count distinct consecutive dates. Yesterday's streak stays alive until today's chance has passed. Multiple check-ins don't inflate it. Missed days reset the streak and preserve your history.
- Pause, resume, or complete journeys. Edit check-ins to correct dates or details. Export the complete journal as JSON.
- Use **Describe your goals by voice** in the journey form to switch directly to chat dictation. Sent messages appear immediately while the coach responds; failed requests restore the draft. Voice supports live browser dictation and recorded audio transcription with Gemini. Both produce an editable draft before sending.
- Optional browser reminders work while the app is open. The native app schedules local reminders for the next seven days, skips days already logged, and cancels/reschedules them on refresh or check-in.

## Run in WSL

Use **Linux Jac 0.37.23**, including through WSL on Windows. Clone this repository into your Linux filesystem, for example `~/projects/journeys`.

```bash
git clone https://github.com/beasleydog/journeys.git ~/projects/journeys
cd ~/projects/journeys
jac --version
jac install
cp .env.example .env    # only for a fresh checkout; preserve an existing .env
# Set GEMINI_API_KEY in .env. Do not put it in frontend code.
jac run
```

Open **http://localhost:8000** in Chrome or Edge. `jac run` starts the web app and server from the root. The development default includes hot reload; restart the server after backend changes. `jac run --no-dev` serves a prepared bundle.

Each checkout needs a `.env` with its own Gemini API key. Credentials and local journal data are excluded from Git and are never included in the exported application bundle. The configured model is `gemini-3.1-flash-lite`; Google offers a free tier subject to account quotas. Manual journeys and logging work without Gemini.

The server is bound to `127.0.0.1` by default. This is a single-person local journal without login; keep it local. Planning data persists in `data/journeys.sqlite3`. Back up that file or export your journal. `JOURNEYS_DB` can select another SQLite file for tests or demos.

## Web and voice

Use **Plan a journey** to begin onboarding, or the **＋** button to create a journey directly. Click a journey tab to browse or edit its history. Use **Check in** for a manual log.

In Chrome/Edge, **Dictate → Live dictation** displays words while you speak. Allow microphone access, stop when done, review the text, and send. Browser recognition can use the browser vendor's speech service. If live recognition is unavailable, choose **Recorded voice · Gemini**, record, stop, and review the returned transcript. Recordings are sent to Google's Gemini API for transcription; they are not saved in the journal. Use localhost or HTTPS for microphone access.

**Settings** controls browser reminders and JSON export. Browser reminders require notification permission and an open app. They are device-local, once per pending journey per day. Choose the native app for reminders that can arrive while the app is closed.

## Mobile

The mobile app uses Jac's `mobile` kind and `@jac/mobui`, compiling to native React Native views through Expo. It provides today's steps, per-journey streaks, journal history, manual check-ins, shared chat/review, and optional local notifications. It uses the same Jac `journey_api` and SQLite planning data as the web and CLI.

First verify the screens in a browser:

```bash
cd ~/projects/journeys
jac run                    # keep the shared backend running
# Another WSL terminal:
jac run --no-dev --platform web --port 8002 mobile
```

If switching from an Android build to the browser preview, run `jac clean --cache --force` first so Jac selects the web reminder module. This clears compiler cache, not journal data.

Or build the mobile browser bundle:

```bash
jac build --platform web mobile
```

For a native device:

```bash
jac setup mobile
# Android: review and accept the required SDK licenses interactively
jac setup --toolchain android
jac run --dev mobile       # Expo/Metro; use the printed device instructions
# Or build an Android APK:
jac build --platform android mobile
```

Jac provisions its managed JDK and Android tools. Android setup requires accepting the SDK licenses. See `TESTING.md` for mobile verification status.

For a phone, the backend must be reachable from that phone. For LAN testing, explicitly run the server with `jac run --host 0.0.0.0` on your trusted network and use the dev host/port printed by Jac. WSL/Windows port forwarding or firewall setup may be needed. Do not publish this unauthenticated personal server. iOS builds require macOS/Xcode or a separately configured hosted builder.

On the **reminders** tab choose an hour and minute, then enable notifications. Scheduling uses `expo-notifications`; preferences use `expo-secure-store`. Enabling schedules the next seven days. Each refresh or mobile check-in replaces only Journeys reminders, omitting already recorded dates. Pausing a journey removes its reminders after sync. Turn reminders off/on after changing the time. Check-ins made on web or CLI require the mobile app to refresh before their pending notification is cancelled. Reopen the app periodically to extend its seven-day schedule. Device power restrictions can delay local delivery.

## CLI

Keep `jac run` running in another WSL terminal. The CLI talks to that server over HTTP rather than maintaining a separate journal.

```bash
jac run cli today
jac run cli list
jac run cli create 'Learn piano' --minimum 'Practice one chord for two minutes' --minutes 15 --goal 'Play one favorite song'
jac run cli log 'Learn piano' 'Practiced C and G chords slowly' --minutes 12
jac run cli log 'Learn piano' 'Reviewed chord shapes' --day 2026-10-03 --minutes 5
jac run cli history 'Learn piano'
jac run cli chat 'Today I practiced piano for 12 minutes and reviewed 10 French words.'
# Chat prints a review ID; save only after reviewing its actions:
jac run cli commit REVIEW_ID
jac run cli status 'Learn piano' paused
jac run cli status 'Learn piano' active
jac run cli export > journeys-backup.json
jac run cli --help
```

Use an exact journey title or an ID from `list`. Configure `JOURNEYS_SERVER` or pass `--server http://localhost:8000` before the subcommand for another server.

## Tests

```bash
jac check core.jac web.jac cli/main.jac mobile/main.jac
jac test tests/core_tests.jac
# Optional live Gemini integration test: consumes a few API requests
jac run --no-serve tests/live_ai.jac
# Focused creation-permission and optional-onboarding regression:
jac run --no-serve tests/chat_regression.jac
```

The 12 deterministic backend tests isolate their databases in temporary folders. They cover persistence, independent streaks, unique-day counting, missed days, invalid data, idempotent review, atomic multi-journey review, dismissal, editing dates, and pause/resume/history retention. The live test covers onboarding, journey creation, extraction for two journeys, refusal to count a future intention, and review/save using synthetic data. It does not alter your journal.

Browser checks cover journey creation, milestone check-in, timeline navigation, live Gemini chat suggestions, save/review, and CLI-to-web shared progress. Mobile browser and native build status is recorded in `TESTING.md`. Microphone quality and device notification delivery require human/device checks and are not asserted as automated passes.

## How the four pieces fit

```text
Jac web UI ───────┐
Jac mobile UI ────┼── Jac journey_api ── SQLite journeys / entries / messages / proposals
Jac CLI ──────────┘          │
                            └── Gemini Flash-Lite: coaching and audio transcription
```

`core.jac` owns validation, persistence, daily calculations and Gemini calls. `web.jac` owns the browser interaction. `mobile/main.jac` uses native UI primitives and platform-specific reminder modules. `cli/main.jac` provides terminal workflows. `jac.toml` declares the workspace and selects the web app as the default. The API key remains entirely server-side.
