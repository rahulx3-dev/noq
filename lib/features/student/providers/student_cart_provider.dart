import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/student_models.dart';

class StudentCartItem {
  final StudentMenuItem menuItem;
  int quantity;

  /// Per-item slot selection — set during checkout
  StudentMenuSlot? selectedSlot;

  StudentCartItem({
    required this.menuItem,
    this.quantity = 1,
    this.selectedSlot,
  });

  /// Unique key combining itemId AND sessionId to isolate same item across different sessions
  String get cartKey => '${menuItem.itemId}::${menuItem.sessionId}';

  StudentCartItem copyWith({int? quantity, StudentMenuSlot? selectedSlot}) {
    return StudentCartItem(
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
      selectedSlot: selectedSlot ?? this.selectedSlot,
    );
  }
}

class StudentCartNotifier extends StateNotifier<List<StudentCartItem>> {
  StudentCartNotifier() : super([]);

  void addToCart(StudentMenuItem item) {
    // Match on composite key (itemId + sessionId) so same item in different sessions is isolated
    final index = state.indexWhere((c) => c.cartKey == '${item.itemId}::${item.sessionId}');
    if (index >= 0) {
      if (state[index].quantity < item.remainingStock) {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == index)
              state[i].copyWith(quantity: state[i].quantity + 1)
            else
              state[i],
        ];
      }
    } else {
      if (item.remainingStock > 0) {
        state = [...state, StudentCartItem(menuItem: item, quantity: 1)];
      }
    }
  }

  /// Decrement using composite key (itemId + sessionId)
  void decrementQuantity(String itemId, String sessionId) {
    final key = '$itemId::$sessionId';
    final index = state.indexWhere((c) => c.cartKey == key);
    if (index >= 0) {
      if (state[index].quantity > 1) {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == index)
              state[i].copyWith(quantity: state[i].quantity - 1)
            else
              state[i],
        ];
      } else {
        removeFromCart(itemId, sessionId);
      }
    }
  }

  void removeFromCart(String itemId, String sessionId) {
    final key = '$itemId::$sessionId';
    state = state.where((c) => c.cartKey != key).toList();
  }

  void clearCart() {
    state = [];
  }

  /// Set the selected slot for a specific cart item (by composite key)
  void setSlotForItem(String itemId, String sessionId, StudentMenuSlot slot) {
    final key = '$itemId::$sessionId';
    state = [
      for (var c in state)
        if (c.cartKey == key) c.copyWith(selectedSlot: slot) else c,
    ];
  }

  /// Check if every cart item has a slot selected
  bool get allSlotsSelected => state.every((c) => c.selectedSlot != null);

  double get subtotal {
    return state.fold(
      0.0,
      (sum, item) => sum + (item.menuItem.priceSnapshot * item.quantity),
    );
  }

  double get totalItems {
    return state.fold(0.0, (sum, item) => sum + item.quantity);
  }
}

final studentCartProvider =
    StateNotifierProvider<StudentCartNotifier, List<StudentCartItem>>((ref) {
      return StudentCartNotifier();
    });

/// Wishlist Provider
class StudentWishlistNotifier extends StateNotifier<Set<String>> {
  StudentWishlistNotifier() : super({});

  void toggleFavorite(String itemId) {
    if (state.contains(itemId)) {
      state = state.where((id) => id != itemId).toSet();
    } else {
      state = {...state, itemId};
    }
  }

  bool isFavorite(String itemId) => state.contains(itemId);
}

final studentWishlistProvider =
    StateNotifierProvider<StudentWishlistNotifier, Set<String>>((ref) {
      return StudentWishlistNotifier();
    });
