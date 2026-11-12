import 'package:clinics_app/countries.dart';
import 'package:clinics_app/data.dart';
import 'package:clinics_app/services_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الأرقام بالإنجليزي', () {
    expect(fmtNum(2026), '2026');
    expect(normalizeDigits('٠٥٥١'), '0551');
  });

  test('تنسيق الوقت', () {
    expect(fmtTime(0), '4:00 م');
    expect(fmtTime(150), '6:30 م');
  });

  test('الجنسيات: السعودية أولها', () {
    expect(countries.first, saudiArabia);
    expect(countries.toSet().length, countries.length);
  });

  test('تنسيق المبالغ', () {
    expect(money(200), '200 $riyalSign');
    expect(spokenMoney(200), '200 ريال');
    expect(money(52.5), '52.50 $riyalSign');
  });
}
