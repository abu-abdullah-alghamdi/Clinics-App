import 'package:clinics_app/data.dart';
import 'package:clinics_app/services_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الأرقام بالإنجليزي', () {
    expect(fmtNum(2026), '2026');
    expect(normalizeDigits('٠٥٥١'), '0551');
  });

  test('تنسيق الوقت', () {
    expect(fmtClock(DateTime(2026, 11, 8, 16, 0)), '4:00 م');
    expect(fmtClock(DateTime(2026, 11, 8, 9, 5)), '9:05 ص');
    expect(fmtClock(DateTime(2026, 11, 8, 12, 30)), '12:30 م');
    expect(fmtClock(DateTime(2026, 11, 8, 0, 15)), '12:15 ص');
  });

  test('تنسيق المبالغ', () {
    expect(money(200), '200 $riyalSign');
    expect(spokenMoney(200), '200 ريال');
    expect(money(52.5), '52.50 $riyalSign');
  });
}
