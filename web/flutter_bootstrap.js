{{flutter_js}}
{{flutter_build_config}}

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/saapadu_sw.js', { updateViaCache: 'none' }).catch((error) => {
      console.warn('Offline cache could not start:', error);
    });
  });
}

_flutter.loader.load();
