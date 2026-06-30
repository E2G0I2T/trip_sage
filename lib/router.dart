import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/trip_input_screen.dart';
import 'screens/trip_result_screen.dart';
import 'screens/trip_map_screen.dart';
import 'screens/trip_budget_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/input',
      builder: (context, state) => const TripInputScreen(),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return TripResultScreen(data: data);
      },
    ),
    GoRoute(
      path: '/map',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return TripMapScreen(
          destination: data['destination'] as String,
          days: (data['days'] as List).cast<Map>(),
        );
      },
    ),
    GoRoute(
      path: '/budget',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return TripBudgetScreen(
          destination: data['destination'] as String,
          days: (data['days'] as List).cast<Map>(),
          totalBudget: data['totalBudget'] as int,
        );
      },
    ),
  ],
);