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

/// Calls [callback] whenever the page comes back into view: shown again,
/// restored, or focused (an installed app on a phone often only does
/// these, without the app hearing it resumed). Returns a function that
/// stops it.
void Function() onPageShown(void Function() callback) =>
    impl.onPageShown(callback);
