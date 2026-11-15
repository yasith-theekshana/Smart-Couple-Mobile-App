import '../../../invitations/presentation/invitation_provider.dart';
import '../../../invitations/presentation/invitation_screens.dart';
import '../../../couple/presentation/screens/couple_setup_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_user.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class AuthGate extends ConsumerWidget {
  final Widget Function(AppUser user) dashboardBuilder;
  const AuthGate({super.key, required this.dashboardBuilder});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider);
    return session.when(
      loading: () => const AuthLoading(),
      error: (e, _) => AuthProblem(
        title: 'Unable to check your session',
        error: e,
        onRetry: () => ref.invalidate(authStateProvider),
      ),
      data: (user) {
        if (user == null) {
          return const AuthScreens();
        }
        final action = ref.watch(authControllerProvider);
        if (action.busy) {
          return const AuthLoading();
        }
        return ref
            .watch(userProfileProvider(user.uid))
            .when(
              loading: () => const AuthLoading(),
              error: (e, _) => AuthProblem(
                title: 'Unable to load your profile',
                error: e,
                onRetry: () => ref.invalidate(userProfileProvider(user.uid)),
                allowSignOut: true,
              ),
              data: (profile) {
                if (profile == null) {
                  return RecoverProfileScreen(session: user);
                }
                // A session-keyed navigator removes every previous user's route and
                // dashboard state, including pushed articles, when identity changes.
                final token = ref.watch(pendingInvitationProvider);
                return Navigator(
                  key: ValueKey('${user.uid}:${profile.coupleId}:$token'),
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => token != null
                        ? AcceptInvitationScreen(user: profile, token: token)
                        : profile.coupleId == null
                        ? CoupleSetupScreen(user: profile)
                        : dashboardBuilder(profile),
                  ),
                );
              },
            );
      },
    );
  }
}

class AuthLoading extends StatelessWidget {
  const AuthLoading({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: CircularProgressIndicator(semanticsLabel: 'Loading your account'),
    ),
  );
}

class AuthScreens extends StatefulWidget {
  const AuthScreens({super.key});
  @override
  State<AuthScreens> createState() => _AuthScreensState();
}

class _AuthScreensState extends State<AuthScreens> {
  int page = 0;
  void change(int value) {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(authControllerProvider.notifier).clearError();
    setState(() => page = value);
  }

  @override
  Widget build(BuildContext context) => switch (page) {
    1 => RegisterScreen(onLogin: () => change(0)),
    2 => ForgotPasswordScreen(onLogin: () => change(0)),
    _ => LoginScreen(
      onRegister: () => change(1),
      onForgotPassword: () => change(2),
    ),
  };
}

class AuthProblem extends ConsumerWidget {
  final String title;
  final Object error;
  final VoidCallback onRetry;
  final bool allowSignOut;
  const AuthProblem({
    super.key,
    required this.title,
    required this.error,
    required this.onRetry,
    this.allowSignOut = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthShell(
    title: title,
    subtitle: 'Your account is safe. Please try again.',
    children: [
      AuthErrorBanner(authErrorMessage(error)),
      if (ref.watch(authControllerProvider).error case final e?)
        AuthErrorBanner(authErrorMessage(e)),
      FilledButton(onPressed: onRetry, child: const Text('Retry')),
      if (allowSignOut) const SignOutButton(),
    ],
  );
}

class RecoverProfileScreen extends ConsumerStatefulWidget {
  final AuthSession session;
  const RecoverProfileScreen({super.key, required this.session});
  @override
  ConsumerState<RecoverProfileScreen> createState() =>
      _RecoverProfileScreenState();
}

class _RecoverProfileScreenState extends ConsumerState<RecoverProfileScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.session.displayName);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authControllerProvider);
    return AuthShell(
      title: 'Complete your profile',
      subtitle: 'You are signed in, but your profile is missing. Save your name to safely finish setting up your account.',
      children: [
        if (action.error != null)
          AuthErrorBanner(authErrorMessage(action.error!)),
        Form(
          key: form,
          child: TextFormField(
            controller: name,
            enabled: !action.busy,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: validateName,
          ),
        ),
        const SizedBox(height: 24),
        AuthSubmit(
          label: 'SAVE PROFILE',
          busy: action.busy,
          onPressed: () {
            if (form.currentState!.validate()) {
              ref
                  .read(authControllerProvider.notifier)
                  .recoverProfile(widget.session, name.text);
            }
          },
        ),
        const SignOutButton(),
      ],
    );
  }
}
