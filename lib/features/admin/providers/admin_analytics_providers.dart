import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

// ─── 1. Session sell-through ─────────────────────────────────────────────────

final sessionSellThroughProvider =
    FutureProvider.family<double, String>((ref, sessionId) async {
  final stats = await ref.watch(sessionStatsProvider(sessionId).future);
  final added = (stats['added'] ?? 0);
  final sold  = (stats['sold']  ?? 0);
  if (added == 0) return 0.0;
  return (sold / added * 100).clamp(0.0, 100.0);
});

// ─── 2. Unique students today ────────────────────────────────────────────────

final uniqueStudentsProvider =
    FutureProvider.family<int, DatePeriod>((ref, period) async {
  try {
    final startDate = DateFormat('yyyy-MM-dd').parse(period.start);
    final endDate = DateFormat('yyyy-MM-dd').parse(period.end);
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final snap = await ref.read(firestoreServiceProvider).getOrdersByDateRange('default', startOfDay, endOfDay).first;
    return snap.docs.map((d) => d.data()['studentUid'] as String? ?? '').toSet().length;
  } catch (_) {
    return 0;
  }
});

// ─── 3. Payment breakdown ────────────────────────────────────────────────────

final paymentBreakdownProvider =
    FutureProvider.family<Map<String, dynamic>, DatePeriod>((ref, period) async {
  try {
    final startDate = DateFormat('yyyy-MM-dd').parse(period.start);
    final endDate = DateFormat('yyyy-MM-dd').parse(period.end);
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final snap = await ref.read(firestoreServiceProvider).getOrdersByDateRange('default', startOfDay, endOfDay).first;
    final docs = snap.docs.map((d) => d.data()).toList();
    int gpay = 0, phonepe = 0, others = 0, failed = 0, total = docs.length;
    for (final d in docs) {
      final mode   = (d['paymentMode']   ?? '').toString().toLowerCase();
      final status = (d['paymentStatus'] ?? '').toString().toLowerCase();
      if (mode.contains('gpay') || mode.contains('google')) {  gpay++; }
      else if (mode.contains('phonepe')) { phonepe++; }
      else { others++; }
      if (status == 'failed') failed++;
    }
    final success = total > 0 ? ((total - failed) / total * 100) : 0.0;
    return {
      'gpay': gpay, 'phonepe': phonepe, 'others': others,
      'failed': failed, 'total': total,
      'successRate': success.toStringAsFixed(1),
    };
  } catch (_) {
    return {'gpay': 0, 'phonepe': 0, 'others': 0, 'failed': 0, 'total': 0, 'successRate': '0.0'};
  }
});

// ─── 4. Slot heatmap ─────────────────────────────────────────────────────────

final slotHeatmapProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, dateStr) async {
  try {
    final releasedSnap = await FirebaseFirestore.instance
        .collection('canteens/default/dailyMenus/$dateStr/sessions')
        .get();
    final List<Map<String, dynamic>> result = [];
    for (final sessDoc in releasedSnap.docs) {
      final sessData  = sessDoc.data();
      final sessName  = sessData['sessionNameSnapshot'] ?? 'Session';
      final slotsSnap = await FirebaseFirestore.instance
          .collection('canteens/default/dailyMenus/$dateStr/sessions/${sessDoc.id}/slots')
          .get();
      for (final slotDoc in slotsSnap.docs) {
        final s         = slotDoc.data();
        final capacity  = (s['capacity']          ?? 0) as int;
        final remaining = (s['remainingCapacity'] ?? 0) as int;
        final ordered   = (capacity - remaining).clamp(0, capacity);
        result.add({
          'slotId':      slotDoc.id,
          'startTime':   s['startTime']  ?? '',
          'endTime':     s['endTime']    ?? '',
          'sessionId':   sessDoc.id,
          'sessionName': sessName,
          'ordersInSlot': ordered,
          'capacity':    capacity,
          'utilisation': capacity > 0 ? (ordered / capacity * 100) : 0.0,
        });
      }
    }
    result.sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
    return result;
  } catch (_) {
    return [];
  }
});

// ─── 5. Waste analysis ───────────────────────────────────────────────────────

final wasteAnalysisProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, dateStr) async {
  try {
    final releasedSnap = await FirebaseFirestore.instance
        .collection('canteens/default/dailyMenus/$dateStr/sessions')
        .get();
    double totalWasteValue = 0;
    final List<Map<String, dynamic>> wasteItems   = [];
    final Map<String, dynamic>       sessionWaste  = {};
    for (final sessDoc in releasedSnap.docs) {
      final sessData = sessDoc.data();
      final sessName = sessData['sessionNameSnapshot'] ?? 'Session';
      final itemsSnap = await FirebaseFirestore.instance
          .collection('canteens/default/dailyMenus/$dateStr/sessions/${sessDoc.id}/items')
          .get();
      double sessWaste = 0;
      for (final itemDoc in itemsSnap.docs) {
        final item  = itemDoc.data();
        final stock = (item['remainingStock'] ?? 0) as int;
        final price = ((item['priceSnapshot'] ?? 0) as num).toDouble();
        if (stock > 0) {
          final wv = stock * price;
          sessWaste      += wv;
          totalWasteValue += wv;
          wasteItems.add({
            'name':        item['nameSnapshot'] ?? 'Item',
            'stock':       stock,
            'price':       price,
            'wasteValue':  wv,
            'sessionName': sessName,
            'sessionId':   sessDoc.id,
          });
        }
      }
      sessionWaste[sessName] = sessWaste;
    }
    return {
      'totalWasteValue': totalWasteValue,
      'wasteItems':      wasteItems,
      'sessionWaste':    sessionWaste,
    };
  } catch (_) {
    return {'totalWasteValue': 0.0, 'wasteItems': [], 'sessionWaste': {}};
  }
});

// ─── 6. Token consumption ────────────────────────────────────────────────────

final tokenConsumptionProvider =
    FutureProvider.family<Map<String, dynamic>, DatePeriod>((ref, period) async {
  try {
    final startDate = DateFormat('yyyy-MM-dd').parse(period.start);
    final endDate = DateFormat('yyyy-MM-dd').parse(period.end);
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final snap = await ref.read(firestoreServiceProvider).getOrdersByDateRange('default', startOfDay, endOfDay).first;
    final docs = snap.docs.map((d) => d.data()).toList();

    int generated = docs.length;
    int served    = 0, pending = 0, noShow = 0, preparing = 0, ready = 0;
    final List<double> waitMinutes = [];

    // velocity buckets: "HH:MM" → count
    final Map<String, int> buckets = {};

    for (final d in docs) {
      final status = (d['orderStatus'] ?? '').toString().toLowerCase();
      // Broad matching for 'served' to include 'partial served'
      if (status.contains('served')) {                              served++; }
      else if (status == 'ready') {                                 ready++; }
      else if (status == 'preparing') {                             preparing++; }
      else if (status == 'pending' || status == 'confirmed') {      pending++; }
      else if ({'skipped','cancelled'}.contains(status)) {          noShow++; }
      else if (status == 'partial') {                               served++; } // Count partial as served for consumption tracking

      final created = (d['createdAt']  as Timestamp?)?.toDate();
      final served_ = (d['updatedAt']  as Timestamp?)?.toDate();
      if (created != null && served_ != null && status.contains('served')) {
        final diff = served_.difference(created).inSeconds / 60.0;
        if (diff > 0) waitMinutes.add(diff);
      }

      // bucket by 30-min windows using createdAt
      if (created != null) {
        final h   = created.hour;
        final m   = created.minute < 30 ? 0 : 30;
        final key = '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}';
        buckets[key] = (buckets[key] ?? 0) + 1;
      }
    }

    final avg     = waitMinutes.isNotEmpty
        ? waitMinutes.reduce((a,b)=>a+b) / waitMinutes.length : 0.0;
    final peak    = waitMinutes.isNotEmpty
        ? waitMinutes.reduce((a,b)=>a>b?a:b) : 0.0;
    final fastest = waitMinutes.isNotEmpty
        ? waitMinutes.reduce((a,b)=>a<b?a:b) : 0.0;
    final slow    = waitMinutes.where((w) => w > 10).length;

    final sortedBuckets = buckets.entries.toList()
      ..sort((a,b) => a.key.compareTo(b.key));

    // Consumption rate includes everything that is no longer pending/preparing
    final consumptionRate = generated > 0 ? (served / generated * 100) : 0.0;

    return {
      'generated':          generated,
      'served':             served,
      'pending':            pending,
      'preparing':          preparing,
      'ready':              ready,
      'noShow':             noShow,
      'consumptionRate':    consumptionRate,
      'avgWaitMinutes':     avg,
      'peakWaitMinutes':    peak,
      'fastestPickupMinutes': fastest,
      'slowTokenCount':     slow,
      'velocityBuckets':    sortedBuckets
          .map((e) => {'timeLabel': e.key, 'count': e.value}).toList(),
    };
  } catch (_) {
    return {
      'generated': 0, 'served': 0, 'pending': 0, 'noShow': 0,
      'consumptionRate': 0.0, 'avgWaitMinutes': 0.0,
      'peakWaitMinutes': 0.0, 'fastestPickupMinutes': 0.0,
      'slowTokenCount': 0, 'velocityBuckets': [],
    };
  }
});

// ─── 7. Seven-day summary ────────────────────────────────────────────────────

final sevenDayStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final List<Map<String, dynamic>> result = [];
  final today = DateTime.now();
  for (int i = 6; i >= 0; i--) {
    final date    = today.subtract(Duration(days: i));
    final dateStr = _fmt(date);
    try {
      final stats    = ref.watch(statsByPeriodProvider((start: dateStr, end: dateStr)));
      final waste    = await ref.watch(wasteAnalysisProvider(dateStr).future);
      final tokens   = await ref.watch(tokenConsumptionProvider((start: dateStr, end: dateStr)).future);
      result.add({
        'date':         dateStr,
        'displayDate':  DateFormat('EEE MMM d').format(date),
        'isToday':      i == 0,
        'revenue':      (stats['totalRevenue']    ?? 0) as num,
        'orders':       (stats['totalOrders']     ?? 0) as int,
        'served':       (tokens['served']         ?? 0) as int,
        'noShow':       (tokens['noShow']         ?? 0) as int,
        'avgWait':      (tokens['avgWaitMinutes'] ?? 0.0) as double,
        'wasteValue':   (waste['totalWasteValue'] ?? 0.0) as double,
        'hourlyOrders': stats['hourlyOrders'] ?? {},
      });
    } catch (_) {
      result.add({
        'date': dateStr, 'displayDate': DateFormat('EEE MMM d').format(date),
        'isToday': i == 0,
        'revenue': 0, 'orders': 0, 'served': 0,
        'noShow': 0, 'avgWait': 0.0, 'wasteValue': 0.0,
      });
    }
  }
  return result;
});
