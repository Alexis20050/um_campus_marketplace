import 'package:flutter_test/flutter_test.dart';
import 'package:um_campus_marketplace/utils/student_name.dart';

void main() {
  test('shows the saved student name without surrounding whitespace', () {
    expect(studentName('  Maria Santos  '), 'Maria Santos');
  });

  test('never presents an email or placeholder as a student name', () {
    for (final value in [
      null,
      '',
      '  ',
      'UM Student',
      'um student',
      'Name unavailable',
      'maria@umindanao.edu.ph',
      'Maria <maria@umindanao.edu.ph>',
      123,
    ]) {
      expect(studentName(value), isNull);
    }
  });

  test('uses signup and Google names without deriving names from email', () {
    expect(accountStudentName({'name': 'Maria Santos'}), 'Maria Santos');
    expect(
      accountStudentName({'name': 'UM Student', 'full_name': 'Juan Cruz'}),
      'Juan Cruz',
    );
    expect(
      accountStudentName({
        'name': 'juan@umindanao.edu.ph',
        'full_name': 'Juan Cruz',
      }),
      'Juan Cruz',
    );
    expect(accountStudentName({'email': 'juan@umindanao.edu.ph'}), isNull);
    expect(accountStudentName(null), isNull);
  });
}
