# OptoLink iOS SDK

Deferred deep linking + click attribution for iOS. Swift Package Manager binary
distribution, zero dependencies beyond Foundation/URLSession; floor iOS 15 (tools 5.9).

**Compatible with OptoLink backend v2.1.0+.**

## Install

```swift
dependencies: [
    .package(url: "https://github.com/Optomatica/optolink-ios-sdk.git", from: "0.2.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "OptoLink", package: "optolink-ios-sdk"),
    ]),
]
```

```swift
import OptoLink
```

The package resolves anonymously — no SSH keys, tokens, or netrc entries. This
repository is a **releases-only mirror**: it carries the prebuilt `OptoLink.xcframework`
(binaries for iOS, iOS Simulator, and macOS), not source code.

## Quick start

One config, one init, both ingestion surfaces, one collector:

```swift
import OptoLink

@main
struct MyApp: App {
    init() {
        Task {
            await OptoLink.initialize(config: OptoLinkConfig(
                apiKey: "opl_sdk_…",                 // CLIENT-tier key (portal → API keys)
                orgKey: "your-org",
                baseUrl: URL(string: "https://api.optolink.app")!
            ))
        }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
            .onOpenURL { OptoLink.instance().handle(url: $0) }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { OptoLink.instance().handle(url: url) }
            }
    }
}
```

```swift
// Route matched links — e.g. in your root view:
Task { for await link in OptoLink.instance().links { route(link) } }
```

Notes:

- `initialize` is idempotent and concurrency-safe (first config wins). It awaits the
  once-per-install deferred match; a network failure there is **logged, not thrown** — startup
  never blocks. Re-attempt later with `try await OptoLink.instance().resolveDeferredLink()`
  (returns `nil` on no match).
- `handle(url:)` is safe before `initialize` — an early URL parks and is flushed after init
  (deferred link first, parked URL second).
- `links` is a fresh `AsyncStream<OptoLinkData>` per access with replay-last semantics: the
  latest emitted link is delivered even when you subscribe after the emission. It never errors
  and never finishes.
- To delay routing (e.g. until onboarding finishes), subscribe to `links` only when ready —
  replay-last delivers the held link then. The SDK never opens anything on the app's behalf.

## Capabilities

| Capability | Surface | Notes |
| --- | --- | --- |
| **Direct links** | `handle(url:)` → `links` | Universal Links (primary) and custom-scheme URLs both go through the one entry point; resolves `{orgKey}/{shortCode}` to link data via the backend. |
| **Deferred deep linking** | once-per-install on `initialize`; `resolveDeferredLink()` for manual re-attempt | Deterministic clipboard token only: the backend runs no fingerprint or IP matching for Apple platforms. The pasteboard is cleared only when it held our token, nothing was copied since, and `/match` succeeded. No install referrer exists on iOS (see Limitations). |
| **Identity** | `setIdentity(externalId:)`, `clearIdentity()` | Throwing trio; success is implicit. |
| **Events** | `trackEvent(name:properties:)` | String name + `[String: String]` properties; oversize payloads surface as `OptoLinkApiError`. |

Every matched link carries `OptoLinkData`: `linkId`, `path` (verbatim; may carry a query),
`params`, `queryParams` (the query embedded in `path`, parsed; `nil` when none), `matchMethod`
(`CLIPBOARD` / `FINGERPRINT_EXACT` / `FINGERPRINT_SCORED` / `IP_FUZZY` / `DIRECT` / `NONE`),
`confidence`, `isDeferred`. Errors are `OptoLinkApiError` (HTTP, carries `status`,
`requestId`, `retryAfterSeconds`) and `OptoLinkConnectionError` (transport). Wire in an
`OptoLinkLogger` via `OptoLinkConfig.logger` to see warnings/errors. `dispose()` resets state
(tests only). `clipboardEnabled` defaults to `true`; opt out in the config.

## Universal Links setup

Universal Links are the primary ingestion entry. Add the associated-domains entitlement with
your org's link domain:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:go.demo.optolink.io</string>
</array>
```

The `apple-app-site-association` file is served by the OptoLink backend from the org's IOS
AppConfig (`bundleId`, `teamId`, paths). A custom scheme may be registered as a fallback
entry; the SDK treats any URL through `handle(url:)` identically.

`https://api.optolink.app` (used in the snippets) is the **chosen public default, not live
anywhere today** — point `baseUrl` at your OptoLink backend for real matches.

## Limitations

- **No install-referrer channel exists on iOS.** The App Store carries no referrer, so all
  deferred attribution rides the clipboard token. FDL-style guarantees are impossible by
  platform design; a user who bounces to the App Store before the redirect page's user-gesture
  clipboard write fires gets no deferred match (direct links are unaffected).
- **The clipboard leg is user-gesture-bound.** The copy happens via the redirect page's copy
  affordance, not a silent background write. On every supported version (iOS 15+) the SDK
  first checks silently via `detectPatterns` and reads only when a web URL is present; the
  system paste prompt then appears once. Declining leaves the pasteboard untouched.
- **Timezone asymmetry is deliberate.** The iOS match body omits `timezone` (Safari's click
  side stores none); Android sends IANA tz — the two collectors are intentionally different.
  Flutter integrators additionally take a scored-path `deviceModel` penalty (a lower
  fingerprint score) until the Flutter plugin converts to this SDK.
- **Custom-scheme fallback links carry no Universal Link security** — any app can claim a
  scheme; the SDK treats scheme URLs as raw-direct data only.
- **Universal Link verification is delivery-gated:** on-device AASA verification needs the
  org's link-domain DNS + Apple-CDN AASA publication to land (backend/ops side); the SDK
  itself is unaffected.

## License

Proprietary — see [LICENSE](LICENSE). No right to use, copy, modify, or distribute this
software is granted except under a valid written agreement with Optomatica (for example, an
OptoLink subscription or SDK license agreement). For licensing inquiries, contact Optomatica.
