import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/partner_invitation.dart';
import 'invitation_provider.dart';

class InvitationLinkListener extends ConsumerStatefulWidget {
  final Widget child;
  const InvitationLinkListener({super.key, required this.child});
  @override
  ConsumerState<InvitationLinkListener> createState() =>
      _InvitationLinkListenerState();
}

class _InvitationLinkListenerState
    extends ConsumerState<InvitationLinkListener> {
  StreamSubscription<Uri>? subscription;
  void handle(Uri? uri) {
    if (!mounted || uri == null) {
      return;
    }
    final token = invitationTokenFrom(uri.toString());
    if (token != null) {
      ref.read(pendingInvitationProvider.notifier).open(token);
    }
  }

  @override
  void initState() {
    super.initState();
    final launchUri = Uri.base;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(pendingInvitationProvider.notifier).restore());
      if (kIsWeb) {
        handle(launchUri);
      } else {
        final links = AppLinks();
        unawaited(
          links.getInitialLink().then(handle).catchError((Object _) {}),
        );
        subscription = links.uriLinkStream.listen(
          handle,
          onError: (Object _) {},
        );
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
