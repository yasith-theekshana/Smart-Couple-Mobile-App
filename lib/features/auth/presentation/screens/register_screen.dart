import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_user.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final VoidCallback onLogin;
  const RegisterScreen({super.key, required this.onLogin});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    final success = await ref
        .read(authControllerProvider.notifier)
        .register(name.text, email.text, password.text);
    if (success) {
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authControllerProvider);
    return AuthShell(
      title: 'Join the sanctuary.',
      subtitle: 'Begin your journey towards a smarter partnership.',
      children: [
        if (action.error != null)
          AuthErrorBanner(authErrorMessage(action.error!)),
        AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: name,
                  enabled: !action.busy,
                  autofillHints: const [AutofillHints.name],
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: validateName,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: email,
                  enabled: !action.busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 18),
                PasswordInput(
                  controller: password,
                  label: 'Password',
                  enabled: !action.busy,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validatePassword,
                ),
                const SizedBox(height: 8),
                const Text(
                  '8–128 characters, including a letter and a number.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                PasswordInput(
                  controller: confirm,
                  label: 'Confirm password',
                  enabled: !action.busy,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Confirm your password.'
                      : v != password.text
                      ? 'Passwords do not match.'
                      : null,
                  onSubmitted: action.busy ? null : submit,
                ),
                const SizedBox(height: 24),
                AuthSubmit(
                  label: 'CREATE ACCOUNT',
                  busy: action.busy,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: action.busy ? null : widget.onLogin,
          child: const Text('Already have an account? Sign in'),
        ),
      ],
    );
  }
}
