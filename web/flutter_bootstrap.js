{{flutter_js}}
{{flutter_build_config}}

(function () {
  const trace = (event, fields) => {
    if (typeof window.__orAppStartupRecord === 'function') {
      window.__orAppStartupRecord(event, fields);
    }
  };

  const resource = (needle) => {
    try {
      const entry = performance.getEntriesByType('resource').find((value) =>
        String(value.name).includes(needle),
      );
      if (!entry) return null;
      return {
        durationMs: Math.round(entry.duration),
        transferSize: Number(entry.transferSize) || null,
        encodedBodySize: Number(entry.encodedBodySize) || null,
        decodedBodySize: Number(entry.decodedBodySize) || null,
      };
    } catch (_) {
      return null;
    }
  };

  trace('FLUTTER_LOADER_START');
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: '{{flutter_service_worker_version}}',
    },
    onEntrypointLoaded: async function (engineInitializer) {
      trace('ENTRYPOINT_LOAD_END', { mainDartJs: resource('main.dart.js') });
      trace('ENGINE_INITIALIZE_START');
      const appRunner = await engineInitializer.initializeEngine();
      trace('ENGINE_INITIALIZE_END', { canvasKit: resource('canvaskit') });
      trace('APP_RUNNER_RUN_START');
      await appRunner.runApp();
      trace('APP_RUNNER_RUN_END');
    },
  });
})();
