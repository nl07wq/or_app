# Startup Performance V2 investigation

Date: 2026-11-16
Baseline: iPhone Safari diagnostics supplied for releases before this change.

## Confirmed facts

- MAP and the six facility assets already begin independently after their real
  configuration prerequisites are ready. Facility presentation remains atomic.
- WATER and WALKER already use two bounded lanes. Each lane decodes sequentially.
- The previous staging code awaited a rendered frame before every WALKER frame,
  between each facility after the first, after each four WATER frames, and before
  each deferred RIFLE REGRIP frame.
- Delayed-reopen diagnostics showed WALKER frame completions separated by roughly
  200–300 ms. Twenty-five render-frame waits therefore account for approximately
  5–7.5 seconds even before acquisition/decode work. This matches the observed
  5.997–6.687 second WALKER preparations. The same mechanism contributed up to
  five throttled waits to facility preparation and six to WATER preparation.
- Warm foreground launches delivered frames normally, explaining why the same
  path could complete much faster without any asset or geometry difference.

## Correction

The per-asset render-frame barriers were replaced with microtask/event-loop
yielding. This retains sequential decoding within each lane, keeps the maximum
of two expensive WATER/WALKER decode operations, and lets pending input and
microtasks proceed without making asset readiness depend on iOS render cadence.

The approved assets, timing, map transforms, facility atomic reveal, water
geometry, and animation behavior are unchanged.

Completion diagnostics now include per-item duration, cache status, aggregate
cache reuse, yield time, and scheduling strategy. Slow frames separately report
build and raster duration, plus lifecycle state.

## Slow-start evidence schema

Storage key: `or_app.slow_start_evidence.v1`
Schema version: 1
Retention: newest five incidents, independent of the routine five sessions and
the URI Evidence V2 incident store.

Triggers are inclusive:

- Document to Dart Main: 5,000 ms
- Document to Dashboard interactive: 10,000 ms
- Dart Main to Dashboard interactive: 5,000 ms
- Facility atomic preparation: 3,000 ms
- WATER preparation: 4,000 ms
- WALKER preparation: 5,000 ms

Each incident snapshots the complete available session trace, trigger values,
build identity, platform metadata, lifecycle state, startup metrics, asset
preparation summaries, and slow-frame batches. SYSTEM > DIAGNOSTICS exposes a
local JSON copy/export path.

Pre-Dart evidence uses the separate bounded key
`or_app.pre_dart_evidence.v1`. It stores at most five scalar browser-boundary
records (document, bundle preload, bootstrap and Dart-reached status), so a
startup that ends before Dart can be correlated on the next successful launch.

## Unresolved / real-device gate

- Desktop tests cannot reproduce an iPhone delayed reopen or prove WebKit cache,
  suspension, network and JavaScript compilation behavior after hours idle.
- Document-to-Dart variance therefore remains a real-device investigation item.
  The release-token preload is preserved; new pre-Dart records distinguish
  preload/bootstrap progress without claiming an unavailable Document metric.
- iPhone delayed-reopen performance must be compared over multiple equivalent
  launches. Until then, delayed-reopen acceptance remains pending even though
  the render-cadence dependency is removed and permanently observable.
