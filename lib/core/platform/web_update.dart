import 'web_update_native.dart'
    if (dart.library.js_interop) 'web_update_web.dart'
    as impl;

/// This build's stamp (tool/build_web_game.sh sets it), empty in the apps.
const kWebBuild = String.fromEnvironment('WEB_BUILD');

/// The build the site serves now (its build.json), or null if it can't be
/// read. Always null in the apps.
Future<String?> liveWebBuild() => impl.liveWebBuild();

/// Loads the page again, with the newest build.
void reloadPage() => impl.reloadPage();
