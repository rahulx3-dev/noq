import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers.dart';
import 'staff_providers.dart';

final staffAlertProvider = Provider<StaffAlertService>((ref) {
  return StaffAlertService(ref);
});

class StaffAlertService {
  final Ref _ref;
  final FlutterTts _flutterTts = FlutterTts();
  final Set<String> _knownPendingTokens = {};
  bool _isInitialized = false;

  StaffAlertService(this._ref) {
    _initTts();
    _listenToOrders();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _listenToOrders() {
    _ref.listen<AsyncValue<List<DocumentSnapshot<Map<String, dynamic>>>>>(
      todayAllOrdersStreamProvider,
      (previous, next) {
        next.whenData((docs) {
          _processOrdersForAlerts(docs);
        });
      },
    );
  }

  Future<void> _processOrdersForAlerts(
    List<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (!_isInitialized) {
      // First load, populate known tokens so we don't alert on existing ones
      for (var doc in docs) {
        final data = doc.data()!;
        final status = (data['statusCategory'] as String? ??
            data['orderStatus'] as String? ?? 'pending').toLowerCase();
        if (status == 'pending') {
          final token = data['tokenNumber']?.toString();
          if (token != null) {
            _knownPendingTokens.add(token);
          }
        }
      }
      _isInitialized = true;
      return;
    }

    // Check for new pending tokens
    final userProfileAsync = _ref.read(userProfileProvider);
    final userProfile = userProfileAsync.value;

    // Only alert if the setting is enabled
    final isAlertsEnabled = userProfile?.orderAlertsEnabled ?? false;

    if (!isAlertsEnabled) return;

    for (var doc in docs) {
      final data = doc.data()!;
      final status = (data['statusCategory'] as String? ??
          data['orderStatus'] as String? ?? 'pending').toLowerCase();
      if (status == 'pending') {
        final token = data['tokenNumber']?.toString();
        if (token != null && !_knownPendingTokens.contains(token)) {
          _knownPendingTokens.add(token);
          // Only announce if the order was created very recently (< 5 minutes ago)
          // to avoid announcing old tokens that somehow got set to pending.
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null &&
              DateTime.now().difference(createdAt.toDate()).inMinutes < 5) {
            _announceToken(token);
          }
        }
      }
    }
  }

  Future<void> _announceToken(String token) async {
    await _flutterTts.speak('New token, $token');
  }
}
