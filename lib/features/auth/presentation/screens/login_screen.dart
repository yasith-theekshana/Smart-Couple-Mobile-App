import '../../../invitations/presentation/invitation_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_user.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onRegister, onForgotPassword;
  const LoginScreen({
    super.key,
    required this.onRegister,
    required this.onForgotPassword,
  });
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(email.text, password.text);
    if (success) {
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authControllerProvider);
    return AuthShell(
      title: 'Welcome back.',
      subtitle: 'Sign in to manage your shared life.',
      children: [
        if (ref.watch(pendingInvitationProvider) != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Your partner invitation is saved. Sign in or register to review it.',
            ),
          ),
        if (action.error != null)
          AuthErrorBanner(authErrorMessage(action.error!)),
        AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: email,
                  enabled: !action.busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 20),
                PasswordInput(
                  controller: password,
                  label: 'Password',
                  enabled: !action.busy,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your password.' : null,
                  onSubmitted: action.busy ? null : submit,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: action.busy ? null : widget.onForgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 10),
                AuthSubmit(
                  label: 'SIGN IN',
                  busy: action.busy,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        TextButton(
          onPressed: action.busy ? null : widget.onRegister,
          child: const Text('No account yet? Create an account'),
        ),
      ],
    );
  }
}
