import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import '../providers/student_orders_provider.dart';
import 'package:flutter/foundation.dart';

class StudentVoiceService {
  final Ref _ref;
  final FlutterTts _flutterTts = FlutterTts();
  final Set<String> _announcedCalls = {};

  StudentVoiceService(this._ref) {
    _initTts();
    _listenToOrders();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-IN"); // Targeted locale
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _listenToOrders() {
    _ref.listen(studentActiveOrdersProvider, (previous, next) {
      for (final order in next) {
        final orderId = order['orderId'] as String?;
        final isCalled = order['isCalledForPickup'] as bool? ?? false;
        final tokenNumber = order['tokenNumber']?.toString() ?? '';
        final status = (order['orderStatus'] as String? ?? '').toLowerCase();

        if (orderId == null || tokenNumber.isEmpty) continue;

        final announceKey = '${orderId}_called';
        
        // 1. Announce when called for pickup
        if (isCalled && !_announcedCalls.contains(announceKey)) {
          _announceCall(tokenNumber);
          _announcedCalls.add(announceKey);
        }
        
        // 2. Clear from set if order is served to keep memory clean
        if (status == 'served') {
          _announcedCalls.remove(announceKey);
        }
      }
    });
  }

  Future<void> _announceCall(String tokenNumber) async {
    final message = "Token number $tokenNumber is ready for pickup. Please come to the counter.";
    debugPrint('StudentVoiceService: Announcing => $message');
    
    // Physical feedback
    HapticFeedback.vibrate();
    
    // Audible feedback
    await _flutterTts.speak(message);
  }
}

final studentVoiceServiceProvider = Provider<StudentVoiceService>((ref) {
  return StudentVoiceService(ref);
});
