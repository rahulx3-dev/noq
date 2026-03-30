import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_token_card.dart';
import '../../../core/utils/app_motion_tokens.dart';

class StaffAnimatedQueue extends StatefulWidget {
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;

  const StaffAnimatedQueue({super.key, required this.docs});

  @override
  State<StaffAnimatedQueue> createState() => _StaffAnimatedQueueState();
}

class _StaffAnimatedQueueState extends State<StaffAnimatedQueue> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  late List<DocumentSnapshot<Map<String, dynamic>>> _currentDocs;
  bool _hasInitialScrolled = false;

  @override
  void initState() {
    super.initState();
    _currentDocs = List.from(widget.docs);
    _checkInitialScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkInitialScroll() {
    if (_hasInitialScrolled) return;
    if (_currentDocs.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToFirstActionable();
    });
  }

  void _scrollToFirstActionable() {
    int targetIndex = -1;
    for (int i = 0; i < _currentDocs.length; i++) {
      final status = (_currentDocs[i].data()?['statusCategory'] as String? ?? 
                      _currentDocs[i].data()?['orderStatus'] as String? ?? 'pending').toLowerCase();
      if (status == 'ready' || status == 'pending') {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex > 0) {
      // Calculate precise offset 
      double offset = targetIndex * 155.0; 

      _hasInitialScrolled = true;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didUpdateWidget(StaffAnimatedQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    _processUpdates(widget.docs);
  }

  void _processUpdates(List<DocumentSnapshot<Map<String, dynamic>>> newDocs) {
    // 1. Check for focus scroll if we haven't or if list was empty
    if (!_hasInitialScrolled && newDocs.isNotEmpty) {
      _checkInitialScroll();
    }

    final oldIds = _currentDocs.map((d) => d.id).toList();
    final newIds = newDocs.map((d) => d.id).toList();

    // 1. Handle Removals
    for (int i = _currentDocs.length - 1; i >= 0; i--) {
      final id = _currentDocs[i].id;
      if (!newIds.contains(id)) {
        final removedItem = _currentDocs[i];
        _currentDocs.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildRemovedItem(removedItem, animation),
          duration: AppMotionTokens.standard,
        );
      }
    }

    // 2. Handle Insertions & Reorders
    for (int i = 0; i < newDocs.length; i++) {
      final id = newDocs[i].id;
      if (!oldIds.contains(id)) {
        _currentDocs.insert(i, newDocs[i]);
        _listKey.currentState?.insertItem(
          i,
          duration: AppMotionTokens.standard,
        );
      }
    }

    // Final sync
    setState(() {
      _currentDocs = List.from(newDocs);
    });
  }

  Widget _buildRemovedItem(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Animation<double> animation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.2), // Slide UP on removal
            end: Offset.zero,
          ).animate(animation),
          child: StaffTokenCard(order: doc.data()!, orderId: doc.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction != ScrollDirection.idle) {
            _hasInitialScrolled = true; // Stop auto-scrolling if user touches it
          }
        }
        return false;
      },
      child: AnimatedList(
        key: _listKey,
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        initialItemCount: _currentDocs.length,
        padding: const EdgeInsets.only(top: 8, bottom: 120),
        itemBuilder: (context, index, animation) {
          if (index >= _currentDocs.length) return const SizedBox.shrink();
          final doc = _currentDocs[index];
          final data = doc.data()!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 0), // Card already has internal margin
            child: FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: StaffTokenCard(order: data, orderId: doc.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
