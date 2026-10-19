{{flutter_js}}
{{flutter_build_config}}

// The faster WebAssembly build where the browser can run it, the
// JavaScript one elsewhere (the loader picks). Adding ?js to the address
// (or utopia_js=1 in this site's storage) always takes the JavaScript one:
// a way out if a browser ever misbehaves with WebAssembly.
var useJs = new URLSearchParams(location.search).has('js');
try {
  useJs = useJs || localStorage.getItem('utopia_js') === '1';
} catch (_) {}

_flutter.loader.load({
  config: useJs ? { renderer: 'canvaskit' } : {},
});
