class AuthValidators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final RegExp _nameRegex = RegExp(r"^[A-Za-z][A-Za-z '.-]{1,49}$");

  static const Set<String> _blockedEmailDomains = {
    'mailinator.com',
    'tempmail.com',
    '10minutemail.com',
    'guerrillamail.com',
    'yopmail.com',
    'trashmail.com',
    'dispostable.com',
    'fakeinbox.com',
  };

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Full name is required';
    if (!_nameRegex.hasMatch(name)) return 'Enter a valid full name';
    return null;
  }

  static String? validateEmail(String? value) {
    final email = (value ?? '').trim().toLowerCase();
    if (email.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address';

    final parts = email.split('@');
    if (parts.length != 2) return 'Enter a valid email address';
    if (_blockedEmailDomains.contains(parts[1])) {
      return 'Disposable emails are not allowed';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final rules = passwordRules(value ?? '');
    if ((value ?? '').isEmpty) return 'Password is required';
    if (!rules.isValid) {
      return 'Password does not meet all requirements';
    }
    return null;
  }

  static PasswordRules passwordRules(String password) {
    return PasswordRules(
      minLength: password.length >= 8,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasNumber: RegExp(r'[0-9]').hasMatch(password),
      hasSpecial: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    );
  }

  static String? validateConfirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }
}

class PasswordRules {
  const PasswordRules({
    required this.minLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecial,
  });

  final bool minLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecial;

  bool get isValid =>
      minLength && hasUppercase && hasLowercase && hasNumber && hasSpecial;
}
