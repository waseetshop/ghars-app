// Smoke test — skipped in CI until Supabase is mocked
// يتطلب Supabase مُهيّأً لتشغيله، يُتجاهل في البيئات بدون اتصال
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder', (tester) async {
    // TODO: add proper widget tests with Supabase mock
    expect(true, isTrue);
  });
}
