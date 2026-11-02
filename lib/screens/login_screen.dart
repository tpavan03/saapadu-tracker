import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_sync_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key,
      required this.cloud,
      this.onContinueLocally,
      this.emailOtpEnabled = const bool.fromEnvironment('EMAIL_OTP_ENABLED'),
      this.resendCooldown = const Duration(seconds: 60)});
  final CloudSyncService cloud;
  final VoidCallback? onContinueLocally;
  final Duration resendCooldown;
  final bool emailOtpEnabled;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool working = false;
  String? error;
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _codeSent = false;
  DateTime? _resendAt;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  int get _resendSeconds => _resendAt == null
      ? 0
      : _resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 60);

  String _authError(Object failure) {
    if (failure is AuthException && failure.statusCode == '429') {
      return 'Too many requests. Wait a little before requesting another code.';
    }
    if (failure is FormatException) return failure.message;
    if (failure is StateError) return failure.message;
    return _codeSent
        ? 'That code could not be verified. Use the latest email code, or request a new one.'
        : 'A code could not be requested. Check your email address and connection, then try again.';
  }

  Future<void> _requestCode() async {
    if (working || _resendSeconds > 0) return;
    if (!_codeSent && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await widget.cloud.requestEmailCode(_emailController.text);
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _codeSent = true;
        _resendAt = DateTime.now().add(widget.resendCooldown);
      });
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _resendSeconds == 0) timer.cancel();
        if (mounted) setState(() {});
      });
    } catch (failure) {
      if (mounted) setState(() => error = _authError(failure));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _verifyCode() async {
    if (working || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await widget.cloud
          .verifyEmailCode(_emailController.text, _codeController.text);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (failure) {
      if (mounted) setState(() => error = _authError(failure));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget _nativeGoogleScreen(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                        color: AppColors.hero,
                        borderRadius: BorderRadius.circular(30)),
                    child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.ramen_dining_rounded,
                              size: 44, color: AppColors.lime),
                          SizedBox(height: 26),
                          Text('saapadu.',
                              style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          SizedBox(height: 12),
                          Text('Your diary.\nKept with you.',
                              style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 27,
                                  height: 1.2,
                                  color: Colors.white)),
                        ]),
                  ),
                  const SizedBox(height: 30),
                  Text('Connect once. Settle in.',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text(
                      'Use the Google account that holds your Saapadu history. Google opens its secure sign-in screen once, then returns you to this app.',
                      style: TextStyle(color: AppColors.muted, height: 1.65)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: working ? null : _signIn,
                    icon: Icon(working
                        ? Icons.hourglass_top_rounded
                        : Icons.login_rounded),
                    label: Text(
                        working ? 'Opening Google…' : 'Continue with Google'),
                  ),
                  if (error != null || widget.cloud.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(error ?? widget.cloud.lastError!,
                              style: const TextStyle(
                                  color: AppColors.terracotta))),
                    ),
                  if (widget.onContinueLocally != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: working ? null : widget.onContinueLocally,
                        child: const Text('Continue on this device')),
                  ],
                  const SizedBox(height: 24),
                  const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 18, color: AppColors.leaf),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                'Your session is kept securely on this device. Future opens stay in Saapadu, and your saved diary works offline.',
                                style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    height: 1.6))),
                      ]),
                ]),
          ),
        ))),
      );

  Widget _nativeScreen(BuildContext context) => !widget.emailOtpEnabled
      ? _nativeGoogleScreen(context)
      : Scaffold(
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                  child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                                color: AppColors.hero,
                                borderRadius: BorderRadius.circular(30)),
                            child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.ramen_dining_rounded,
                                      size: 42, color: AppColors.lime),
                                  SizedBox(height: 22),
                                  Text('saapadu.',
                                      style: TextStyle(
                                          fontFamily: 'Sora',
                                          fontSize: 31,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                  SizedBox(height: 10),
                                  Text('Your diary.\nKept with you.',
                                      style: TextStyle(
                                          fontFamily: 'Sora',
                                          fontSize: 26,
                                          height: 1.2,
                                          color: Colors.white)),
                                ]),
                          ),
                          const SizedBox(height: 28),
                          Text(
                              _codeSent
                                  ? 'Check your email'
                                  : 'Keep your history together',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 10),
                          Text(
                              _codeSent
                                  ? 'Enter the latest code sent to ${_emailController.text.trim()}. You stay in Saapadu to finish signing in.'
                                  : 'Use the same email as your existing Saapadu account. We’ll send a one-time code; no browser sign-in is needed.',
                              style: const TextStyle(
                                  color: AppColors.muted, height: 1.6)),
                          const SizedBox(height: 22),
                          TextFormField(
                            key: const ValueKey('native-sign-in-email'),
                            controller: _emailController,
                            readOnly: _codeSent,
                            enabled: !working,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                                labelText: 'Email address',
                                prefixIcon:
                                    Icon(Icons.alternate_email_rounded)),
                            validator: (value) =>
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch((value ?? '').trim())
                                    ? null
                                    : 'Enter a valid email address.',
                          ),
                          if (_codeSent) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('native-sign-in-code'),
                              controller: _codeController,
                              enabled: !working,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8)
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Email code',
                                  prefixIcon: Icon(Icons.password_rounded)),
                              validator: (value) =>
                                  RegExp(r'^\d{6,8}$').hasMatch(value ?? '')
                                      ? null
                                      : 'Enter the code from your email.',
                              onFieldSubmitted: (_) => _verifyCode(),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: working
                                ? null
                                : _codeSent
                                    ? _verifyCode
                                    : _requestCode,
                            icon: Icon(working
                                ? Icons.hourglass_top_rounded
                                : _codeSent
                                    ? Icons.lock_open_rounded
                                    : Icons.mail_outline_rounded),
                            label: Text(working
                                ? 'Please wait…'
                                : _codeSent
                                    ? 'Verify & sign in'
                                    : 'Email me a code'),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Text(error!,
                                      style: const TextStyle(
                                          color: AppColors.terracotta))),
                            ),
                          if (_codeSent)
                            Row(children: [
                              Expanded(
                                  child: TextButton(
                                onPressed: working
                                    ? null
                                    : () => setState(() {
                                          _codeSent = false;
                                          error = null;
                                          _codeController.clear();
                                          _resendAt = null;
                                        }),
                                child: const Text('Change email'),
                              )),
                              Expanded(
                                  child: TextButton(
                                onPressed: working || _resendSeconds > 0
                                    ? null
                                    : _requestCode,
                                child: Text(_resendSeconds > 0
                                    ? 'Resend in ${_resendSeconds}s'
                                    : 'Resend code'),
                              )),
                            ]),
                          if (widget.onContinueLocally != null) ...[
                            const SizedBox(height: 10),
                            TextButton(
                                onPressed:
                                    working ? null : widget.onContinueLocally,
                                child: const Text('Continue on this device')),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                              'Sign in once. Your session is kept securely on this device and refreshes automatically. Your diary remains available offline.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.6)),
                        ],
                      ))),
            ),
          ))),
        );

  Future<void> _signIn() async {
    if (working) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await widget.cloud.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        setState(() {
          working = false;
          error =
              'Google sign-in could not open. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => !kIsWeb
      ? _nativeScreen(context)
      : Scaffold(body: SafeArea(child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 860;
          final story = Container(
              padding: EdgeInsets.all(wide ? 48 : 28),
              decoration: BoxDecoration(
                  color: AppColors.hero,
                  borderRadius: BorderRadius.circular(32)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Row(children: [
                      Icon(Icons.spa_rounded, color: AppColors.lime, size: 30),
                      SizedBox(width: 10),
                      Text('saapadu.',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Sora',
                              fontSize: 27,
                              fontWeight: FontWeight.w700))
                    ]),
                    const SizedBox(height: 42),
                    const Text('Your plate.\nYour pace.',
                        style: TextStyle(
                            fontFamily: 'Sora',
                            color: Colors.white,
                            fontSize: 47,
                            height: 1.14,
                            letterSpacing: -2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    Text(
                        'Familiar food. Thoughtful routines.\nA little more balance, every day.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .75),
                            fontSize: 16,
                            height: 1.6)),
                    const SizedBox(height: 30),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final feature in [
                        (Icons.ramen_dining_rounded, 'South Indian food diary'),
                        (Icons.water_drop_outlined, 'Daily wellness'),
                        (Icons.timelapse_rounded, 'Fasting windows'),
                        (Icons.show_chart_rounded, 'Your progress')
                      ])
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(12)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(feature.$1, size: 17, color: AppColors.lime),
                              const SizedBox(width: 8),
                              Text(feature.$2,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12))
                            ]))
                    ]),
                    const SizedBox(height: 36),
                    Text('BUILT AROUND THE WAY YOU EAT.',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 2,
                            color: Colors.white.withValues(alpha: .65),
                            fontWeight: FontWeight.w700)),
                  ]));
          final entry = Padding(
              padding: EdgeInsets.all(wide ? 48 : 12),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('YOUR PRIVATE WELLNESS SPACE',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forest)),
                    const SizedBox(height: 16),
                    Text('A fresh page.\nA familiar routine.',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 18),
                    const Text(
                        'Log the meals you love, understand your nutrition and bring your daily rhythms together. Sign in to keep your history across devices.',
                        style: TextStyle(color: AppColors.muted, height: 1.7)),
                    const SizedBox(height: 30),
                    FilledButton.icon(
                        onPressed: working ? null : _signIn,
                        icon: Icon(working
                            ? Icons.hourglass_top_rounded
                            : Icons.login_rounded),
                        label: Text(working
                            ? 'Opening Google…'
                            : 'Continue with Google')),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Semantics(
                              liveRegion: true,
                              child: Text(error!,
                                  style: const TextStyle(
                                      color: AppColors.terracotta)))),
                    const SizedBox(height: 20),
                    const Row(children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 16, color: AppColors.muted),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Your account. Your diary. No ads or analytics.',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)))
                    ]),
                    const SizedBox(height: 40),
                    const Text(
                        'Calories and activity figures are estimates. Your personal records belong to your account.',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 11, height: 1.6)),
                  ]));
          return Center(
              child: SingleChildScrollView(
                  padding: EdgeInsets.all(wide ? 34 : 18),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                  Expanded(child: story),
                                  Expanded(child: entry)
                                ])
                          : Column(children: [
                              story,
                              const SizedBox(height: 24),
                              entry
                            ]))));
        })));
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key, required this.cloud});
  final CloudSyncService cloud;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_accounts_outlined,
                      size: 54, color: AppColors.terracotta),
                  const SizedBox(height: 16),
                  Text('This account is not approved.',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign out and use the Google account configured for this tracker.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: cloud.signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
