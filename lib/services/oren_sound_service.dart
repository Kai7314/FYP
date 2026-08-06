import 'package:audioplayers/audioplayers.dart';

import 'app_settings_service.dart';

class OrenSoundService {
  OrenSoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  Future<void> playDailyBonus() => _play('oren_bonus.wav');

  Future<void> playFeed() => _play('oren_feed.wav');

  Future<void> playPet() => _play('oren_pet.wav');

  Future<void> playPlayful() => _play('oren_play.wav');

  Future<void> dispose() => _player.dispose();

  Future<void> _play(String fileName) async {
    try {
      await AppSettingsService.instance.load();
      if (!AppSettingsService.instance.current.orenSoundsEnabled) return;
      await _player.stop();
      await _player.play(
        AssetSource('sounds/$fileName'),
        volume: 0.55,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Sound should never block Oren's care actions.
    }
  }
}
