class Validators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? v, [String field = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  /// Optional non-negative whole number (empty is allowed).
  static String? optionalInt(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a whole number';
    return null;
  }

  static String? optionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a number';
    return null;
  }
}
