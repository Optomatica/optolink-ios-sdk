# Changelog

The SDK runs its own semver clock: `0.x` while pre-stable, `1.0` when confident. A breaking change in the backend surface also forces an SDK major — the backend has no API versioning, so the SDK treats it as an uncontrolled external dependency. This file mirrors the changelog page on the OptoLink docs site (`sdk/ios/changelog`).

## 0.2.0

Clipboard leg behaviour change plus one additive API, `OptoLinkData.queryParams`.

- `OptoLinkData.queryParams: [String: String]?` — the query embedded in `path`, parsed (e.g. `["uuid": "18f0"]` for `/event?uuid=18f0`; `nil` when none). Derived from `path` only, never merged with `params`, not part of the Codable payload. Form-encoding rules: `+` is a space, the last duplicate key wins, empty keys and `#fragment` are ignored, a malformed escape keeps its raw text. `path` itself is unchanged and still delivered verbatim.
- No clipboard wipe: the SDK clears the pasteboard only when it extracted an `opl_` token, the `POST /match` call returned (hit or miss; a thrown match keeps the token for `resolveDeferredLink()`), and `UIPasteboard.changeCount` is unchanged since the read. Empty, denied, or non-OptoLink clipboard content is never cleared, and neither is anything the user copied after the read. Same rule in `resolveDeferredLink()`.
- The `changeCount` check and the clear run as one main-actor step, so an in-app Copy that lands after `POST /match` returns is never wiped by the clear.
- The `detectPatterns(.probableWebURL)` silent gate now runs on every supported version (iOS 15 included); the iOS 15 plain read on first launch is gone. A gate error still counts as closed (no read).
- Note (unchanged from 0.1.0): if the first-launch `POST /match` fails, the token stays on the clipboard, so a later `resolveDeferredLink()` reads it again and the system "Allow Paste" alert can appear a second time.

**Compatible with OptoLink backend v2.1.0+.**

## 0.1.0

Initial release.

- Deferred deep linking: once-per-install match on `initialize` (backend ladder: clipboard → fingerprint exact/scored → IP fuzzy), `resolveDeferredLink()` for manual re-attempt. Match failure is logged, never thrown — startup never blocks.
- Direct link ingestion: one entry point `handle(url:)` for both Universal Links (`onContinueUserActivity`) and custom schemes (`onOpenURL`); safe before init (parks the URL, flushes after — deferred first, parked second).
- `links`: `AsyncStream<OptoLinkData>` per access, replay-last, never errors or finishes. Route gating (e.g. until onboarding ends) = subscribe when ready; replay-last delivers the held link.
- Identity + events: `setIdentity(externalId:)`, `clearIdentity()`, `trackEvent(name:properties:)` — throwing trio, success implicit.
- Config: `OptoLinkConfig` (`apiKey` CLIENT-tier `opl_sdk_…`, `orgKey`, `baseUrl: URL`, `timeout` 10 s, `maxRetries` 2, `clipboardEnabled` default on, optional `OptoLinkLogger`).
- Error model: `OptoLinkApiError` (HTTP — `status`, `requestId`, `details`, `retryAfterSeconds` regexed from 429, `raw`) and `OptoLinkConnectionError` (transport). Unknown match-method wire values decode to `.none`.
- Retry matrix: reads retry on connection errors, 429 (sleeping the body-communicated `retryAfterSeconds`), and 5xx; writes never retry on 5xx. Shared per-call budget.
- Device identity: persisted UUID v4 (UserDefaults); `dispose()` test reset. No ATT prompt, no IDFA.
- Logging: `OptoLinkLogLevel.info` (alongside `warning`/`error`) — the SDK logs its decision trail at `info` (init summary with a redacted key, match attempt/response, per-rung deferred-leg decisions, per-attempt request lines + retry backoff, link emissions, telemetry successes) for live-test observability.
- `OptoLinkData.score: Int?` — the backend's `matchScore` (present only on `FINGERPRINT_SCORED` matches) surfaces instead of being dropped; `nil` everywhere else.
- Privacy manifest `PrivacyInfo.xcprivacy` shipped as a `.copy` resource.
- Zero dependencies (Foundation/URLSession only); Swift 6-friendly (`Sendable` payloads, actor-isolated core); iOS 15+, tools 5.9.

**Compatible with OptoLink backend v2.1.0+.**

Known iOS platform limits (full list in the README): no install referrer on iOS — deferred attribution rides clipboard + fingerprint + IP only; the clipboard leg is user-gesture-bound; `IP_FUZZY` degrades under Private Relay/VPN/shared IPs; the match body deliberately omits `timezone`.
