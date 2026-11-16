{{flutter_js}}
{{flutter_build_config}}

const startupTiming = window.__orAppStartupTiming ??= {};
const markStartup = (event, fields = {}) => {
  if (typeof window.__orAppMarkPreDart === 'function') {
    window.__orAppMarkPreDart(event, fields);
  }
};

_flutter.loader.load({
  config: {
    // The loader starts CanvasKit before onEntrypointLoaded runs, so this
    // setting must live here rather than in initializeEngine().
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: async function(engineInitializer) {
    startupTiming.entrypointLoadedMs = performance.now();
    markStartup('entrypoint_loaded', {
      entrypointLoadedMs: startupTiming.entrypointLoadedMs,
    });

    startupTiming.engineInitializeStartMs = performance.now();
    markStartup('engine_initialize_start', {
      engineInitializeStartMs: startupTiming.engineInitializeStartMs,
    });
    const appRunner = await engineInitializer.initializeEngine();
    startupTiming.engineInitializeCompleteMs = performance.now();
    const engineResources = performance.getEntriesByType('resource')
      .filter((entry) => /flutter-canvaskit|canvaskit/i.test(entry.name))
      .slice(-16)
      .map((entry) => {
        let resource = 'unknown';
        try {
          resource = new URL(entry.name).pathname.split('/').pop() || 'unknown';
        } catch (_) {}
        return {
          resource,
          source: entry.name.includes(location.origin)
            ? 'same_origin'
            : 'cross_origin',
          initiatorType: entry.initiatorType || 'unknown',
          startMs: Math.round(entry.startTime),
          responseEndMs: Math.round(entry.responseEnd),
          durationMs: Math.round(entry.duration),
          fetchWaitMs:
            entry.responseStart > 0
              ? Math.round(entry.responseStart - entry.fetchStart)
              : null,
          downloadMs:
            entry.responseStart > 0
              ? Math.round(entry.responseEnd - entry.responseStart)
              : null,
          transferBytes: entry.transferSize || 0,
          encodedBytes: entry.encodedBodySize || 0,
          decodedBytes: entry.decodedBodySize || 0,
          cacheStatus: entry.transferSize === 0 && entry.decodedBodySize > 0
            ? 'reused'
            : 'transferred',
          protocol: entry.nextHopProtocol || 'unknown',
        };
      });
    startupTiming.engineResourceTimingsJson = JSON.stringify(engineResources);
    markStartup('engine_initialize_complete', {
      engineInitializeCompleteMs: startupTiming.engineInitializeCompleteMs,
      engineResourceCount: engineResources.length,
    });

    startupTiming.runAppStartMs = performance.now();
    markStartup('flutter_run_app_start', {
      runAppStartMs: startupTiming.runAppStartMs,
    });
    await appRunner.runApp();
    startupTiming.runAppCompleteMs = performance.now();
    markStartup('flutter_run_app_complete', {
      runAppCompleteMs: startupTiming.runAppCompleteMs,
    });
    window.dispatchEvent(new CustomEvent('or-app-run-app-complete'));
  },
});
