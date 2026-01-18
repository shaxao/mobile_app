import 'package:go_router/go_router.dart';
import '../features/home/home_page.dart';
import '../features/borrow/borrow_page.dart';
import '../features/products/products_page.dart';
import '../features/order/order_page.dart';
import '../features/ledger/ledger_page.dart';
import '../features/attendance/attendance_page.dart';
import '../features/sales/sales_summary_page.dart';
import '../features/revenue/revenue_page.dart';
import '../features/weekly/weekly_schedule_page.dart';
import '../features/schedule_ai/schedule_ai_page.dart';
import '../features/settings/settings_page.dart';
import '../features/schedule/daily_schedule_page.dart';
import '../features/menu/menu_admin_page.dart';

GoRouter createRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(path: '/borrow', builder: (context, state) => const BorrowPage()),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsPage(),
      ),
      GoRoute(path: '/order', builder: (context, state) => const OrderPage()),
      GoRoute(path: '/ledger', builder: (context, state) => const LedgerPage()),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendancePage(),
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const SalesSummaryPage(),
      ),
      GoRoute(
        path: '/revenue',
        builder: (context, state) => const RevenuePage(),
      ),
      GoRoute(
        path: '/weekly',
        builder: (context, state) => const WeeklySchedulePage(),
      ),
      GoRoute(
        path: '/schedule-ai',
        builder: (context, state) => const ScheduleAIPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final showTutorial = extra?['tutorial'] as bool? ?? false;
          return SettingsPage(showTutorial: showTutorial);
        },
      ),
      GoRoute(
        path: '/daily',
        builder: (context, state) =>
            DailySchedulePage(initialDate: state.uri.queryParameters['date']),
      ),
      GoRoute(
        path: '/menu',
        builder: (context, state) => const MenuAdminPage(),
      ),
    ],
  );
}
