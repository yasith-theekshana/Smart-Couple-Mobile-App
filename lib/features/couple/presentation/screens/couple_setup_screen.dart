import '../../../invitations/presentation/invitation_screens.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/auth_widgets.dart';
import '../../domain/couple_space.dart';
import '../providers/couple_provider.dart';

class CoupleSetupScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const CoupleSetupScreen({super.key, required this.user});
  @override
  ConsumerState<CoupleSetupScreen> createState() => _CoupleSetupScreenState();
}

class _CoupleSetupScreenState extends ConsumerState<CoupleSetupScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  bool creating = false, busy = false;
  Object? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (busy || !form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(coupleRepositoryProvider)
          .createCoupleSpace(widget.user.uid, name.text);
      // Membership is the routing source of truth; never push the dashboard
      // speculatively. The profile listener also handles updates on other devices.
      if (mounted) {
        ref.invalidate(userProfileProvider(widget.user.uid));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return PopScope(
      canPop: !busy,
      child: AuthShell(
        title: creating
            ? 'Your space, together.'
            : 'Welcome, ${widget.user.name}.',
        subtitle: creating
            ? 'Choose a name for the life you share. Then invite your partner with a private link.'
            : 'Your account is ready. Create a space to begin.',
        children: [
          if (error != null) AuthErrorBanner(coupleErrorMessage(error!)),
          if (auth.error != null)
            AuthErrorBanner(authErrorMessage(auth.error!)),
          const Icon(Icons.favorite_outline, size: 48),
          const SizedBox(height: 20),
          if (creating) ...[
            Form(
              key: form,
              child: TextFormField(
                key: const ValueKey('couple-name'),
                controller: name,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                validator: validateCoupleName,
                decoration: const InputDecoration(
                  labelText: 'Couple space name',
                  hintText: 'Our little world',
                ),
                onFieldSubmitted: (_) => create(),
              ),
            ),
            const SizedBox(height: 18),
            AuthSubmit(label: 'CREATE SPACE', busy: busy, onPressed: create),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      creating = false;
                      error = null;
                    }),
              child: const Text('Back'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: auth.busy
                  ? null
                  : () => setState(() => creating = true),
              icon: const Icon(Icons.add),
              label: const Text('Create Couple Space'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: auth.busy ? null : () => pasteInvitation(context, ref),
              icon: const Icon(Icons.link),
              label: const Text('Join Couple Space'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Create a space or open the invitation link your partner sent you.',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: busy || auth.busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

String coupleErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Your space could not be saved. Please retry or contact support if this continues.';
  }
  if (error is AuthFailure) {
    if (error.code == 'invalid-couple-name') {
      return 'Enter a space name (1–80 characters).';
    }
    if (error.code == 'missing-profile') {
      return 'Your profile is missing. Sign out and sign in to complete it first.';
    }
  }
  return authErrorMessage(error);
}
