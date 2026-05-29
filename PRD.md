# PRD — Headlessone (a WebKit browser, for macOS)

> **Audience:** an executor LLM ("Agent 007") building this app one
> vertical slice at a time, driven by the 007-builder orchestrator.
> Every design decision is pre-resolved. **Do not invent behavior,
> endpoints, or libraries.** If something is unspecified, stop and ask
> the product owner.

---

## 0. Reading order

1. Read §1–§6 once, fully, before writing code.
2. Read **§7 (HTTP test API)** and **§8 (architectural invariants)**
   before *every* slice. The quality review enforces §8 mechanically;
   the feature check exercises §7.
3. Every behavior MUST be reachable from the HTTP test API and MUST obey
   the MVC contract (§8.14 + `.agent/skills/mvc-appkit.md`). A behavior
   reachable only by clicking is, for this project, untestable and
   therefore unbuilt.
4. **A browser is networked and async, but the feature check asserts
   exact states from a fixed, loopless probe sequence.** Two rules make
   that work and are non-negotiable: navigation is **synchronous** (it
   resolves only after the load settles, §8.15) and feature tests run
   against **offline fixtures**, never the live internet (§8.15).

---

## 1. Product Overview

### 1.1 What we are building
A native macOS web browser named **Headlessone** built on the system
**WKWebView** (WebKit). One window with a **tab strip**, an **omnibox**
(URL + search), back/forward/reload/stop, **find-in-page**, persistent
**history** and **bookmarks**, a **downloads** manager, and a **safe
encrypted password vault** with autofill. Styling is native macOS.

The defining feature is that **everything is drivable and assertable
over a localhost HTTP test API**, deterministically — which is what the
007-builder pipeline requires and what the name nods to.

### 1.2 In scope
- System **WKWebView** rendering (one engine, no bundled core).
- **Tabs** in a single window: new / close / activate / reorder; each
  tab owns its own WKWebView.
- **Omnibox**: resolves input to a URL or a DuckDuckGo search; navigates
  the active tab.
- Navigation: back, forward, reload, stop; per-tab load state.
- **Find-in-page** (WKWebView find) with match count + next/prev.
- Persistent **history** (url/title/visitedAt) with list/search/clear.
- Persistent **bookmarks** (add/list/delete).
- **Downloads** via WKDownload (start/list/cancel) to `~/Downloads`.
- **Password vault**: AES-GCM encrypted file, key derived from a master
  password (PBKDF2); save/list/get/delete + autofill into matching page
  forms.
- A bundled **`fixture://` scheme** serving offline HTML for
  deterministic tests, plus a `fixture://newtab` start page.
- An embedded localhost **HTTP test API** (§7) driving every feature,
  with `WKWebView.takeSnapshot`-based page screenshots.

### 1.3 Out of scope (deferred, §10)
Multiple windows; session/tab restore; extensions; iCloud/sync; reader
mode; developer tools; content blockers / ad-block; a custom PDF viewer
beyond WebKit's; multiple user profiles; private-browsing UI toggle (the
data store is persistent in normal mode); live-web dependence in tests;
custom app icon.

### 1.4 Success criteria
Headlessone browses real sites via WKWebView, manages tabs, autofills
saved credentials, and **every feature is verifiable through the HTTP
test API against offline fixtures — deterministically and repeatably.**

---

## 2. Tech Stack (locked, do not deviate)

| Item | Choice |
| --- | --- |
| Language | Swift 5.9+ |
| UI framework | AppKit. SwiftUI permitted for panels/controls; the web content is `WKWebView`. |
| Web engine | System **WebKit** (`WKWebView`). No bundled browser core. |
| Project gen | **XcodeGen** (`Project.yml`). The `.xcodeproj` is generated each build and git-ignored. |
| Build | `xcodegen generate && xcodebuild -scheme Headlessone -configuration Debug -derivedDataPath build/ build` |
| Min macOS | 13.0 |
| Architecture | Universal (arm64 + x86_64) |
| Third-party deps | **None.** Standard library, AppKit, SwiftUI, WebKit, `CryptoKit`, CommonCrypto, `Network.framework`. |
| Crypto | `CryptoKit` (AES-GCM) + CommonCrypto (PBKDF2). No third-party crypto. |
| HTTP server | Hand-rolled over `Network.framework` (`NWListener`). No web frameworks. |
| Entry point | Explicit `Headlessone/main.swift` calling `NSApplication.shared.run()`. **No `@main`** (§8.1). |
| Window | Standard titled `NSWindow` with real traffic lights. |
| Bundle ID | `com.bimboware.headlessone` |

---

## 3. Project Structure

Every user-visible feature is an `NSViewController` that owns its model,
its view, **and its HTTP routes** (§8.14, `.agent/skills/mvc-appkit.md`).
Routes live in an extension on the controller in the same file. **Model
/ store types MUST NOT `import AppKit`.**

```
Headlessone/
├── main.swift                          # NSApplication.shared.run()
├── AppDelegate.swift                   # instantiates AppController
│
├── App/
│   ├── AppController.swift             # /healthz, /shutdown, /screenshot
│   ├── MenuBuilder.swift               # macOS menu bar
│   └── TestAPI/
│       ├── TestAPIServer.swift         # NWListener HTTP listener
│       ├── TestAPIRouter.swift         # flat registry; controllers register
│       └── TestAPIRequest+Response.swift
│
├── Window/
│   ├── WindowController.swift          # /window/list
│   ├── WindowState.swift
│   ├── HeadlessoneWindow.swift         # NSWindow subclass
│   ├── RootView.swift                  # toolbar + tab strip + content + find bar layout
│   └── ToolbarView.swift               # back/fwd/reload/stop buttons (forward to active TabController)
│
├── Tabs/
│   ├── TabsController.swift            # /tabs/*  (list,new,close,activate,reorder)
│   ├── TabsState.swift                 # ordered tab ids + active id (no AppKit)
│   ├── TabStripView.swift
│   └── TabButton.swift
│
├── Tab/
│   ├── TabController.swift             # /tab/*  (navigate,back,forward,reload,stop,state,eval)
│   ├── WebTab.swift                    # one WKWebView + WKNavigationDelegate + per-tab state
│   └── ContentAreaView.swift           # hosts the active tab's WKWebView
│
├── Omnibox/
│   ├── OmniboxController.swift         # /omnibox/*  (submit,state) — URL-vs-search resolution
│   ├── OmniboxState.swift
│   └── OmniboxView.swift
│
├── Find/
│   ├── FindController.swift            # /find/*  (start,next,prev,close)
│   └── FindBarView.swift
│
├── History/
│   ├── HistoryController.swift         # /history/*  (list,search,clear); records on navigation
│   └── HistoryStore.swift              # persisted JSON store (no AppKit)
│
├── Bookmarks/
│   ├── BookmarksController.swift       # /bookmarks/*  (list,add,delete)
│   └── BookmarksStore.swift
│
├── Downloads/
│   ├── DownloadsController.swift       # /downloads/*  (list,start,cancel) via WKDownload
│   └── DownloadsStore.swift
│
├── Passwords/
│   ├── PasswordController.swift        # /password/*  (unlock,lock,save,list,get,delete,autofill)
│   ├── Vault.swift                     # AES-GCM + PBKDF2 encrypted store (CryptoKit/CommonCrypto, no AppKit)
│   └── Autofill.swift                  # JS to fill matching forms in the active page
│
├── Data/
│   └── DataController.swift            # /data/clear (cookies/cache/history/bookmarks/passwords/all)
│
├── Web/
│   ├── WebConfig.swift                 # shared WKWebViewConfiguration + data store (persistent | test-ephemeral)
│   └── FixtureSchemeHandler.swift      # fixture:// → bundled Fixtures/*.html (offline, deterministic)
│
├── Fixtures/                           # bundled test HTML (newtab, login form, long text, links, a file to download)
│
└── Theme/
    ├── Metrics.swift
    └── Palette.swift
```

Do not create files outside this list without a controller home. Do not
add a top-level route (only the orchestrator routes `/healthz`,
`/shutdown`, `/screenshot` are top-level, §7.3).

---

## 4. Layout & UI

Native macOS chrome. Top to bottom: **toolbar** (back / forward / reload
/ stop on the left, **omnibox** centered, an overflow/menu affordance on
the right), **tab strip**, **content area** (the active tab's
WKWebView), and a slide-down **find bar** (hidden until invoked).

### 4.1 Metrics (`Theme/Metrics.swift`)
```swift
enum Metrics {
    static let toolbarHeight: CGFloat = 38
    static let tabStripHeight: CGFloat = 30
    static let findBarHeight: CGFloat = 30
    static let tabMinWidth: CGFloat = 80
    static let tabMaxWidth: CGFloat = 220
    static let navButton: CGFloat = 28
    static let defaultWindowSize = NSSize(width: 1100, height: 760)
}
```

### 4.2 Tab strip (`Tabs/TabStripView.swift`)
- Horizontal row of tabs; active tab highlighted; each shows favicon
  placeholder + title (or URL host) + a close (×). A `+` adds a new tab.
- Always ≥ 1 tab. Closing the last tab opens a fresh `fixture://newtab`
  tab (§8.17).

### 4.3 Omnibox (`Omnibox/OmniboxView.swift`)
- Single text field. On submit (`/omnibox/submit` or Return), resolve:
  1. If the text has a scheme (`http`, `https`, `file`, `fixture`,
     `data`) → navigate as-is.
  2. Else if it looks like a host (`localhost`, an IP, or a dotted name
     with no spaces) → prepend `https://` and navigate.
  3. Else → DuckDuckGo search: `https://duckduckgo.com/?q=<escaped>`.
- The omnibox shows the active tab's current URL when not editing.

### 4.4 Menus (`App/MenuBuilder.swift`)
App menu (`Headlessone`): About, Quit. Then **File** (New Tab ⌘T, Close
Tab ⌘W, New Window — deferred), **Edit** (standard), **View** (Reload
⌘R, Stop ⌘., Find ⌘F), **History** (Back ⌘[, Forward ⌘], Show History,
Clear History), **Bookmarks** (Add ⌘D, Show Bookmarks). Every item maps
to the same controller action the test API invokes.

---

## 5. Behavior

### 5.1 Tabs (`Tabs/TabsController.swift`, `TabsState.swift`)
Ordered list of tabs with an active id. New tab opens `fixture://newtab`
(or a supplied URL). Activating swaps which WKWebView is visible in the
content area. Closing tears down the tab's WKWebView + delegate (§8.17).

### 5.2 A tab (`Tab/WebTab.swift`, `TabController.swift`)
Each tab owns one `WKWebView` built from the shared `WebConfig` and a
`WKNavigationDelegate` that updates the tab's state (`url`, `title`,
`loadState ∈ {idle,loading,finished,failed}`, `canGoBack`,
`canGoForward`, `progress`) and records a history visit on `didFinish`.
`TabController` exposes navigate / back / forward / reload / stop / state
/ eval for the active tab (or a `tabId`). **Navigate is synchronous**
(§8.15): it returns only after `didFinish`/`didFail` or a 15s timeout.

### 5.3 Find-in-page (`Find/FindController.swift`)
Uses WKWebView's find API. `start{query}` highlights matches and returns
`{matchCount, activeMatch}`; next/prev cycle; close clears highlights.

### 5.4 History (`History/HistoryController.swift`, `HistoryStore.swift`)
On each successful navigation, append `{url, title, visitedAt}` to the
persisted store. API: list (most-recent first), search by substring,
clear.

### 5.5 Bookmarks (`Bookmarks/*`)
Persisted `{id, url, title, addedAt}`. API: list, add, delete.

### 5.6 Downloads (`Downloads/*`)
WKDownload-based. `start{url}` begins a download to `~/Downloads`
(tests use a `fixture://` file so it's offline + deterministic); list
reports `{id, url, filename, state ∈ {running,finished,failed,canceled},
bytesReceived}`; cancel stops one.

### 5.7 Password vault (`Passwords/*`)
- **At rest:** a single AES-GCM encrypted file in Application Support.
  The symmetric key is derived from the master password via **PBKDF2**
  (SHA-256, ≥ 200k iterations, random per-vault salt). Nonce per
  encryption. No plaintext on disk.
- **Session:** `unlock{master}` derives the key and decrypts into memory;
  `lock` drops the key. Entries are `{origin, username, password}`,
  keyed by `(origin, username)`.
- **Autofill:** `autofill` injects the saved credential for the active
  tab's origin into the page's username/password form fields via JS
  (`Autofill.swift`).
- **Save prompt:** on a form submit in normal use, offer to save; in
  tests, `save` writes directly.

### 5.8 Data clearing (`Data/DataController.swift`)
`clear{types}` wipes any of: cookies/cache/localStorage (via
`WKWebsiteDataStore`), history, bookmarks, passwords, or `all`.

---

## 6. Profile & persistence

- **Normal mode:** persistent `WKWebsiteDataStore.default()` (cookies,
  cache, localStorage); history, bookmarks, and the password vault
  persist under `~/Library/Application Support/Headlessone/`. **No
  session restore** — each launch opens a single fresh
  `fixture://newtab` tab.
- **Test mode** (`HEADLESSONE_TEST_API=1`): a **non-persistent**
  `WKWebsiteDataStore` and **isolated, empty** history / bookmarks /
  downloads / vault under a temp directory — never the real profile, so
  every run starts clean and reproducible (§8.7).

---

## 7. Testability (the HTTP test API)

### 7.1 Why
Headless, deterministic verification is the contract. `osascript` /
`CGEvent` synthetic input silently no-ops without permission. Every
behavior is reachable via HTTP on `127.0.0.1`; the feature check uses
HTTP only. Because the browser is async + networked, two rules make it
deterministic: **synchronous navigation** (§8.15) and **offline
fixtures** (§8.15).

### 7.2 Enabling the API
- Binds when `HEADLESSONE_TEST_API=1` is in the environment. Default off.
- Port is OS-chosen (`:0`) and written to
  `~/Library/Application Support/Headlessone/test-api.port` (decimal,
  newline-terminated) **before** the listener accepts connections.
- Handlers run off the main queue but `DispatchQueue.main.sync` before
  touching WebKit/AppKit (WKWebView is main-thread-only; §8.12).
- Enabling the API also switches the app to the **isolated test
  profile** (§6, §8.7).

### 7.3 Required endpoints
Organised by owning controller. Every route is `/<prefix>/<action>`; the
only top-level routes are the three orchestrator routes `/healthz`,
`/shutdown`, `/screenshot`. JSON unless noted; errors return
`{"error":"..."}` with a 4xx/5xx.

#### App (`AppController`) — top-level orchestrator routes
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| GET | `/healthz` | — | `{"ok":true}` | Readiness probe |
| POST | `/shutdown` | — | `{"ok":true}` | `NSApp.terminate(nil)` after responding |
| GET | `/screenshot` | `?region=window` (default) | `image/png` | Window PNG: chrome via `cacheDisplay` composited with the active tab's `WKWebView.takeSnapshot` (§7.6, §8.13). Orchestrator calls with no query. |

#### Window (`WindowController`)
| Method | Path | Response | Purpose |
|---|---|---|---|
| GET | `/window/list` | `[{"id":"w1","title":"Headlessone","isKey":true}]` | Window inventory |

#### Tabs (`TabsController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| GET | `/tabs/list` | — | `[{"id":"t1","title":"New Tab","url":"fixture://newtab","active":true}]` | All tabs |
| POST | `/tabs/new` | `{"url":"fixture://newtab"}` (optional) | `{"ok":true,"id":"t2"}` | Open + activate a new tab |
| POST | `/tabs/close` | `{"id":"t2"}` | `{"ok":true}` | Close a tab (last → fresh newtab) |
| POST | `/tabs/activate` | `{"id":"t1"}` | `{"ok":true}` | Make a tab active |
| POST | `/tabs/reorder` | `{"id":"t2","index":0}` | `{"ok":true}` | Move a tab |

#### Tab (`TabController`) — acts on the active tab, or `tabId` if given
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| POST | `/tab/navigate` | `{"url":"fixture://login","tabId":"t1"}` | `{"ok":true,"url":"...","title":"...","loadState":"finished"}` | **Synchronous**: returns after load settles (§8.15) |
| POST | `/tab/back` | `{}` | `{"ok":true}` | Go back |
| POST | `/tab/forward` | `{}` | `{"ok":true}` | Go forward |
| POST | `/tab/reload` | `{}` | `{"ok":true}` | Reload (synchronous) |
| POST | `/tab/stop` | `{}` | `{"ok":true}` | Stop loading |
| GET | `/tab/state` | `?tabId=t1` | `{"tabId":"t1","url":"...","title":"...","loadState":"finished","canGoBack":true,"canGoForward":false,"progress":1.0}` | Tab state mirror |
| POST | `/tab/eval` | `{"js":"document.title"}` | `{"result":"Login"}` | `evaluateJavaScript` for content assertions |

#### Omnibox (`OmniboxController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| POST | `/omnibox/submit` | `{"text":"duckduckgo.com"}` | `{"ok":true,"navigatedTo":"https://duckduckgo.com/"}` | Resolve URL-vs-search (§4.3) + navigate active tab (synchronous) |
| GET | `/omnibox/state` | — | `{"text":"fixture://newtab"}` | Current omnibox text |

#### Find (`FindController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| POST | `/find/start` | `{"query":"hello"}` | `{"matchCount":3,"activeMatch":1}` | Begin find on active tab |
| POST | `/find/next` | `{}` | `{"activeMatch":2}` | Next match |
| POST | `/find/prev` | `{}` | `{"activeMatch":1}` | Previous match |
| POST | `/find/close` | `{}` | `{"ok":true}` | Clear + hide |

#### History (`HistoryController`)
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| GET | `/history/list` | — | `[{"url":"...","title":"...","visitedAt":"ISO8601"}]` | Most-recent-first |
| GET | `/history/search` | `?q=login` | `[...]` | Substring match |
| POST | `/history/clear` | `{}` | `{"ok":true}` | Wipe history |

#### Bookmarks (`BookmarksController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| GET | `/bookmarks/list` | — | `[{"id":"b1","url":"...","title":"..."}]` | All bookmarks |
| POST | `/bookmarks/add` | `{"url":"...","title":"..."}` | `{"ok":true,"id":"b1"}` | Add |
| POST | `/bookmarks/delete` | `{"id":"b1"}` | `{"ok":true}` | Delete |

#### Downloads (`DownloadsController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| GET | `/downloads/list` | — | `[{"id":"d1","url":"...","filename":"file.bin","state":"finished","bytesReceived":1024}]` | All downloads |
| POST | `/downloads/start` | `{"url":"fixture://file.bin"}` | `{"ok":true,"id":"d1"}` | Start (synchronous to a terminal state for fixtures) |
| POST | `/downloads/cancel` | `{"id":"d1"}` | `{"ok":true}` | Cancel |

#### Password (`PasswordController`)
| Method | Path | Body / Query | Response | Purpose |
|---|---|---|---|---|
| POST | `/password/unlock` | `{"master":"hunter2"}` | `{"ok":true}` | Derive key + decrypt vault into memory |
| POST | `/password/lock` | `{}` | `{"ok":true}` | Drop the key |
| POST | `/password/save` | `{"origin":"https://x.test","username":"a","password":"p"}` | `{"ok":true}` | Store a credential |
| GET | `/password/list` | `?origin=https://x.test` | `[{"origin":"...","username":"a"}]` | Metadata (no plaintext) |
| GET | `/password/get` | `?origin=&username=` | `{"password":"p"}` | **Plaintext read-back. Test-only** — the server runs only under the test env, so this is unreachable in shipped builds (§8.16). |
| POST | `/password/delete` | `{"origin":"...","username":"a"}` | `{"ok":true}` | Remove |
| POST | `/password/autofill` | `{"tabId":"t1"}` (optional) | `{"ok":true,"filled":true}` | Inject the saved credential for the active tab's origin into the page form |

#### Data (`DataController`)
| Method | Path | Body | Response | Purpose |
|---|---|---|---|---|
| POST | `/data/clear` | `{"types":["cookies","cache","history","bookmarks","passwords","all"]}` | `{"ok":true}` | Wipe browsing data |

New controllers MAY add prefixes; new behavior MUST belong to a
controller — never a top-level route.

### 7.4 Per-issue contract
Each `slice` issue body carries an `acceptance:` JSON block of HTTP
probes. Example — "omnibox navigates to a fixture and the title reads
back" (offline, deterministic):
```json
{
  "acceptance": [
    {"step": "navigate-and-read-title",
     "calls": [
       {"method":"POST","path":"/omnibox/submit","body":{"text":"fixture://login"}},
       {"method":"GET","path":"/tab/state","expect":{"url":"fixture://login","loadState":"finished"}},
       {"method":"POST","path":"/tab/eval","body":{"js":"document.title"},"expect":{"result":"Login"}}
     ]}
  ]
}
```
The feature check fails the issue if any `expect` assertion fails.
(Array responses like `/tabs/list` are matched with order-independent
containment; objects by key-subset.)

### 7.5 Security
The listener binds only to `127.0.0.1`, no auth, opt-in via
`HEADLESSONE_TEST_API=1` (an env var, not a build flag). Because the
server exists only in test mode, the vault read-back endpoint
(`/password/get`) is unreachable in shipped builds.

### 7.6 Self-screenshot
`/screenshot` composes, **in-process**: the window chrome via
`contentView.bitmapImageRepForCachingDisplay` → `cacheDisplay(in:to:)`,
and the active tab's page pixels via `WKWebView.takeSnapshot(with:)`
(a WebKit in-process API), drawn into the content-area rect. It MUST NOT
call `CGWindowListCreateImage`, `CGDisplayCreateImage`, `NSScreen`
grabs, or `screencapture` (all TCC-gated). It must work the moment
`HEADLESSONE_TEST_API=1` is set, with zero permission prompts.
(`cacheDisplay` alone does not capture out-of-process WKWebView content —
that is why the page is captured via `takeSnapshot`.)

---

## 8. Architectural invariants

The code-quality review uses this list as its checklist; any violation
blocks the PR.

### 8.1 Entry point
Explicit `Headlessone/main.swift` constructs `NSApplication.shared`,
assigns the delegate, calls `setActivationPolicy(.regular)`, and
`app.run()`. `@main` on an `NSApplicationDelegate` is forbidden.

### 8.2 Tab / web-view model
Each tab owns exactly one `WKWebView` built from the shared
`Web/WebConfig` configuration; the active tab's web view fills the
content area and switching tabs swaps the visible web view. Tab/history/
bookmark/download/vault state lives in plain model/store types that do
not `import AppKit`/`WebKit`.

### 8.3 Single navigation path
Omnibox submit, toolbar buttons, menu items, and the `/tab` + `/omnibox`
routes all funnel through `TabController`'s navigate/back/forward/reload/
stop. Views forward intent to the active controller; no duplicated
navigation logic.

### 8.4 Image loading
`NSImage(imageLiteralResourceName:)` is forbidden. Use failable
`NSImage(named:)` with a non-trapping fallback.

### 8.5 Callback re-entrancy
A method that "set active tab / set omnibox text / set load state"
updates state only; it MUST NOT re-emit the user-action callback the
app uses to *request* that same change.

### 8.6 Window
Standard titled `NSWindow` with real traffic lights, title `Headlessone`
(or the active tab's title). Any `.borderless` subclass overrides
`canBecomeKey`/`canBecomeMain`.

### 8.7 Network & profile isolation
WKWebView may use the network (it is a browser); that is allowed. But:
in **normal** mode the profile is persistent
(`WKWebsiteDataStore.default()` + stores under Application Support); in
**test** mode (env set) the app MUST use a **non-persistent** data store
and **isolated, empty** history/bookmarks/downloads/vault under a temp
dir, never the real profile. The only listener is the loopback test
server. **Feature tests MUST NOT depend on the live internet** (§8.15).

### 8.8 Force-unwrap discipline
`try!`, `as!`, and `!`-on-optionals are forbidden except: `NSScreen.main`
(guard + fallback); `URL(string:)` of compile-time literals; the
`bitmapImageRepForCachingDisplay`/`representation(using:)` pair in §7.6.

### 8.9 Test API parity
Every PR adding user-visible behavior MUST extend the owning
controller's routes so the behavior is reachable and assertable via
HTTP. A new feature with no probe path fails review.

### 8.10 Silent failure
`catch { /* ignore */ }` is forbidden. Errors propagate or surface an
`NSAlert` on the main queue. WKWebView load failures set
`loadState=failed`, never swallowed.

### 8.11 Notifications & observers
Closures stored by `NotificationCenter`/KVO (e.g. `estimatedProgress`)
capture `self` weakly; observers are removed on teardown.

### 8.12 Main-queue / WebKit threading
`WKWebView` is main-thread-only. Test API handlers run on a background
queue and `DispatchQueue.main.sync` before touching WebKit/AppKit.
Async WebKit results (`evaluateJavaScript`, `takeSnapshot`, navigation)
are bridged to the synchronous HTTP response with a bounded wait.

### 8.13 Self-screenshot only
`/screenshot` uses only the in-process path in §7.6 (`cacheDisplay` +
`WKWebView.takeSnapshot`). Any `CGWindowListCreateImage`/
`CGDisplayCreateImage`/`screencapture`/TCC-gated API is a blocker.

### 8.14 Controller owns its routes (MVC)
Every user-visible feature lives in an `NSViewController` under
`Headlessone/<Feature>/<Name>Controller.swift`, conforming to
`TestAPIControllerRoutes` and registering its routes in `viewDidLoad`.
Route handlers live in an extension on the controller in the same file —
never a shared routes file. Views MUST NOT reference `TestAPIRouter`/
`URLSession`/HTTP types. Models/stores MUST NOT `import AppKit`/`WebKit`.
Top-level routes forbidden except `/healthz`, `/shutdown`, `/screenshot`.

### 8.15 Deterministic navigation & offline fixtures
`/tab/navigate`, `/tab/reload`, and `/omnibox/submit` resolve only after
the navigation settles (`didFinish`/`didFail` or a 15s timeout) — never
fire-and-forget. **Feature-test probes MUST target offline fixtures**
(`fixture://…` served by `FixtureSchemeHandler` from bundled HTML, or
`file://`/`data:`) — never live URLs, which are flaky and
non-deterministic. The `fixture://` scheme and the bundled `Fixtures/`
set are part of the contract.

### 8.16 Vault security
Passwords are encrypted at rest with AES-GCM; the key is derived from
the master password via PBKDF2 (SHA-256, ≥200k iterations, random salt),
using only system frameworks. Plaintext exists only in memory while
unlocked and only crosses the loopback test API (which runs only in test
mode). Plaintext MUST NOT be written to logs, history, or any
unencrypted file.

### 8.17 Tab lifecycle
There is always ≥1 tab; closing the last opens a fresh
`fixture://newtab`. Closing a tab tears down its `WKWebView`, navigation
delegate, and KVO observers (no leaks). The active-tab id is always
valid.

---

## 9. The orchestrator's contract
(Informational; not implemented by coding agents.)
- Issues are labelled `slice`, numbered `S1`, `S2`, …
- `S1` ≈ "app launches via `main.swift`, shows a window with one
  `fixture://newtab` tab, `GET /healthz` → 200, `GET /window/list` →
  one entry, `GET /tabs/list` → one tab, `GET /screenshot` → a PNG."
- Good early slices: window + one tab → `fixture://` scheme + newtab page
  → `/tab/navigate` (synchronous) + `/tab/state` → `/tab/eval` →
  omnibox URL-vs-search resolution → tab strip new/close/activate →
  back/forward/reload/stop → find-in-page → history record + list →
  bookmarks → downloads (fixture file) → vault unlock/save/list/get →
  autofill into a login fixture → `/data/clear`.
- Each issue cycles `code-agent → xcodebuild → feature-test →
  quality-review`; failure bumps `attempt:N`; at the cap the
  orchestrator hands off for human review.

---

## 10. Out of v1, deferred
Multiple windows; session/tab restore; extensions; sync; reader mode;
developer tools; content blockers / ad-block; custom PDF UI; multiple
profiles; a private-browsing toggle; live-web in tests; custom app icon;
favicons beyond a placeholder.

End of PRD.
