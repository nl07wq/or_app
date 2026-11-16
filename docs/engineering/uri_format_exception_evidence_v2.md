# URI FormatException Evidence V2

## Incident and status

Incident: `ORAPP-WEB-URI-2026-11`
Current status: **root cause unresolved; production capture implemented**.

Production releases repeatedly reported a minified `FormatException` near
`main.dart.js:7299:8`. Two observations occurred 118–164 ms after an unnamed
route was popped and `/system` was pushed. That timing is a correlation, not a
confirmed cause. `/system` is a valid URI and the VM Navigator reproduction did
not fail.

## Confirmed source path

The deployed Flutter 3.44.6 source path is:

1. `SystemNavigator.routeInformationUpdated`
2. `SystemChannels.navigation` (`flutter/navigation`)
3. Web engine `EnginePlatformDispatcher.sendPlatformMessage`
4. `EngineFlutterWindow.handleNavigationMessage`
5. `Uri.parse(arguments['uri'])`

The relevant SDK sources are:

* `packages/flutter/lib/src/services/system_navigator.dart`
* `packages/flutter/lib/src/widgets/navigator.dart`
* `engine/src/flutter/lib/web_ui/lib/src/engine/platform_dispatcher.dart`
* `engine/src/flutter/lib/web_ui/lib/src/engine/window.dart`

Normal framework route reporting converts a `Uri` back to a string before the
message is sent. No direct application call that supplies a raw malformed
`uri` value was found. Therefore neither `/system` nor any application route is
currently established as the producer of the invalid input.

## Instrumentation boundary

`NavigationDiagnosticWidgetsFlutterBinding` overrides the supported
`ServicesBinding.createBinaryMessenger()` extension point. Its messenger
observes only outgoing `flutter/navigation` bytes, decodes a copy with the same
`JSONMethodCodec`, and delegates the original `ByteData` unchanged and in FIFO
order. This boundary is immediately before the engine handler above, and covers
framework-internal route reports that a `NavigatorObserver` cannot see.

The capture records:

* session, event ID, monotonic sequence and UTC time;
* method, original URI string, UTF-16LE code-unit Base64 and length;
* replace flag and bounded history-state metadata;
* browser URL metadata and recent application navigation;
* exception metadata and message-to-error time;
* release, Flutter framework and engine revisions, and browser identity.

The UI displays only summaries. Full raw evidence is available only through a
local, user-initiated SYSTEM diagnostics copy/export. No external upload exists.
The UTF-16LE representation preserves the exact Dart string code-unit sequence,
including malformed escapes and unpaired Unicode code units.

## Freeze and retention

Relevant platform-response errors are frozen directly. A `window.onerror` or
unhandled rejection is correlated only when it follows an observed navigation
platform message within five seconds; this is labeled
`closest_preceding_message_unconfirmed`. Duplicate freezes for the same message
are suppressed.

Incidents use localStorage key `or_app.uri_exception_evidence.v2`, schema 2.
They are separate from the normal five-session/200-event rotation and are
bounded to five incidents. Persistence is synchronous only at freeze time so a
restart does not erase the incident. Routine diagnostics CLEAR does not remove
this unresolved evidence.

## Controlled reproduction

Build-time define `OR_APP_URI_EVIDENCE_INJECTION=true` sends this malformed
input through the real `SystemChannels.navigation` channel:

`http://or-app.invalid:bad/path?probe=%25#uri-evidence-v2`

It is disabled in every normal build. A release-equivalent verification build
must demonstrate that the engine parser fails, the exact UTF-16 sequence is
frozen, the app can restart, and SYSTEM diagnostics exports the same sequence.

Example build:

```text
flutter build web --release --base-href /or_app/ --pwa-strategy=none \
  --dart-define=OR_APP_URI_EVIDENCE_INJECTION=true \
  --dart-define=OR_APP_URI_EVIDENCE_E2E_DIAGNOSTICS_ROUTE=true \
  --dart-define=OR_APP_RELEASE_COMMIT=uri-evidence-e2e-20261116
```

The diagnostics-route define is test infrastructure only. It changes the
injection build's initial route to the real Dashboard Diagnostics page so the
export control can be exercised without screen-coordinate assumptions. It does
not change the malformed-message path, and both defines are omitted from every
production build.

Run the deterministic browser acceptance after the build:

```text
node tool/run_uri_evidence_browser_e2e.mjs \
  uri-evidence-e2e-20261116 8766 9336
```

The runner serves `build/web` at the production-compatible fixed origin
`http://127.0.0.1:8766/or_app/`, applies the same release-token query to the
bootstrap/main request as Pages, and launches Chrome on CDP port 9336 with a
new persistent profile. It verifies the actual URL and bundle release before
testing. The browser process is closed and relaunched with that same profile;
a refresh is not used as the persistence proof. The second process activates
the real `COPY URI EVIDENCE` control through Chrome's accessibility tree and
parses the clipboard JSON.

The release-Web engine reports this controlled parser failure through
`window.onerror` rather than as an error response on the platform-message
Future. The frozen incident therefore labels the relationship
`closest_preceding_message_unconfirmed`, while retaining the only immediately
preceding `flutter/navigation` input byte-for-byte. This controlled injection
proves capture coverage; it does not prove that the same URI producer caused
the historical production incidents.

Unit coverage uses the same production messenger wrapper with a delegate that
performs the engine's documented decode-and-parse behavior. That test is useful
but does not replace the release-Web verification above.

Before publishing, build again without either E2E define and verify that
`main.dart.js` contains neither the injected malformed URI nor the E2E define
names. Permanent capture, persistence, and the SYSTEM export remain enabled.

## Failed/insufficient earlier methods

* NavigatorObserver history did not expose framework-internal message bytes.
* VM navigation tests passed and did not exercise the Web engine handler.
* Browser popstate/hashchange and `window.onerror` recorded timing but not the
  parser input.
* A direct `Uri.parse()` collector test would not prove boundary coverage and is
  not used as the acceptance path.

## Evidence interpretation

`platform_response_error` is a directly associated message failure.
`closest_preceding_message_unconfirmed` is evidence of timing only. A captured
URI must not be called causal until its same-boundary injection or production
failure reproduces the engine exception.

## Version dependencies and next step

Production CI injects the actual Flutter version, framework revision and engine
revision from `flutter --version --machine`. The current investigated versions
are Flutter 3.44.6, framework
`ee80f08bbf97172ec030b8751ceab557177a34a6`, engine
`83675ed27633283e7fc296c8bca22e841224c096`.

After the next real-device incident, export SYSTEM diagnostics and compare the
captured raw URI and method with the browser/history context. Only then should
the owner that produced the malformed value be changed.
