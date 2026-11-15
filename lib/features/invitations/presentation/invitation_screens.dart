import '../data/invitation_email_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/domain/app_user.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/screens/auth_widgets.dart';

import '../../couple/presentation/providers/couple_provider.dart';
import '../domain/partner_invitation.dart';
import 'invitation_provider.dart';

class InvitePartnerScreen extends ConsumerStatefulWidget {
  final String uid, coupleId;
  final String senderName;
  const InvitePartnerScreen({
    super.key,
    required this.uid,
    required this.coupleId,
    this.senderName = 'Your partner',
  });
  @override
  ConsumerState<InvitePartnerScreen> createState() =>
      _InvitePartnerScreenState();
}

class _InvitePartnerScreenState extends ConsumerState<InvitePartnerScreen> {
  final email = TextEditingController();
  final emailForm = GlobalKey<FormState>();
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  PartnerInvitation? invite;
  bool busy = false;
  String? error, notice;
  Future<void> generate() async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final value = await ref
          .read(invitationRepositoryProvider)
          .create(widget.uid, widget.coupleId);
      if (mounted) {
        setState(() => invite = value);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = invitationError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> sendEmail() async {
    final current = invite;
    if (busy || current == null || !emailForm.currentState!.validate()) {
      return;
    }
    final recipient = email.text.trim();
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      // Confirm the capability is still usable on the server before requesting
      // email delivery. Failure never deletes or regenerates the invitation.
      final latest = await ref
          .read(invitationRepositoryProvider)
          .getFromServer(current.token);
      if (latest == null ||
          latest.createdBy != widget.uid ||
          latest.status != 'pending' ||
          !latest.expiresAt.isAfter(DateTime.now())) {
        throw const InvitationEmailFailure('unavailable-invite');
      }
      await ref
          .read(invitationEmailServiceProvider)
          .send(
            recipientEmail: recipient,
            senderName: widget.senderName,
            invitation: latest,
          );
      if (mounted) {
        setState(
          () => notice =
              'Invitation email sent to $recipient. Ask your partner to check their inbox or spam folder.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is InvitationEmailFailure
              ? invitationEmailError(e)
              : invitationError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> share() async {
    if (invite == null || busy) {
      return;
    }
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: 'Join my couple space on SmartCouple:\n${invite!.link}',
          subject: 'Join me on SmartCouple',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Sharing is unavailable here. Use Copy link instead.',
        );
      }
    }
  }

  Future<void> revoke() async {
    if (invite == null || busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(invitationRepositoryProvider)
          .revoke(widget.uid, invite!.token);
      if (mounted) {
        setState(() {
          invite = null;
          notice = 'Invitation revoked. It can no longer be accepted.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = invitationError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AuthShell(
      title: 'Invite your partner.',
      subtitle: 'Send a private link. Your partner will sign in or register, then choose whether to join your space.',
      children: [
        if (error != null) AuthErrorBanner(error!),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(notice!),
          ),
        if (invite == null)
          AuthSubmit(
            label: 'CREATE INVITATION LINK',
            busy: busy,
            onPressed: generate,
          )
        else ...[
          Text(
            invite!.spaceName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          const Text(
            'Single-use link · expires within 24 hours. Anyone you send this link to can accept it, so share it only with your partner.',
          ),
          const SizedBox(height: 16),
          Form(
            key: emailForm,
            child: TextFormField(
              key: const ValueKey('partner-email'),
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Partner email address',
                hintText: 'partner@example.com',
              ),
              validator: validateEmail,
            ),
          ),
          const SizedBox(height: 12),
          AuthSubmit(
            label: 'SEND INVITATION EMAIL',
            busy: busy,
            onPressed: sendEmail,
          ),
          const SizedBox(height: 18),
          SelectableText(invite!.link, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : share,
            icon: const Icon(Icons.share_outlined),
            label: const Text('SHARE LINK'),
          ),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: invite!.link));
                    if (mounted) {
                      setState(
                        () => notice = 'Link copied. Send it to your partner.',
                      );
                    }
                  },
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
          ),
          TextButton(
            onPressed: busy ? null : revoke,
            child: const Text('Revoke this invitation'),
          ),
        ],
        const SizedBox(height: 14),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Back to your space'),
        ),
      ],
    ),
  );
}

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  final AppUser user;
  final String token;
  const AcceptInvitationScreen({
    super.key,
    required this.user,
    required this.token,
  });
  @override
  ConsumerState<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState
    extends ConsumerState<AcceptInvitationScreen> {
  bool busy = false;
  String? error;
  Future<void> accept() async {
    if (busy) {
      return;
    }
    final pending = ref.read(pendingInvitationProvider.notifier);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final coupleId = await ref
          .read(invitationRepositoryProvider)
          .accept(widget.user.uid, widget.token);
      // The profile stream can replace this screen before the transaction returns.
      // Clear only this capability, even if the old screen has been disposed.
      pending.clearIf(widget.token);
      if (mounted) {
        ref.invalidate(userProfileProvider(widget.user.uid));
        ref.invalidate(coupleSpaceProvider(coupleId));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = invitationError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = ref.watch(invitationProvider(widget.token));
    return PopScope(
      canPop: !busy,
      child: AuthShell(
        title: 'A space for two.',
        subtitle:
            'Signed in as ${widget.user.email}. Accept only if this is an invitation from your partner.',
        children: [
          if (error != null) AuthErrorBanner(error!),
          ...invitation.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (e, _) => [
              AuthErrorBanner(invitationError(e)),
              TextButton(
                onPressed: () =>
                    ref.invalidate(invitationProvider(widget.token)),
                child: const Text('Refresh invitation'),
              ),
            ],
            data: (value) {
              if (value == null) {
                return [
                  const AuthErrorBanner('This invitation could not be found.'),
                ];
              }
              final own = value.createdBy == widget.user.uid;
              final joined =
                  value.status == 'accepted' &&
                  value.acceptedBy == widget.user.uid &&
                  widget.user.coupleId == value.coupleId;
              final other =
                  widget.user.coupleId != null &&
                  widget.user.coupleId != value.coupleId;
              final expired = !value.expiresAt.isAfter(DateTime.now());
              return <Widget>[
                Text(
                  value.spaceName,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (joined)
                  const Text(
                    'You have joined this couple space. Continue to your dashboard.',
                  )
                else if (own)
                  const AuthErrorBanner(
                    'This is your invitation. Share it with your partner.',
                  )
                else if (other)
                  const AuthErrorBanner(
                    'This account already belongs to another couple space. Sign out and use the intended account.',
                  )
                else if (value.status != 'pending')
                  AuthErrorBanner(
                    invitationError(
                      const InvitationFailure('unavailable-invite'),
                    ),
                  )
                else if (expired)
                  AuthErrorBanner(
                    invitationError(const InvitationFailure('expired')),
                  )
                else
                  AuthSubmit(
                    label: 'ACCEPT INVITATION',
                    busy: busy,
                    onPressed: accept,
                  ),
              ];
            },
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: busy
                ? null
                : () => ref.read(pendingInvitationProvider.notifier).clear(),
            child: Text(
              widget.user.coupleId == null ? 'Not now' : 'Continue to my space',
            ),
          ),
          if (!busy) const SignOutButton(),
        ],
      ),
    );
  }
}

Future<void> pasteInvitation(BuildContext context, WidgetRef ref) async {
  final token = await showDialog<String>(
    context: context,
    builder: (_) => const InvitationInputDialog(),
  );
  if (token != null && context.mounted) {
    ref.read(pendingInvitationProvider.notifier).open(token);
  }
}

class InvitationInputDialog extends StatefulWidget {
  const InvitationInputDialog({super.key});
  @override
  State<InvitationInputDialog> createState() => _InvitationInputDialogState();
}

class _InvitationInputDialogState extends State<InvitationInputDialog> {
  final input = TextEditingController(), form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Join your partner'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: input,
        decoration: const InputDecoration(labelText: 'Invitation link'),
        validator: (value) => invitationTokenFrom(value ?? '') == null
            ? 'Paste a valid SmartCouple invitation link.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, invitationTokenFrom(input.text));
          }
        },
        child: const Text('Open invitation'),
      ),
    ],
  );
}
