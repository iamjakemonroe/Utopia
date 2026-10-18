import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/chip/chip_brain.dart';
import 'package:utopia/features/auras/domain/aura.dart';
import 'package:utopia/features/maestro/data/maestro_repository.dart';

void main() {
  test("a member's plan reads from the server's answer", () {
    final status = MaestroStatus.fromJson({
      'active': true,
      'until': '2026-11-18T10:00:00Z',
      'auto_renew': true,
      'left': 27,
      'free': false,
    });
    expect(status.active, isTrue);
    expect(status.left, 27);
    expect(status.until, DateTime.utc(2026, 11, 18, 10));
    expect(MaestroStatus.fromJson(null).active, isFalse);
  });

  test("Chip's portrait offer keeps how it works for the player", () {
    final offer = ChipPortraitOffer.fromJson({
      'subject': 'Burna Boy',
      'photo': false,
      'state': 'maestro',
      'left': 12,
    })!;
    expect(offer.state, 'maestro');
    expect(ChipPortraitOffer.fromJson(offer.toJson())!.left, 12);
    // A line saved before plans existed still reads (as locked).
    expect(ChipPortraitOffer.fromJson({'subject': 'x'})!.state, 'locked');
  });

  test('the Maestro frame comes with the plan and is never sold', () {
    expect(Aura.maestro.notSold, isTrue);
    expect(Aura.byId('maestro')?.includedWith, 'Chip Maestro');
    expect(Aura.byId('bubbles')!.notSold, isFalse);
  });
}
