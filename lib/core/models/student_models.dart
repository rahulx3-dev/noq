// Models for student read-only view

class StudentMenuSlot {
  final String id;
  final String startTime;
  final String endTime;
  final int remainingCapacity;
  final bool isEnabled;

  StudentMenuSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.remainingCapacity,
    required this.isEnabled,
  });

  factory StudentMenuSlot.fromMap(String id, Map<String, dynamic> data) {
    return StudentMenuSlot(
      id: id,
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      remainingCapacity: data['remainingCapacity'] ?? 0,
      isEnabled: data['isEnabled'] ?? true,
    );
  }

  bool get isAvailable => remainingCapacity > 0 && isEnabled;
}

class StudentMenuItem {
  final String itemId;
  final String nameSnapshot;
  final double priceSnapshot;
  final String imageUrlSnapshot;
  final String categoryIdSnapshot;
  final List<String> categoryIdsSnapshot;
  final String descriptionSnapshot;
  final bool isAvailableSnapshot;
  final int remainingStock;
  final bool isPreReady; // Added
  final String sessionId; // Helper field to easily know parent session
  final String sessionNameSnapshot; // Added for order root access

  StudentMenuItem({
    required this.itemId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.imageUrlSnapshot,
    required this.categoryIdSnapshot,
    this.categoryIdsSnapshot = const [],
    required this.descriptionSnapshot,
    required this.isAvailableSnapshot,
    required this.remainingStock,
    this.isPreReady = false, // Added
    required this.sessionId,
    required this.sessionNameSnapshot,
  });

  factory StudentMenuItem.fromMap(
    String id,
    Map<String, dynamic> data,
    String sessionId,
    String sessionName,
  ) {
    return StudentMenuItem(
      itemId: data['itemId'] ?? id,
      nameSnapshot: data['nameSnapshot'] ?? '',
      priceSnapshot: (data['priceSnapshot'] ?? 0.0).toDouble(),
      imageUrlSnapshot: data['imageUrlSnapshot'] ?? '',
      categoryIdSnapshot: data['categoryIdSnapshot'] ?? '',
      categoryIdsSnapshot: List<String>.from(data['categoryIdsSnapshot'] ?? data['categoryIds'] ?? []),
      descriptionSnapshot: data['descriptionSnapshot'] ?? '',
      isAvailableSnapshot:
          data['isAvailable'] ?? data['isAvailableSnapshot'] ?? true,
      remainingStock: data['remainingStock'] ?? 0,
      isPreReady: data['isPreReady'] ?? data['isReadyMade'] ?? false,
      sessionId: sessionId,
      sessionNameSnapshot: sessionName,
    );
  }

  bool get isAvailable => isAvailableSnapshot && remainingStock > 0;
}

class StudentMenuSession {
  final String sessionId;
  final String sessionNameSnapshot;
  final String startTime;
  final String endTime;
  final List<StudentMenuItem> items;
  final List<StudentMenuSlot> slots;

  StudentMenuSession({
    required this.sessionId,
    required this.sessionNameSnapshot,
    required this.startTime,
    required this.endTime,
    required this.items,
    required this.slots,
  });

  factory StudentMenuSession.fromMap(
    String id,
    Map<String, dynamic> data,
    List<StudentMenuItem> items,
    List<StudentMenuSlot> slots,
  ) {
    return StudentMenuSession(
      sessionId: data['sessionId'] ?? id,
      sessionNameSnapshot: data['sessionNameSnapshot'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      items: items,
      slots: slots,
    );
  }
}

class StudentDailyMenu {
  final String date;
  final String status;
  final List<StudentMenuSession> sessions;

  StudentDailyMenu({
    required this.date,
    required this.status,
    required this.sessions,
  });

  factory StudentDailyMenu.fromMap(
    String id,
    Map<String, dynamic> data,
    List<StudentMenuSession> sessions,
  ) {
    return StudentDailyMenu(
      date: data['date'] ?? id,
      status: data['status'] ?? 'pending',
      sessions: sessions,
    );
  }

  bool get isReleased => status == 'released';
}
