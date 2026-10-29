{{flutter_js}}
{{flutter_build_config}}

// The faster WebAssembly build where the browser can run it, the
// JavaScript one elsewhere (the loader picks). Safari, and every browser on
// an iPhone or iPad, gets the WebAssembly one too (Flutter's loader keeps it
// to Chrome and Edge unless told): there it draws on a background thread
// (the site isolates the page, see the landing page's _headers), so the
// game no longer freezes while it draws. Browsers without WebAssembly GC
// (iOS before 18.2) still get the JavaScript one.
//
// Adding ?js to the address (or utopia_js=1 in this site's storage) always
// takes the JavaScript one: a way out if a browser ever misbehaves with
// WebAssembly. And if the game hasn't drawn its first frame 25 seconds after
// starting the WebAssembly one, the page takes that way out by itself (once:
// from then on this browser keeps the JavaScript one).
var useJs = new URLSearchParams(location.search).has('js');
try {
  useJs = useJs || localStorage.getItem('utopia_js') === '1';
} catch (_) {}

if (!useJs) {
  var drawn = false;
  window.addEventListener('flutter-first-frame', function () { drawn = true; });
  setTimeout(function () {
    var wasm = performance.getEntriesByType('resource').some(function (e) {
      return e.name.indexOf('main.dart.wasm') >= 0;
    });
    if (drawn || !wasm) return;
    try {
      localStorage.setItem('utopia_js', '1');
    } catch (_) {}
    location.reload();
  }, 25000);
}

// Where the WebAssembly build draws: on a background thread (the page is
// isolated so it can), which keeps the page's own thread free for touches
// and scrolling. ?draw=page draws on the page's thread instead, for checking.
var onPage = new URLSearchParams(location.search).get('draw') === 'page';

_flutter.loader.load({
  config: useJs
    ? { renderer: 'canvaskit' }
    : {
        wasmAllowList: { blink: true, webkit: true },
        forceSingleThreadedSkwasm: onPage,
      },
});
