import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:school_task_app/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SchoolTaskApp());

    expect(find.text('School Tasks'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
