/// Returns an actual profile name, never an email address or placeholder.
String? studentName(Object? value) {
  if (value is! String) return null;
  final name = value.trim();
  if (name.isEmpty ||
      name.contains('@') ||
      name.toLowerCase() == 'um student' ||
      name.toLowerCase() == 'name unavailable') {
    return null;
  }
  return name;
}

String? accountStudentName(Map<String, dynamic>? metadata) {
  for (final key in ['name', 'full_name', 'display_name']) {
    final name = studentName(metadata?[key]);
    if (name != null) return name;
  }
  return null;
}
