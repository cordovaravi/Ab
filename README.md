# WorldOS Browser — The Action Browser

> The browser doesn't ask *"What do you want to search?"* — it asks **"What do you want to get done?"**

WorldOS is a Flutter app that reframes the browser as a **digital workforce layer**: you state an
*intention*, and a team of micro-agents searches the web, analyzes sources, runs reality checks,
makes a decision, and presents it for your approval — turning websites into **outcomes**.

It runs **on-device** using LiquidAI's **LFM2-1.2B** (Q4 GGUF) as the agent brain via
[llamadart](https://llamadart.leehack.com/), with a background "google scraper" brain for sourcing.

---

## What's here (MVP)

- **Intention bar** instead of an address bar — type a goal, not a URL.
- **Workspaces, not tabs** — each objective becomes a mission with status, sources, and a verdict.
- **Micro-agent orchestrator** — Search / Price / Review / Fraud / Compare / Decision agents
  coordinated by `Orchestrator` (`lib/services/orchestrator.dart`).
- **Background scraper brain** — `ScraperService` scrapes Google → falls back to DuckDuckGo →
  falls back to high-quality simulated results, so the pipeline always produces something to reason over.
- **Reality Check layer** — flags marketing claims ("best price", "limited time", inflated ratings).
- **Decision engine** — produces Verdict / Reasons / Risks / Avoid / Next action, not blue links.
- **Human-time-saved dashboard** — the metric that matters: minutes recovered, tasks, comparisons.
- **Approval gate + Negotiation drafting** — nothing final happens without you; draft a negotiation
  message in one tap.
- **Persistent memory** — user profile ("personal twin"), past intentions, website behavior,
  time-saved stats via `MemoryService` (`shared_preferences`).

## Architecture

```
User intention
      │
      ▼
  AppBrain (Provider, lib/providers/app_state.dart)
      │  orchestrator.processIntention(text)  → Stream<OrchestratorEvent>
      ├──────────────┬───────────────┐
      ▼              ▼               ▼
 LlamaService    ScraperService   MemoryService
 (LFM2-1.2B Q4)  (Google/DDG)     (profile, stats)
      │
      ▼
  Orchestrator: parse → search → analyze → compare → decide → reality-check → time-saved
      │
      ▼
  Workspace UI (screens/workspace_screen.dart): agents, sources, verdict, [Approve] [Negotiate]
```

| Layer | File |
|---|---|
| Entry / splash | `lib/main.dart` |
| Theme | `lib/core/theme.dart` |
| Domain models | `lib/models/models.dart` |
| On-device LLM | `lib/services/llama_service.dart` |
| Scraper brain | `lib/services/scraper_service.dart` |
| Orchestrator | `lib/services/orchestrator.dart` |
| Memory | `lib/services/memory_service.dart` |
| App state | `lib/providers/app_state.dart` |
| Screens | `lib/screens/home_screen.dart`, `workspace_screen.dart` |
| Widgets | `lib/widgets/widgets.dart` |

## Status — read this

The app runs **end-to-end immediately** in *simulated mode*: `LlamaService` returns intelligent,
context-aware structured responses parsed from the prompt, and `ScraperService` returns curated
fallback results when live scraping is blocked. Every feature (agents, decision, reality checks,
negotiation, dashboard) works on first launch.

**Two pieces to wire for full "real" operation** (clearly marked in code):
1. **Real on-device inference** — in `LlamaService._loadModel` / `generate`, replace the simulation
   with the actual engine call. The model URL/filename (`LFM2-1.2B-Q4_0.gguf`) and the
   download-with-progress flow are already in place. Note: `pubspec.yaml` lists `llama_cpp_dart`;
   you can also use the [`llamadart`](https://pub.dev/packages/llamadart) package
   (`LlamaEngine`/`ChatSession`) — both target llama.cpp GGUF.
2. **Live scraping reliability** — Google often blocks server-side scraping; the DuckDuckGo HTML
   fallback is more permissive. For robustness, a future version can scrape inside a `WebView`
   (rendered DOM) instead of raw HTTP.

## Setup & Run

This repo contains the Dart sources, `pubspec.yaml`, and config. Generate the native platform
folders once, then run:

```bash
# From the repo root — generates android/ (and other platforms) WITHOUT overwriting lib/ or pubspec.
flutter create . --project-name worldos_browser --platforms=android

flutter pub get
flutter run            # Android device/emulator recommended for on-device LLM
```

Desktop also works: `flutter create . --platforms=linux,macos,windows` then `flutter run -d <device>`.

### Android configuration

After `flutter create .`, apply these edits:

**`android/app/src/main/AndroidManifest.xml`** — permissions above `<application>`, and flags on it:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<application
    android:label="WorldOS Browser"
    android:largeHeap="true"
    android:usesCleartextTraffic="true"
    ... >
```

`largeHeap` matters: the Q4 1.2B model plus context needs room — target mid/high-end devices.

**`android/app/build.gradle`** (or `build.gradle.kts`):

```gradle
android {
    defaultConfig {
        minSdkVersion 24
        targetSdkVersion 34
        ndk { abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64' }
    }
}
```

## Roadmap (from the manifesto)

Universal form brain · workflow record/replay · time-travel page diffs · website memory selectors ·
business-portal automation (login → download report → extract tables → fill forms → export Excel/email).

---

*Built around one metric: how many human minutes did this remove?*
