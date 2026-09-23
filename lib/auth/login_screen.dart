// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/language_service.dart';
import '../services/biometric_service.dart';
import '../widgets/animation_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _biometricService = BiometricService();
  final _passwordCtrl = TextEditingController();

  bool _canCheckBiometrics = false;
  bool _biometricEnabled = false;

  // MID Parts
  final _midFamilyCtrl = TextEditingController();
  final _midSubFamilyCtrl = TextEditingController();
  final _midRandomCtrl = TextEditingController();

  // Admin Mode
  final _adminIdCtrl = TextEditingController();
  bool _isAdminMode = false;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final isAvailable = await _biometricService.isBiometricsAvailable();
    final isEnabled = await SessionManager.isBiometricEnabled();
    setState(() {
      _canCheckBiometrics = isAvailable;
      _biometricEnabled = isEnabled;
    });
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    String loginId = '';
    if (_isAdminMode) {
      loginId = _adminIdCtrl.text.trim();
    } else {
      // Format: F-XXX-SXX-XXX
      final f = _midFamilyCtrl.text.trim().toUpperCase();
      final s = _midSubFamilyCtrl.text.trim().toUpperCase();
      final r = _midRandomCtrl.text.trim();
      if (f.isEmpty || s.isEmpty || r.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Complete MID required (F-XXX-SXX-XXX)';
        });
        return;
      }
      loginId = 'F-$f-S$s-$r';
    }

    final res = await _auth.login(
      loginId: loginId,
      password: _passwordCtrl.text,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (!res.success) {
        setState(() => _error = res.message);
        return;
      }

      if (res.success) {
        // Save credentials for biometrics if successful
        await SessionManager.saveCredentials(loginId, _passwordCtrl.text);

        // Navigate based on role/admin status
        if (res.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Please authenticate to login',
    );

    if (authenticated) {
      final creds = await SessionManager.getSavedCredentials();
      if (creds != null) {
        setState(() => _loading = true);
        final res = await _auth.login(
          loginId: creds['loginId']!,
          password: creds['password']!,
        );

        if (mounted) {
          setState(() => _loading = false);
          if (res.success) {
            if (res.isAdmin) {
              Navigator.pushReplacementNamed(context, '/admin');
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          } else {
            setState(() => _error = res.message);
          }
        }
      } else {
        setState(
          () => _error =
              'No saved credentials found. Please login once with password.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Language Switcher Bar (prevents any floating stack overlap)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final newLang = lang.currentLanguage == 'en' ? 'gu' : 'en';
                      lang.setLanguage(newLang);
                    },
                    icon: const Icon(Icons.language, size: 16),
                    label: Text(
                      lang.currentLanguage == 'en' ? 'ગુજરાતી' : 'ENG',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo or Icon with animation
                      ScaleAnimation(
                        delay: const Duration(milliseconds: 100),
                        beginScale: 0.5,
                        child: Image.asset(
                          'assets/ganesh.png',
                          height: 115,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            Text(
                              _isAdminMode
                                  ? 'Developer & Admin Console'
                                  : lang.translate('welcome_back'),
                              style: TextStyle(
                                fontSize: _isAdminMode ? 21 : 26,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                            if (_isAdminMode) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Internal Operations & Diagnostics Portal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (!_isAdminMode) ...[
                        // MID INPUT (F-XXX-SXX-XXX) with animation
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 400),
                          beginOffset: const Offset(0, 0.2),
                          child: Column(
                            children: [
                              Text(
                                lang.translate('username'),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildFixedLabel('F-'),
                                    _buildMidInput(_midFamilyCtrl, 3, 'XXX'),
                                    _buildFixedLabel('-S'),
                                    _buildMidInput(_midSubFamilyCtrl, 2, 'XX'),
                                    _buildFixedLabel('-'),
                                    _buildMidInput(_midRandomCtrl, 3, 'XXX'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // ADMIN ID INPUT (ADM-83288) with animation
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 400),
                          beginOffset: const Offset(0, 0.2),
                          child: TextField(
                            controller: _adminIdCtrl,
                            decoration: InputDecoration(
                              labelText: 'Console ID',
                              hintText: 'ADM-83288',
                              prefixIcon: const Icon(Icons.shield_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // PASSWORD INPUT with animation
                      SlideInAnimation(
                        delay: const Duration(milliseconds: 500),
                        beginOffset: const Offset(0, 0.2),
                        child: TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: lang.translate('password'),
                            prefixIcon: const Icon(Icons.key_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 24),

                      if (_loading)
                        const CircularProgressIndicator()
                      else ...[
                        ScaleAnimation(
                          delay: const Duration(milliseconds: 600),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 3,
                              ),
                              onPressed: _login,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isAdminMode
                                      ? 'ACCESS DEVELOPER / ADMIN CONSOLE'
                                      : lang.translate('login'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_canCheckBiometrics && _biometricEnabled && !_isAdminMode) ...[
                          const SizedBox(height: 14),
                          PulseAnimation(
                            child: IconButton(
                              onPressed: _authenticateWithBiometrics,
                              icon: const Icon(Icons.fingerprint, size: 42),
                              color: Theme.of(context).colorScheme.primary,
                              tooltip: lang.translate('biometric_login'),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 22),

                      // Rearranged Developer / Member Mode Toggle Button
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 700),
                        child: _isAdminMode
                            ? TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isAdminMode = false;
                                    _error = null;
                                  });
                                },
                                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                label: const Text('Back to Member Login'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isAdminMode = true;
                                      _error = null;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.terminal_rounded,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Developer / Admin Portal',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMidInput(TextEditingController ctrl, int length, String hint) {
    return Container(
      width: length == 2 ? 45 : 60,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: TextField(
        controller: ctrl,
        maxLength: length,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        onChanged: (v) {
          if (v.length == length) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }
}
