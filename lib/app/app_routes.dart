class AppRoutes {
  // Auth
  static const String authNav = '/';
  static const String login = '/login';
  static const String resetPassword = '/reset-password';
  static const String otpVerification = '/otp-verification';
  static const String changePassword = '/change-password';
  static const String signup = '/signup';
  static const String createAccount = '/create-account';
  static const String getStarted = '/get-started';

  // Student
  static const String studentDashboard = '/student/dashboard';
  static const String studentOrders = '/student/orders';
  static const String studentToken = '/student/token';
  static const String studentProfile = '/student/profile';
  static const String studentNotifications = '/student/notifications';
  static const String studentNoNetwork = '/student/no-network';

  // Staff
  static const String staffDashboard = '/staff/dashboard';
  static const String staffKitchen = '/staff/kitchen';
  static const String staffProfile = '/staff/profile';
  static const String kitchenTv = '/kitchen-tv';

  // Admin
  static const String adminDashboard = '/admin/dashboard';
  static const String adminRelease = '/admin/release';
  static const String adminLiveMenu = '/admin/live-menu';
  static const String adminManageMenu = '/admin/manage-menu';
  static const String adminOrders = '/admin/orders';
  static const String adminReports = '/admin/reports';
  static const String adminNotifications = '/admin/notifications';
  static const String adminNoNetwork = '/admin/no-network';

  // Admin Profile Hub & Settings
  static const String adminProfile = '/admin/profile';
  static const String adminCanteenDetails = '/admin/profile/canteen-details';
  static const String adminSessionScheduler =
      '/admin/profile/session-scheduler';
  static const String adminSlotDefaults = '/admin/profile/slot-defaults';
  static const String adminStaffManagement = '/admin/profile/staff';
}
