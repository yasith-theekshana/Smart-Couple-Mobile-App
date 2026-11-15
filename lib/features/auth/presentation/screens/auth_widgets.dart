import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

import 'package:flutter/material.dart';

import '../../../../ui.dart';

class AuthShell extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: mist,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: gold.withValues(alpha: .15)),
                boxShadow: [
                  BoxShadow(
                    color: royal.withValues(alpha: .06),
                    blurRadius: 35,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'SMART',
                            style: TextStyle(color: gold),
                          ),
                          TextSpan(
                            text: 'COUPLE',
                            style: TextStyle(color: royal),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 44,
                      height: 44,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(title, style: serif(26), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: coral.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF8A2525),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ),
  );
}

class AuthSubmit extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  const AuthSubmit({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Please wait',
            ),
          )
        : Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
  );
}

class PasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final VoidCallback? onSubmitted;
  const PasswordInput({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.autofillHints,
    this.enabled = true,
    this.onSubmitted,
  });
  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: hidden,
    enableSuggestions: false,
    autocorrect: false,
    autofillHints: widget.autofillHints,
    validator: widget.validator,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: hidden ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
        ),
      ),
    ),
  );
}

class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return TextButton.icon(
      onPressed: state.busy
          ? null
          : () => ref.read(authControllerProvider.notifier).signOut(),
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('Sign out'),
    );
  }
}
