import 'package:ailurus/features/events/presentation/event_editor_page.dart';
import 'package:ailurus/features/events/presentation/home_page.dart';
import 'package:ailurus/features/settings/presentation/settings_page.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/event/new',
      builder: (context, state) => const EventEditorPage(),
    ),
    GoRoute(
      path: '/event/:id',
      builder: (context, state) =>
          EventEditorPage(eventId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
