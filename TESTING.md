# Verification

Tested with Jac 0.37.23 in WSL on October 4, 2026.

| Check | Status |
|---|---|
| Backend persistence, streaks, validation, proposals, editing, pause/resume | 12 tests passed |
| Live Gemini onboarding and two-journey extraction | Passed using synthetic data in a temporary database |
| Web journey creation and milestone check-in | Passed in browser |
| Web Gemini chat → review → save | Passed in browser |
| Immediate pending chat bubble, failed-request draft restoration, optional setup/voice button | Passed in browser |
| Unrelated coding ignored; explicit gardening creation without questionnaire | Passed against live Gemini in isolated temporary database |
| CLI reads web journal, logs yesterday's progress, calculates 2-day streak | Passed |
| Mobile browser UI | Passed: shared journal, history and two-day streak; bundle built successfully |
| Native Expo scaffold and native source compilation | Prepared successfully |
| Android APK | Pending SDK license acceptance; initial Gradle attempt stopped at that gate |
| Live microphone recognition/transcription | Needs human microphone test |
| Device reminder delivery while closed | Needs native device test |

Temporary browser/CLI QA data is identified separately from real user data and removed after verification. The assignment has not been submitted. Keys and local journal data are excluded from the public source repository. No site or mobile app was deployed.

The full live integration rerun encountered a Gemini HTTP 503; the focused two-request regression then passed. Existing earlier full integration pass is retained above.
