import 'package:ailurus/app/app.dart';
import 'package:ailurus/features/events/application/providers.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('app boots to the home empty state', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sortedOccurrencesProvider.overrideWith(
            (Ref ref) =>
                const AsyncData<List<EventOccurrence>>(<EventOccurrence>[]),
          ),
        ],
        child: const AilurusApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('Ailurus'), findsOneWidget);
    expect(find.text('从最重要的日子开始记录。'), findsOneWidget);
  });
}
