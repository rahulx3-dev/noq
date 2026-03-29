import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/providers.dart';
import '../../../core/models/user_profile_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_providers.dart';
import 'package:flutter/foundation.dart';

class VoiceAnnouncerService {
  final Ref _ref;
  final FlutterTts _flutterTts = FlutterTts();
  final Set<String> _announcedOrders = {};
  final List<String> _speechQueue = [];
  bool _isInitialized = false;
  bool _isSpeaking = false;

  VoiceAnnouncerService(this._ref) {
    _initTts();
    _listenToOrders();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // Natural clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Ensure we wait for speak to finish before starting next one
      await _flutterTts.awaitSpeakCompletion(true);

      _isInitialized = true;
      debugPrint('VoiceAnnouncer: TTS initialized successfully');
    } catch (e) {
      debugPrint('VoiceAnnouncer: TTS initialization failed: $e');
      _isInitialized = false;
    }
  }

  void _listenToOrders() {
    _ref.listen(todayAllOrdersStreamProvider, (previous, next) {
      final userProfile = _ref.read(userProfileProvider).value;
      if (userProfile == null || userProfile.role != UserRole.staff) return;
      if (userProfile.orderAlertsEnabled != true) return;

      next.whenData((docs) {
        final now = DateTime.now();
        for (final doc in docs) {
          final data = doc.data();
          if (data == null) continue;

          final orderId = doc.id;
          final status =
              (data['orderStatus'] as String?)?.toLowerCase() ?? 'pending';
          final tokenNumber = data['tokenNumber']?.toString() ?? 'Unknown';

          final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
          if (updatedAt != null && now.difference(updatedAt).inMinutes > 5)
            continue;

          final announceKey = '${orderId}_$status';
          if (!_announcedOrders.contains(announceKey)) {
            if (status == 'ready' ||
                status == 'skipped' ||
                status == 'partial') {
              _queueAnnouncement(tokenNumber, status);
              _announcedOrders.add(announceKey);
            }
          }
        }
      });
    });
  }

  void _queueAnnouncement(String tokenNumber, String status) {
    String message = "Token number $tokenNumber is ready";
    if (status == 'skipped') {
      message = "Token number $tokenNumber has been skipped";
    } else if (status == 'partial') {
      message = "Token number $tokenNumber is partially served";
    }

    _speechQueue.add(message);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (!_isInitialized || _isSpeaking || _speechQueue.isEmpty) return;

    _isSpeaking = true;

    while (_speechQueue.isNotEmpty) {
      final message = _speechQueue.removeAt(0);
      try {
        debugPrint('VoiceAnnouncer: Speaking => $message');
        await _flutterTts.speak(message);
      } catch (e) {
        debugPrint('VoiceAnnouncer: Error speaking: $e');
      }
    }

    _isSpeaking = false;
  }
}

// Provider to keep the service alive in the staff shell
final voiceAnnouncerServiceProvider = Provider<VoiceAnnouncerService>((ref) {
  return VoiceAnnouncerService(ref);
});
