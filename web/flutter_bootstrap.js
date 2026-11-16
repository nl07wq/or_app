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
    markStartup('engine_initialize_complete', {
      engineInitializeCompleteMs: startupTiming.engineInitializeCompleteMs,
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
