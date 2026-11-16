# Startup Performance V6 investigation

## Scope and environment

- Baseline source: `0159c0b6` (includes Startup V5 `da53bed8`)
- Flutter: 3.44.6 stable (`ee80f08bbf`), engine revision `83675ed276`
- Renderer: dart2js + CanvasKit, locally served from `canvaskit/chromium/`
- Controlled browser: isolated Chrome profile and process via CDP
- Production path: `/or_app/`

The browser probe in `tool/run_startup_performance_browser_probe.mjs`
records resource requests, cache state, Performance metrics, long tasks and the
existing startup marks. CPU and network constraints are applied through CDP,
before navigation.

## Confirmed execution path

1. `web/index.html` records the document boundary, starts the local CanvasKit
   JS/WASM preloads, performs stale-service-worker recovery, then preloads the
   release-token-matched `main.dart.js`.
2. `web/flutter_bootstrap.js` asks Flutter Loader for local CanvasKit and
   records entrypoint, `initializeEngine` and `runApp` boundaries.
3. During `initializeEngine`, Flutter reads `FontManifest.json` and fetches
   every registered font face before Dart `main()`.
4. Dart `main()` starts startup/database verification and font readiness in
   parallel, initializes device settings, and calls `runApp`.
5. the existing StartupGate and BOOT/INITIALIZING UI retain ownership of
   application readiness and Dashboard transition.

MAP, facility, WATER, WALKER and SOLDIER preparation begins after Dart entry;
none is a dependency of the pre-Dart Engine interval.

## Confirmed root cause

`KleeOne` remained registered in `pubspec.yaml` even though no Dart source used
the family. Flutter therefore fetched both Klee faces during Engine startup:

- `KleeOne-Regular.ttf`: 8,724,204 bytes
- `KleeOne-SemiBold.ttf`: 8,905,128 bytes

This added 17,629,332 bytes to a cold or evicted-cache Engine start. It became
particularly expensive after browser inactivity, when Safari could no longer
reuse the font response.

The M PLUS filename also contained literal square brackets. Flutter encoded
the manifest path and the browser encoded it again, producing
`MPLUS1Code%255Bwght%255D.ttf` and an HTTP 404 during startup. The same bytes
are now stored under the URL-safe name `MPLUS1Code-wght.ttf`.

## Controlled verification

Three independent cold-profile runs used 20,000 kbps download throughput,
50 ms latency and no CPU throttle. All other source and build settings were
identical.

| Build | Engine median | runApp median | Font transfer median |
| --- | ---: | ---: | ---: |
| V5/current-font baseline | 9,101.5 ms | 15,233.3 ms | 19.12 MiB |
| V6 candidate | 3,295.2 ms | 9,418.6 ms | 6.06 MiB |

The candidate removed 13.06 MiB of measured font transfer and reduced the
median Engine interval by 5,806.3 ms. Individual Engine results were
9,056.0 / 9,125.4 / 9,101.5 ms before and
3,295.2 / 3,326.9 / 3,288.4 ms after.

With local unthrottled networking and a 6x CPU constraint, five candidate
runs had a 3,417.6 ms Engine median versus 3,511.5 ms for the baseline. This
small difference shows that removing the fonts fixes the cold-transfer cause,
but does not remove the independent CPU cost of Flutter/CanvasKit startup.

A minimal Flutter A/B used a 0.99 MB main bundle against the full 7.37 MB app.
At 6x CPU, its Engine median was 1,539.2 ms versus 3,511.5 ms for the full app;
entrypoint median was 605.8 ms versus 1,145.8 ms. This confirms accumulated
compiled-code CPU cost, but selecting a code-splitting architecture would be a
major architectural change and is outside V6 authority.

Removing either existing preload was disproven as an optimization. Without
the CanvasKit preload, Engine median increased from 3,511.5 to 3,629.2 ms and
variance increased. Disabling the main bundle preload also worsened the
controlled cold run. Both V5 delivery corrections remain.

## Historical evidence

- The original BOOT sequence entered at `dd6b8843` (2026-09-02). It is Dart UI
  and cannot execute before Engine completion.
- Both large Klee faces were registered at `7d45d9bc` (2026-10-12).
- M PLUS 1 Code replaced Klee as the application default at `baa5bcf4`
  (2026-10-26), but the unused Klee registrations remained.
- V3/V4/V5 main bundle sizes were approximately 7.35/7.36/7.36 MB. Their
  startup changes did not materially increase compiled JS size.
- MAP/WATER/WALKER/SOLDIER expansion increases post-Dart work, but controlled
  execution ordering rejects it as the source of the pre-BOOT Engine wait.

## Production correction and limits

- Remove Klee from the Flutter font manifest; source font/license files remain
  available in the repository and no user data is touched.
- Rename the M PLUS bundle asset to a URL-safe filename and update all direct
  loaders/tests.
- Remove the V5-only pre-Flutter presentation and its display lifecycle. The
  dark document canvas remains, and official BOOT/INITIALIZING is unchanged.
  This removal is not counted as a performance gain.
- Preserve local CanvasKit, release-token bundle preload, recovery behavior
  and all startup evidence stores.

The remaining CPU-bound Engine cost is real but not safely attributable to a
single application operation without architectural code splitting or a
renderer/SDK change. Neither is implemented in V6.

## iPhone acceptance contract

On the deployed release, collect at least five delayed-reopen and five warm
launches in iPhone Safari. Confirm:

1. no requests for either Klee font;
2. M PLUS returns 200 from `MPLUS1Code-wght.ttf` with no `%255B` 404;
3. `entrypointLoadedMs`, Engine start/complete, Dart main, BOOT first frame and
   Dashboard interactive remain internally ordered;
4. compare Engine and document-to-BOOT medians/ranges against V5 delayed runs;
5. no BASE CAMP, STANDARD, Japanese typography or persisted-data regression.

Desktop/CDP improvement is evidence for the removed transfer bottleneck, not
final proof of iPhone Safari acceptance.
