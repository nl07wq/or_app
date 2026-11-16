{{flutter_js}}
{{flutter_build_config}}

const startupTiming = window.__orAppStartupTiming ??= {};
const markStartup = (event, fields = {}) => {
  if (typeof window.__orAppMarkPreDart === 'function') {
    window.__orAppMarkPreDart(event, fields);
  }
};

_flutter.loader.load({
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
      .slice(-12)
      .map((entry) => {
        let resource = 'unknown';
        try {
          resource = new URL(entry.name).pathname.split('/').pop() || 'unknown';
        } catch (_) {}
        return {
          resource,
          initiatorType: entry.initiatorType || 'unknown',
          startMs: Math.round(entry.startTime),
          durationMs: Math.round(entry.duration),
          transferBytes: entry.transferSize || 0,
          encodedBytes: entry.encodedBodySize || 0,
          decodedBytes: entry.decodedBodySize || 0,
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
  },
});
