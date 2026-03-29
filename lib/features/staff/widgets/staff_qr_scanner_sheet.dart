import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/themes/staff_theme.dart';
import '../../../core/utils/time_helper.dart';
import '../providers/staff_providers.dart';

/// A bottom sheet that opens the camera to scan a student's QR code.
/// On successful scan, it locates the token group and navigates the
/// staff dashboard to the correct session/slot.
///
/// This is an ADDITIVE ASSIST feature only. It does NOT auto-serve,
/// does NOT bypass the queue, and does NOT change any status.
class StaffQrScannerSheet extends ConsumerStatefulWidget {
  const StaffQrScannerSheet({super.key});

  @override
  ConsumerState<StaffQrScannerSheet> createState() => _StaffQrScannerSheetState();
}

class _StaffQrScannerSheetState extends ConsumerState<StaffQrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      final data = jsonDecode(barcode.rawValue!) as Map<String, dynamic>;
      final checkoutGroupId = data['checkoutGroupId'] as String?;
      final tokenNumber = data['tokenNumber'] as String?;

      if (checkoutGroupId == null || tokenNumber == null) {
        _showError('Invalid QR code');
        return;
      }

      _locateToken(checkoutGroupId, tokenNumber);
    } catch (e) {
      _showError('Could not read QR code');
    }
  }

  void _locateToken(String checkoutGroupId, String tokenNumber) {
    final ordersAsync = ref.read(todayAllOrdersStreamProvider);

    ordersAsync.when(
      data: (docs) {
        // Find ALL docs matching this checkoutGroupId
        final matchingDocs = docs.where((doc) {
          final data = doc.data()!;
          return data['checkoutGroupId'] == checkoutGroupId;
        }).toList();

        if (matchingDocs.isEmpty) {
          _showError('Token #$tokenNumber not found today');
          return;
        }

        // Classify slices
        final List<Map<String, dynamic>> nonServedSlices = [];
        bool allServed = true;

        for (final doc in matchingDocs) {
          final data = doc.data()!;
          final status = (data['statusCategory'] as String? ?? 
              data['orderStatus'] as String? ?? 'pending').toLowerCase();
          
          if (status != 'served') {
            allServed = false;
            nonServedSlices.add({
              'sessionId': data['sessionId'],
              'slotId': data['slotId'],
              'statusCategory': status,
              'sessionName': data['sessionNameSnapshot'] ?? data['sessionName'] ?? 'Session',
              'slotStartTime': data['slotStartTime'] ?? '',
            });
          }
        }

        if (allServed) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Token #$tokenNumber — Already Served ✓',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              backgroundColor: StaffTheme.statusReady,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }

        if (nonServedSlices.length == 1) {
          // Single actionable slice — jump directly
          _navigateToSlice(nonServedSlices.first, tokenNumber);
          return;
        }

        // Multiple non-served slices — pick by real-time priority
        final bestSlice = _pickBestSlice(nonServedSlices);
        if (bestSlice != null) {
          _navigateToSlice(bestSlice, tokenNumber);
          return;
        }

        // Ambiguous — show a lightweight chooser
        Navigator.pop(context); // Close scanner first
        _showSliceChooser(nonServedSlices, tokenNumber);
      },
      loading: () {
        _showError('Still loading orders, try again');
      },
      error: (e, s) {
        _showError('Error loading orders');
      },
    );
  }

  /// Picks the best slice using real-time priority:
  /// 1. Current active session/slot (live right now)
  /// 2. Nearest upcoming slot
  /// Returns null if ambiguous (no clear winner).
  Map<String, dynamic>? _pickBestSlice(List<Map<String, dynamic>> slices) {
    final now = DateTime.now();
    final sessionsAsync = ref.read(currentDaySessionsWithStatusProvider);
    
    // Find the current live session ID
    String? liveSessionId;
    sessionsAsync.whenData((sessions) {
      for (var s in sessions) {
        if (s['isLive'] == true) {
          liveSessionId = s['id'];
          break;
        }
      }
    });

    // Priority 1: slice in the current live session
    if (liveSessionId != null) {
      final liveSlices = slices.where((s) => s['sessionId'] == liveSessionId).toList();
      if (liveSlices.length == 1) return liveSlices.first;
      
      // If multiple slices in same live session, pick the one with earliest slot time
      if (liveSlices.length > 1) {
        liveSlices.sort((a, b) {
          final aTime = a['slotStartTime'] as String? ?? '';
          final bTime = b['slotStartTime'] as String? ?? '';
          return aTime.compareTo(bTime);
        });
        
        // Check if one is in the currently active slot window
        for (final slice in liveSlices) {
          final startDt = TimeHelper.parseSessionTime(slice['slotStartTime'] ?? '', now);
          if (startDt != null && now.isAfter(startDt)) {
            return slice; // This slot has started — it's the active one
          }
        }
        return liveSlices.first;
      }
    }

    // Priority 2: earliest upcoming slot
    final upcomingSlices = slices.where((s) {
      final startTime = s['slotStartTime'] as String? ?? '';
      if (startTime.isEmpty) return false;
      final startDt = TimeHelper.parseSessionTime(startTime, now);
      return startDt != null && now.isBefore(startDt);
    }).toList();

    if (upcomingSlices.length == 1) return upcomingSlices.first;
    if (upcomingSlices.length > 1) {
      upcomingSlices.sort((a, b) {
        final aTime = a['slotStartTime'] as String? ?? '';
        final bTime = b['slotStartTime'] as String? ?? '';
        return aTime.compareTo(bTime);
      });
      return upcomingSlices.first;
    }

    // Ambiguous — return null to trigger the chooser
    return null;
  }

  void _navigateToSlice(Map<String, dynamic> slice, String tokenNumber) {
    final sessionId = slice['sessionId'] as String?;
    final slotId = slice['slotId'] as String?;
    final status = slice['statusCategory'] as String? ?? 'pending';

    if (sessionId != null) {
      ref.read(staffSelectedSessionIdProvider.notifier).state = sessionId;
    }
    if (slotId != null) {
      ref.read(staffSelectedSlotIdProvider.notifier).state = slotId;
    }
    // Set filter to match the token's actual status (don't force 'all')
    ref.read(staffSelectedFilterProvider.notifier).state = status;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Token #$tokenNumber found — showing in queue',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: StaffTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSliceChooser(List<Map<String, dynamic>> slices, String tokenNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Token #$tokenNumber',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: StaffTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Multiple active slices found. Choose one:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: StaffTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...slices.map((slice) {
                final sessionName = slice['sessionName'] ?? 'Session';
                final status = (slice['statusCategory'] as String? ?? 'pending').toUpperCase();
                final slotTime = slice['slotStartTime'] ?? '';

                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: StaffTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long, color: StaffTheme.primary, size: 20),
                  ),
                  title: Text(
                    sessionName,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${slotTime.isNotEmpty ? slotTime : 'N/A'} • $status',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: StaffTheme.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(ctx); // Close chooser
                    _navigateToSliceFromChooser(slice, tokenNumber);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSliceFromChooser(Map<String, dynamic> slice, String tokenNumber) {
    final sessionId = slice['sessionId'] as String?;
    final slotId = slice['slotId'] as String?;
    final status = slice['statusCategory'] as String? ?? 'pending';

    if (sessionId != null) {
      ref.read(staffSelectedSessionIdProvider.notifier).state = sessionId;
    }
    if (slotId != null) {
      ref.read(staffSelectedSlotIdProvider.notifier).state = slotId;
    }
    ref.read(staffSelectedFilterProvider.notifier).state = status;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Token #$tokenNumber found — showing in queue',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: StaffTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        backgroundColor: StaffTheme.statusSkipped,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            decoration: BoxDecoration(
              color: StaffTheme.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Token QR',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Point camera at student\'s QR code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          // Camera view
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Scan overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing 
                            ? StaffTheme.secondary 
                            : Colors.white.withValues(alpha: 0.5),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            'Locating token...',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
