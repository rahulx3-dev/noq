import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/utils/session_status_resolver.dart';
import '../../../app/themes/student_theme.dart';
import '../providers/student_providers.dart';
import '../providers/student_cart_provider.dart';
import '../providers/student_orders_provider.dart';
import '../../../core/models/student_models.dart';
import '../services/student_notification_service.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sessionKeys = {};
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isMostOrderedExpanded = false;
  late AnimationController _driftController;
  bool _isRefreshing = false;

  // Banner auto-scroll
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBanner = 0;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      // Compute dynamic banner count from current data
      final mostOrdered = ref.read(mostOrderedItemsProvider);
      final dailyMenu = ref.read(todayStudentMenuProvider).value;
      final activeOrders = ref.read(studentActiveOrdersProvider);
      int bannerCount = 0;
      if (dailyMenu != null) {
        final hasLowStock = dailyMenu.sessions
            .expand((s) => s.items)
            .any((it) => it.isAvailable && it.remainingStock > 0 && it.remainingStock <= 5);
        if (hasLowStock) bannerCount++;
      }
      if (activeOrders.isNotEmpty) bannerCount++;
      if (mostOrdered.isNotEmpty) bannerCount++;
      if (bannerCount <= 1) return;
      final nextPage = (_currentBanner + 1) % bannerCount;
      setState(() => _currentBanner = nextPage);
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _driftController.dispose();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _scrollToSession(String sessionId) {
    final key = _sessionKeys[sessionId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final dailyMenuAsync = ref.watch(todayStudentMenuProvider);
    final categoriesMapObj = ref.watch(categoriesMapProvider);

    final userName =
        userProfileAsync.value?.displayName.split(' ').first ?? 'Student';
    final categoriesMap = categoriesMapObj.value ?? {};

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildLeftSidebar(dailyMenuAsync.value),
      endDrawer: _buildRightWishlist(),
      backgroundColor: StudentTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(userName),
            _buildSearchBar(),
            _buildCategoryChips(dailyMenuAsync.value, categoriesMap),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(todayStudentMenuProvider);
                  ref.invalidate(categoriesMapProvider);
                  ref.invalidate(userProfileProvider);
                  ref.invalidate(mostOrderedItemsProvider);
                },
                color: StudentTheme.primaryOrange,
                backgroundColor: StudentTheme.surfaceVariant,
                child: dailyMenuAsync.when(
                  data: (menu) {
                    if (menu == null || !menu.isReleased) {
                      return ListView(
                        children: [
                          _buildEmptyState(),
                        ],
                      );
                    }

                    final now = DateTime.now();
                    
                    // Pre-calculate if there are any orderable pre-ready items anywhere in the menu
                    final hasAnyOrderablePreReady = menu.sessions.any((s) => s.items.any((it) => 
                      it.isPreReady && it.isAvailable && it.remainingStock > 0));

                    final activeSessionsRaw = menu.sessions.where((session) {
                      final state = SessionStatusResolver.computeSessionState(
                        selectedDate: DateTime.parse(menu.date),
                        now: now,
                        startTimeStr: session.startTime,
                        endTimeStr: session.endTime,
                        isReleased: menu.isReleased,
                      );
                      // Only show sessions that haven't ended yet for the student
                      return !state.isPast;
                    });

                    final activeSessions = List<StudentMenuSession>.from(
                      activeSessionsRaw,
                    );

                    // Sort by session start time ascending
                    activeSessions.sort((a, b) {
                      try {
                        final format = DateFormat('hh:mm a');
                        final timeA = format.parse(a.startTime);
                        final timeB = format.parse(b.startTime);
                        return timeA.compareTo(timeB);
                      } catch (e) {
                        return 0;
                      }
                    });

                    if (activeSessions.isEmpty && !hasAnyOrderablePreReady) {
                      return ListView(
                        children: [
                          _buildEmptyState(),
                        ],
                      );
                    }

                    return _buildMenuContent(
                      menu,
                      activeSessions,
                      categoriesMap,
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) {
                    final errorStr = e.toString().toLowerCase();
                    if (errorStr.contains('network') || errorStr.contains('unavailable')) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          context.go(AppRoutes.studentNoNetwork);
                        }
                      });
                      return const SizedBox.shrink();
                    }
                    
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: StudentTheme.statusRed,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading menu',
                                    style: GoogleFonts.lexend(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: StudentTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    e.toString(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.lexend(
                                      fontSize: 14,
                                      color: StudentTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: () {
                                      ref.invalidate(todayStudentMenuProvider);
                                      ref.invalidate(categoriesMapProvider);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: StudentTheme.primaryOrange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1), // gray-200
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF111827),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $userName!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: const Color(0xFF111827), // gray-900
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hungry for something new?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280), // gray-500
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildHeaderAction(
                icon: Icons.shopping_cart_outlined,
                onTap: () => context.push('/student/cart'),
                badgeCount: ref.watch(studentCartProvider).length,
              ),
              const SizedBox(width: 12),
              _buildHeaderAction(
                icon: Icons.notifications_none_rounded,
                onTap: () => context.push('/student/notifications'),
                hasDot:
                    (ref.watch(unreadNotificationsCountProvider).value ?? 0) >
                    0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
    bool hasDot = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              color: const Color(0xFF111827),
              size: 24,
            ),
            if (badgeCount > 0 || hasDot)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444), // red-500
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  final TextEditingController _searchController = TextEditingController();

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Elegant Search Bar with Sharp Edges
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero, // Sharp edges as requested
                border: Border.all(color: const Color(0xFF111827), width: 1.5), // gray-900 border
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _searchQuery = val.trim().toLowerCase()),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for food...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF111827),
                    size: 24,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Separated Wishlist Button with Sharp Edges and Light Red Heart
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white, // White background to make the red heart pop
                borderRadius: BorderRadius.zero, // Sharp edges as requested
                border: Border.all(color: const Color(0xFF111827), width: 1.5), // gray-900 border
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF4D4D), // Light Red Heart symbol
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(
    StudentDailyMenu? menu,
    Map<String, String> categoriesMap,
  ) {
    final List<String> catNames = ['All'];
    catNames.addAll(categoriesMap.values.where((v) => v.isNotEmpty));

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: catNames.toSet().map((cat) {
            final isActive = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.black : Colors.white,
                    border: isActive
                        ? null
                        : Border.all(color: const Color(0xFFF9FAFB), width: 1), // gray-50
                    borderRadius: BorderRadius.circular(999), // rounded-full
                    boxShadow: isActive
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFF4B5563), // gray-600
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuContent(
    StudentDailyMenu menu,
    List<StudentMenuSession> sessions,
    Map<String, String> categoriesMap,
  ) {
    // Collect all pre-ready items across sessions (full menu, not just active ones)
    final preReadyItemsMap = <String, StudentMenuItem>{};
    for (var session in menu.sessions) {
      for (var item in session.items) {
        if (item.isPreReady && item.isAvailable && !preReadyItemsMap.containsKey(item.itemId)) {
          preReadyItemsMap[item.itemId] = item;
        }
      }
    }
    final preReadyItems = preReadyItemsMap.values.where((it) {
      if (_searchQuery.isNotEmpty &&
          !it.nameSnapshot.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_selectedCategory != 'All') {
        bool matches = false;
        if (it.categoryIdsSnapshot.isNotEmpty) {
          for (final cid in it.categoryIdsSnapshot) {
            final cName = categoriesMap[cid] ?? cid;
            if (cName == _selectedCategory) {
              matches = true;
              break;
            }
          }
        } else {
          final cName = categoriesMap[it.categoryIdSnapshot] ?? it.categoryIdSnapshot;
          if (cName == _selectedCategory) matches = true;
        }
        if (!matches) return false;
      }
      return true;
    }).toList();

    final hasPreReady = preReadyItems.isNotEmpty;
    // +1 for Most Ordered, +1 for Banner
    const headerCount = 2;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: sessions.length + headerCount + (hasPreReady ? 1 : 0),
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return _buildBannerSection();
        }
        if (idx == 1) {
          return _buildMostOrderedSection();
        }

        // Ready-Made section (Prominent placement after Most Ordered)
        if (hasPreReady && idx == 2) {
          return _buildPreReadySection(preReadyItems);
        }

        final hasPreOffset = hasPreReady ? 1 : 0;
        final sessionIdx = idx - headerCount - hasPreOffset;
        if (sessionIdx < 0) return const SizedBox.shrink(); // Safety
        
        final session = sessions[sessionIdx];
        final sessionKey = _sessionKeys.putIfAbsent(
          session.sessionId,
          () => GlobalKey(),
        );

        // Filter out pre-ready items from per-session grid
        final itemsRaw = session.items.where((it) {
          if (it.isPreReady) return false; // Shown in separate section
          if (!it.isAvailable) return false;
          if (_searchQuery.isNotEmpty &&
              !it.nameSnapshot.toLowerCase().contains(_searchQuery)) {
            return false;
          }
          if (_selectedCategory != 'All') {
            bool matches = false;
            if (it.categoryIdsSnapshot.isNotEmpty) {
              for (final cid in it.categoryIdsSnapshot) {
                final cName = categoriesMap[cid] ?? cid;
                if (cName == _selectedCategory) {
                  matches = true;
                  break;
                }
              }
            } else {
              final cName = categoriesMap[it.categoryIdSnapshot] ?? it.categoryIdSnapshot;
              if (cName == _selectedCategory) matches = true;
            }
            if (!matches) return false;
          }
          return true;
        });

        final items = List<StudentMenuItem>.from(itemsRaw);

        // Sort items by category name alphabetically
        items.sort((a, b) {
          final catA = categoriesMap[a.categoryIdSnapshot] ?? '';
          final catB = categoriesMap[b.categoryIdSnapshot] ?? '';
          return catA.compareTo(catB);
        });

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          key: sessionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                'Today\'s Menu - ${session.sessionNameSnapshot}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827), // gray-900
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildFoodCard(
                  items[index],
                  session.sessionNameSnapshot,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreReadySection(List<StudentMenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pre-ready items',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Optional: "Quick Buy" or similar badge
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildFoodCard(
              items[index],
              'Ready-Made',
            );
          },
        ),
      ],
    );
  }


  Color _getStockColor(int stock) {
    if (stock <= 0) return const Color(0xFF6B7280); // gray-500
    if (stock < 5) return const Color(0xFFEF4444); // red-500
    if (stock < 10) return const Color(0xFFF59E0B); // amber-500
    return const Color(0xFF111827); // Solid dark for high contrast
  }

  Widget _buildBannerSection() {
    final mostOrdered = ref.watch(mostOrderedItemsProvider);
    final trendingItem = mostOrdered.isNotEmpty ? mostOrdered.first : null;

    final dailyMenu = ref.watch(todayStudentMenuProvider).value;
    StudentMenuItem? lowStockItem;
    if (dailyMenu != null) {
      final allItems = dailyMenu.sessions
          .expand((s) => s.items)
          .where((it) => it.isAvailable && it.remainingStock > 0 && it.remainingStock <= 5)
          .toList()
        ..sort((a, b) => a.remainingStock.compareTo(b.remainingStock));
      if (allItems.isNotEmpty) lowStockItem = allItems.first;
    }

    // Get first active order to show token info
    final activeOrders = ref.watch(studentActiveOrdersProvider);
    Map<String, dynamic>? activeToken;
    if (activeOrders.isNotEmpty) {
      final ready = activeOrders.where((o) =>
        (o['orderStatus'] ?? '').toString().toLowerCase() == 'ready').toList();
      activeToken = ready.isNotEmpty ? ready.first : activeOrders.first;
    }

    final List<Widget> banners = [];

    if (lowStockItem != null) {
      banners.add(_bannerCard(
        color: const Color(0xFF991B1B),
        tag: '⚠ LOW STOCK',
        title: 'Only ${lowStockItem.remainingStock} left!',
        subtitle: '${lowStockItem.nameSnapshot} is almost gone.\nOrder before it runs out.',
        emoji: '🍛',
      ));
    }

    if (activeToken != null) {
      final tokenNum = activeToken['tokenNumber']?.toString() ?? '-';
      // Derive status correctly
      final List<dynamic> tItems = activeToken['items'] ?? [];
      int servedCount = 0;
      int readyCount = 0;
      int totalCount = tItems.length;

      for (final item in tItems) {
        final isPreReady = item['isPreReady'] ?? item['isReadyMade'] ?? false;
        final rawStatus = (item['itemStatus'] as String? ?? 'pending').toLowerCase();
        final iStatus = isPreReady 
            ? (rawStatus == 'served' || rawStatus == 'skipped' || rawStatus == 'cancelled' ? rawStatus : 'ready') 
            : rawStatus;

        if (iStatus == 'served') servedCount++;
        else if (iStatus == 'ready') readyCount++;
      }

      String status = 'Pending';
      if (totalCount > 0) {
        if (servedCount == totalCount) status = 'Served';
        else if (servedCount + readyCount == totalCount) status = 'Ready';
        else if (servedCount > 0) status = 'Partial';
      }

      banners.add(_bannerCard(
        color: const Color(0xFF1E3A5F),
        tag: '🎫 YOUR TOKEN',
        title: '#$tokenNum',
        subtitle: 'Status: ${status.toUpperCase()}\nCheck the Token tab for details.',
        emoji: '✅',
      ));
    }

    if (trendingItem != null) {
      banners.add(_bannerCard(
        color: const Color(0xFF3B2A00),
        tag: '🔥 TRENDING',
        title: trendingItem['name'] ?? '',
        subtitle: 'Most ordered right now\namong students today!',
        emoji: '🍱',
      ));
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: PageView(
              controller: _bannerController,
              onPageChanged: (i) => setState(() => _currentBanner = i),
              children: banners,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBanner == i ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBanner == i
                    ? StudentTheme.accent
                    : Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _bannerCard({
    required Color color,
    required String tag,
    required String title,
    required String subtitle,
    required String emoji,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Text(emoji, style: const TextStyle(fontSize: 44)),
          ],
        ),
      ),
    );
  }

  Widget _buildMostOrderedSection() {
    return Consumer(
      builder: (context, ref, _) {
        final mostOrderedAsync = ref.watch(mostOrderedItemsProvider);
        final orderableItems = mostOrderedAsync.where((it) {
          final count = it['frequency'] ?? 0;
          return it['isAvailableToday'] == true && count > 0;
        }).toList();
        
        if (orderableItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Most ordered by you',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827), // gray-900
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isMostOrderedExpanded = !_isMostOrderedExpanded;
                      });
                    },
                    child: Text(
                      _isMostOrderedExpanded ? 'Show Less' : 'See All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF4B3A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isMostOrderedExpanded ? 480 : 250,
              child: _isMostOrderedExpanded
                  ? GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: orderableItems.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return _buildMostOrderedCard(orderableItems[index], ref);
                      },
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: orderableItems.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: SizedBox(
                            width: 170,
                            child: _buildMostOrderedCard(orderableItems[index], ref),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMostOrderedCard(Map<String, dynamic> data, WidgetRef ref) {
    final StudentMenuItem? currentItem = data['currentItem'];
    final bool isAvailable = data['isAvailableToday'];
    
    final cart = ref.watch(studentCartProvider);
    final favorites = ref.watch(favoritesProvider);
    final itemId = data['itemId'] as String;
    final cartItem = currentItem != null 
        ? cart.firstWhere((i) => i.menuItem.itemId == currentItem.itemId, 
            orElse: () => StudentCartItem(menuItem: currentItem, quantity: 0))
        : null;

    bool outOfStock = currentItem != null && currentItem.remainingStock <= 0;
    bool isDisabled = !isAvailable || outOfStock;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black, // Match Order Card
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black, // Darker background for image
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                    Image.network(
                      data['imageUrl'],
                      fit: BoxFit.cover,
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.fastfood_rounded,
                        color: Colors.white24,
                        size: 32,
                      ),
                    ),
                  // Heart Toggle for Most Ordered
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPulseIndicator(itemId),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                final favs = ref.read(favoritesProvider);
                                if (favs.contains(itemId)) {
                                  ref.read(favoritesProvider.notifier).state =
                                      favs.where((id) => id != itemId).toSet();
                                } else {
                                  ref.read(favoritesProvider.notifier).state = {
                                    ...favs,
                                    itemId,
                                  };
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  favorites.contains(itemId)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_outline_rounded,
                                  color: favorites.contains(itemId)
                                      ? StudentTheme.statusRed
                                      : Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  // Stock Indicator for Most Ordered
                  if (currentItem != null && !isDisabled)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStockColor(currentItem.remainingStock),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${currentItem.remainingStock} LEFT',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  if (isDisabled)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text(
                        outOfStock ? 'Sold Out' : 'Unavailable',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data['name'] ?? 'Item',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${(data['price'] ?? 0).toInt()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: StudentTheme.statusGreen,
                ),
              ),
              if (isAvailable && currentItem != null)
                if (cartItem == null || cartItem.quantity == 0)
                  GestureDetector(
                    onTap: !isDisabled
                        ? () => ref.read(studentCartProvider.notifier).addToCart(currentItem)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDisabled ? Colors.white12 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Add',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? Colors.white24 : Colors.black,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => ref.read(studentCartProvider.notifier).decrementQuantity(currentItem.itemId, currentItem.sessionId),
                          child: const Icon(Icons.remove_rounded, color: Colors.white, size: 16),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${cartItem.quantity}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: cartItem.quantity < currentItem.remainingStock
                              ? () => ref.read(studentCartProvider.notifier).addToCart(currentItem)
                              : null,
                          child: Icon(
                            Icons.add_rounded, 
                            color: cartItem.quantity < currentItem.remainingStock ? Colors.white : Colors.white24, 
                            size: 16
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(StudentMenuItem item, String sessionName) {
    return Consumer(
      builder: (context, ref, _) {
        final menu = ref.watch(todayStudentMenuProvider).value;
        final bool isReleased = menu?.isReleased ?? false;

        bool isUnavailable = !item.isAvailableSnapshot;
        bool outOfStock = item.remainingStock <= 0;
        bool isDisabled = isUnavailable || outOfStock || !isReleased;

        final cart = ref.watch(studentCartProvider);
        final favorites = ref.watch(favoritesProvider);
        final itemId = item.itemId;

        // Match on composite key (itemId::sessionId) to isolate multi-session same items
        final cartKey = '${item.itemId}::${item.sessionId}';
        final cartItem = cart.firstWhere(
          (i) => i.cartKey == cartKey,
          orElse: () => StudentCartItem(menuItem: item, quantity: 0),
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.black, // Match Order Card
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image and Status
              Expanded(
                flex: 5,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black, // Darker background for image
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.imageUrlSnapshot.isNotEmpty)
                        Image.network(
                          item.imageUrlSnapshot,
                          fit: BoxFit.cover,
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.fastfood_rounded,
                            color: Colors.white24,
                            size: 32,
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPulseIndicator(itemId),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                final favs = ref.read(favoritesProvider);
                                if (favs.contains(itemId)) {
                                  ref.read(favoritesProvider.notifier).state =
                                      favs.where((id) => id != itemId).toSet();
                                } else {
                                  ref.read(favoritesProvider.notifier).state = {
                                    ...favs,
                                    itemId,
                                  };
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  favorites.contains(itemId)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_outline_rounded,
                                  color: favorites.contains(itemId)
                                      ? StudentTheme.statusRed
                                      : Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stock Indicator
                      if (!isDisabled)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStockColor(item.remainingStock),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${item.remainingStock} LEFT',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      // Out of Stock Cover
                      if (isDisabled)
                        Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: Text(
                            outOfStock ? 'Sold Out' : 'Unavailable',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Content Text
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.nameSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${item.priceSnapshot.toInt()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: StudentTheme.statusGreen,
                          ),
                        ),
                        if (!isDisabled)
                          if (cartItem.quantity == 0)
                            GestureDetector(
                              onTap: () => ref.read(studentCartProvider.notifier).addToCart(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Add',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => ref.read(studentCartProvider.notifier).decrementQuantity(item.itemId, item.sessionId),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      child: const Icon(Icons.remove_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      '${cartItem.quantity}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: cartItem.quantity < item.remainingStock
                                        ? () => ref.read(studentCartProvider.notifier).addToCart(item)
                                        : null,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      child: Icon(
                                        Icons.add_rounded, 
                                        color: cartItem.quantity < item.remainingStock ? Colors.white : Colors.white24, 
                                        size: 18
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Drifting Icon Section
          AnimatedBuilder(
            animation: _driftController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -10 * _driftController.value),
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Drifting Moon/Sleep Icons
                Positioned(
                  top: -20,
                  right: -10,
                  child: Row(
                    children: [
                      Icon(
                        Icons.bedtime_rounded,
                        size: 24,
                        color: const Color(0xFF302F2C).withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 4),
                      Transform.rotate(
                        angle: -0.2,
                        child: Icon(
                          Icons.bedtime_rounded,
                          size: 32,
                          color: const Color(0xFF302F2C).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Skillet Icon
                Column(
                  children: [
                    const Icon(
                      Icons.soup_kitchen_rounded, // Best available alternative to mallet/skillet in standard set
                      size: 120,
                      color: Color(0xFF302F2C),
                      weight: 100,
                    ),
                    const SizedBox(height: 8),
                    // Shadow Pill
                    Container(
                      height: 6,
                      width: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF302F2C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'The kitchen is still waking up...',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF302F2C),
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Our chefs are working their magic! Stay tuned as we prepare today's fresh menu for you.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: const Color(0xFF6B7280), // gray-500
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Refresh Button with State
          GestureDetector(
            onTap: _isRefreshing
                ? null
                : () async {
                    setState(() => _isRefreshing = true);
                    // Invalidate both daily menu and categories
                    ref.invalidate(todayStudentMenuProvider);
                    ref.invalidate(categoriesMapProvider);
                    
                    // Add a small perceived delay for 'magic'
                    await Future.delayed(const Duration(seconds: 1));
                    
                    if (mounted) {
                      setState(() => _isRefreshing = false);
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF302F2C),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF302F2C).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRefreshing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _isRefreshing ? 'Refreshing...' : 'Check Again',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar(StudentDailyMenu? menu) {
    return Drawer(
      backgroundColor: Colors.white,
      width: 280,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
              child: Row(
                children: [
                  Text(
                    "Today's menu",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827), // gray-900
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: menu == null || !menu.isReleased
                  ? Center(
                      child: Text(
                        "No menu items live.",
                        style: GoogleFonts.plusJakartaSans(
                          color: StudentTheme.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ...menu.sessions.expand((session) {
                          return session.items.map((item) {
                            if (item.nameSnapshot.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _scrollToSession(session.sessionId);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  item.nameSnapshot,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF6B7280), // gray-500
                                  ),
                                ),
                              ),
                            );
                          });
                        }),
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightWishlist() {
    return Drawer(
      backgroundColor: StudentTheme.background,
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "Favourites",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("❤️", style: TextStyle(fontSize: 22)),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: StudentTheme.surfaceVariant,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: StudentTheme.border, height: 1),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final favMetadata = ref.watch(favoriteItemsMetadataProvider);

                  if (favMetadata.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 64,
                            color: StudentTheme.textTertiary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No favorites yet",
                            style: GoogleFonts.plusJakartaSans(
                              color: StudentTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: favMetadata.length,
                    itemBuilder: (context, idx) {
                      final data = favMetadata[idx];
                      final itemId = data['itemId'] as String;
                      final StudentMenuItem? currentItem = data['currentItem'];
                      final bool isAvailableToday = data['isAvailableToday'];
                      
                      final cart = ref.watch(studentCartProvider);
                      final cartItem = currentItem != null 
                          ? cart.firstWhere((i) => i.menuItem.itemId == currentItem.itemId, 
                              orElse: () => StudentCartItem(menuItem: currentItem, quantity: 0))
                          : null;

                      bool outOfStock = currentItem != null && currentItem.remainingStock <= 0;
                      // It's unavailable if not in today's released menu OR out of stock
                      bool isUnavailable = !isAvailableToday || outOfStock;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.black, // Premium Black matching food cards
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Image Area with Heart Toggle & Unavailable Overlay
                            SizedBox(
                              height: 100, // Compact height for drawer
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                                    Image.network(
                                      data['imageUrl'],
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    const Center(
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        color: Colors.white12,
                                        size: 40,
                                      ),
                                    ),
                                  // Heart Toggle
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () {
                                        final favs = ref.read(favoritesProvider);
                                        ref.read(favoritesProvider.notifier).state =
                                            favs.where((id) => id != itemId).toSet();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Colors.black26,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.favorite_rounded,
                                          color: StudentTheme.statusRed,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // "Unavailable Today" Overlay
                                  if (isUnavailable)
                                    Container(
                                      color: Colors.black54,
                                      alignment: Alignment.center,
                                      child: Text(
                                        outOfStock ? 'Sold Out' : 'Unavailable Today',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // 2. Info Area
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? 'Item',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹${(data['price'] ?? 0).toInt()}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: StudentTheme.statusGreen,
                                        ),
                                      ),
                                      if (currentItem != null && isAvailableToday)
                                        if (cartItem == null || cartItem.quantity == 0)
                                          GestureDetector(
                                            onTap: !outOfStock
                                                ? () => ref.read(studentCartProvider.notifier).addToCart(currentItem)
                                                : null,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: outOfStock ? Colors.white12 : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Add',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: outOfStock ? Colors.white24 : Colors.black,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                            ),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove, size: 14, color: Colors.white),
                                                  onPressed: () => ref.read(studentCartProvider.notifier).decrementQuantity(itemId, currentItem.sessionId),
                                                ),
                                                Text(
                                                  "${cartItem.quantity}",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                                  onPressed: cartItem.quantity < currentItem.remainingStock
                                                      ? () => ref.read(studentCartProvider.notifier).addToCart(currentItem)
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/student/cart');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: StudentTheme.background,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Go to Cart",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseIndicator(String itemId) {
    return Consumer(
      builder: (context, ref, _) {
        final level = ref.watch(foodPopularityProvider(itemId));
        if (level == PopularityLevel.normal) return const SizedBox.shrink();

        String emoji = '';
        String label = '';
        Color color = Colors.grey;

        switch (level) {
          case PopularityLevel.popular:
            emoji = '🔥';
            label = 'POPULAR';
            color = const Color(0xFFEF4444); // Red-500
            break;
          case PopularityLevel.trending:
            emoji = '📈';
            label = 'TRENDING';
            color = const Color(0xFF3B82F6); // Blue-500
            break;
          case PopularityLevel.fresh:
            emoji = '✨';
            label = 'NEW';
            color = const Color(0xFF10B981); // Emerald-500
            break;
          case PopularityLevel.rare:
            emoji = '💎';
            label = 'RARE';
            color = const Color(0xFF8B5CF6); // Violet-500
            break;
          default:
            return const SizedBox.shrink();
        }

        return PulseIndicator(
          emoji: emoji,
          label: label,
          color: color,
        );
      },
    );
  }
}

class PulseIndicator extends StatefulWidget {
  final String emoji;
  final String label;
  final Color color;

  const PulseIndicator({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.emoji,
              style: const TextStyle(fontSize: 10),
            ),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: widget.color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
