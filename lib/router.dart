import 'package:go_router/go_router.dart';
import 'screens/trip_input_screen.dart';
import 'screens/trip_result_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TripInputScreen(),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return TripResultScreen(data: data);
      },
    ),
  ],
);