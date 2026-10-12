import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chat/domain/chat_filter.dart';

void main() {
  test('clean messages pass through untouched', () {
    for (final text in [
      'Good game!',
      'nice move, well played',
      'that cocktail was great',
      'grapes and scrapes',
      'spicy food',
      'Your turn ⏳',
    ]) {
      expect(ChatFilter.filter(text), text);
      expect(ChatFilter.isClean(text), isTrue);
    }
  });

  test('offensive words are masked, the rest kept', () {
    expect(ChatFilter.filter('you are a FUCKING idiot'), 'you are a ★★★ ★★★');
    expect(ChatFilter.filter('shit happens'), '★★★ happens');
  });

  test('common dodges are caught', () {
    expect(ChatFilter.filter('fuuuuck this'), '★★★ this');
    expect(ChatFilter.filter('sh1t'), '★★★');
    expect(ChatFilter.filter(r'b!tch'), '★★★');
    expect(ChatFilter.filter('f u c k off'), '★★★ off');
    expect(ChatFilter.filter('f.u.c.k'), '★★★');
  });
}
