import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_user.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final VoidCallback onLogin;
  const ForgotPasswordScreen({super.key, required this.onLogin});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  bool sent = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email.text);
    if (mounted && success) {
      setState(() => sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authControllerProvider);
    return AuthShell(
      title: 'A fresh start.',
      subtitle: 'Request a password reset link for your account.',
      children: [
        if (action.error != null)
          AuthErrorBanner(authErrorMessage(action.error!)),
        if (sent)
          Semantics(
            liveRegion: true,
            child: Text(
              'If an account exists for this email, a password reset link has been sent. Check your inbox and spam folder.',
            ),
          )
        else
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: email,
                  enabled: !action.busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 24),
                AuthSubmit(
                  label: 'SEND RESET LINK',
                  busy: action.busy,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: action.busy ? null : widget.onLogin,
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
