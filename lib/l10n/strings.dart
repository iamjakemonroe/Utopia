import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The app's words, in the player's language: every one is in
/// lib/l10n/app_en.arb (English), ready for translation. Read anywhere
/// (screens, controllers, toasts), with no BuildContext needed.
L10n get strings => _strings;
L10n _strings = lookupL10n(const Locale('en'));

/// Switches the app's words to [locale] (one of [L10n.supportedLocales]).
void useLocale(Locale locale) => _strings = lookupL10n(locale);
