# WorldOS Browser — The Action Browser (V1)

> The browser doesn't ask *"What do you want to search?"* — it asks **"What do you want to get done?"**

WorldOS reframes the browser as a **digital workforce layer**. V1 has two halves that share one brain:

1. **Intent Workspace** — state a goal; a micro-agent orchestrator searches the web, analyzes
   sources, runs reality checks, decides, and proposes actions for your approval.
2. **Action Browser** — a real WebView that **reads** each page it loads (injected JS extracts text,
   links, buttons, inputs, forms), **suggests** actions, and **executes** them: fill forms from your
   profile, click elements, extract links — all on the live page.

On-device LLM via [llamadart](https://llamadart.leehack.com/) (LiquidAI **LFM2-1.2B** Q4 GGUF).

## Architecture

```
lib/
  main.dart                       splash + app root
  core/theme.dart
  models/models.dart              Workspace, AgentTask, Decision, ExecAction, PageStructure, ...
  services/
    llama_service.dart            on-device LLM (honest "Simulation Mode" / "LFM2-1.2B Local")
    scraper_service.dart          DuckDuckGo → Google → simulated fallback
    webview_agent_service.dart    the browser's "eyes": JS injection + page parser  (SINGLE source)
    action_executor.dart          fill/click/submit/email/export — audited, approval-gated
    workflow_recorder.dart        record → replay multi-page workflows
    orchestrator.dart             intent pipeline + analyzePage() for browser mode
    memory_service.dart           profile (personal twin) + time-saved stats
  providers/app_state.dart        AppBrain (provider) — wires it all together
  screens/
    home_screen.dart              intention bar, time-saved dashboard, Browser entry (FAB)
    browser_screen.dart           the real Action Browser (WebView + page info + action panel)
    workspace_screen.dart         agents, sources, reality checks, verdict, proposed actions
  widgets/widgets.dart
```

**Flow:** Intent → `Orchestrator.processIntention` → search/analyze/decide → **Workspace** with a
verdict + proposed actions → *Open in Action Browser* hands the recommended URL to `BrowserScreen`,
which reads the page and lets you execute real actions (approval-gated).

## Honest status

- **On-device inference is stubbed.** `LlamaService` runs in **Simulation Mode** — context-aware,
  genuinely-parsed structured output (it reads your intention/page text), labeled honestly in the UI.
  To go live, uncomment the `llama_cpp_dart` calls in `LlamaService._loadModel` / `generate` (the
  download-with-progress flow and model path are already wired).
- **The browser is real.** WebView navigation, JS page extraction, form-fill and button-click
  execution all run for real against live pages. Search scraping is real (DuckDuckGo HTML), with a
  Google attempt and a simulated fallback when blocked.
- **State-changing actions are approval-gated** and written to an audit log.

## Setup & Run

```bash
# From the repo root — generates the rest of android/ without overwriting lib/, pubspec, or the manifest.
flutter create . --project-name worldos_browser --platforms=android
flutter pub get
flutter run            # Android device/emulator recommended
```

`android/app/src/main/AndroidManifest.xml` is included (INTERNET permission + `largeHeap` for the
on-device model). For `build.gradle`, set `minSdkVersion 24` and add
`ndk { abiFilters 'arm64-v8a','armeabi-v7a','x86_64' }`.

## Verify

`flutter run` → splash → home. Tap **Browser**, load a real site, hit the **eye** to read the page
(counts of links/buttons/inputs/forms appear), expand the strip, type an intention, and try
**Fill Forms** / **Extract Links** / **Interact**. Or type an intention on home → open the resulting
workspace → **Open in Action Browser**. `flutter test` runs the model unit tests.
