import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _obscure = true;
  String? _error;
  String? _info;
  bool _left = false;
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    // Google sign-in finishes in the browser; the session arrives later as an
    // auth state change, so the screen listens instead of awaiting it.
    _auth = context.read<AuthProvider>()..addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated && !_auth.isGuest) _goHome();
  }

  void _goHome() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _google() async {
    setState(() {
      _error = null;
      _info = null;
    });
    final result = await _auth.signInWithGoogle();
    if (!mounted) return;
    if (!result.success) setState(() => _error = result.message);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _info = null;
    });
    final auth = context.read<AuthProvider>();
    final result = _signUp
        ? await auth.signUp(_email.text, _password.text, _name.text)
        : await auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (!result.success) {
      setState(() => _error = result.message);
    } else if (auth.isAuthenticated) {
      _goHome();
    } else {
      setState(() {
        _info = result.message;
        _signUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradient,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _signUp ? 'Create your account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.muted),
                    ),
                    const SizedBox(height: 32),
                    if (!auth.isConfigured) ...[
                      const _Banner(
                        color: AppColors.calories,
                        text:
                            'Cloud sync is not configured, so accounts are unavailable. '
                            'Continue as guest to use the app with data stored on this device.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_info != null) ...[
                      _Banner(color: AppColors.steps, text: _info!),
                      const SizedBox(height: 16),
                    ],
                    if (_signUp) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => Validators.required(v, 'Name'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: _signUp
                          ? Validators.password
                          : (v) => Validators.required(v, 'Password'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 24),
                    GradientButton(
                      label: _signUp ? 'Sign up' : 'Sign in',
                      loading: auth.isLoading,
                      onPressed: auth.isConfigured ? _submit : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: auth.isConfigured
                          ? () => setState(() {
                                _signUp = !_signUp;
                                _error = null;
                                _info = null;
                              })
                          : null,
                      child: Text(
                        _signUp
                            ? 'Already have an account? Sign in'
                            : "New here? Create an account",
                      ),
                    ),
                    if (auth.isConfigured) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: auth.isLoading ? null : _google,
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    OutlinedButton(
                      onPressed: () {
                        context.read<AuthProvider>().continueAsGuest();
                        Navigator.of(context).pushReplacementNamed('/home');
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Continue as guest'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Guest data stays on this device and is not synced.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: context.faint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final String text;

  const _Banner({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}
