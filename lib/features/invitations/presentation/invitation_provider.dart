import '../../../firebase_runtime.dart';

import 'package:http/http.dart' as http;

import '../data/invitation_email_service.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/invitation_repository.dart';
import '../domain/partner_invitation.dart';

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => FirestoreInvitationRepository(activeFunctions),
);
final invitationProvider = StreamProvider.autoDispose
    .family<PartnerInvitation?, String>(
      (ref, token) => ref.watch(invitationRepositoryProvider).watch(token),
    );
final pendingInvitationProvider = NotifierProvider<PendingInvitation, String?>(
  PendingInvitation.new,
);

class PendingInvitation extends Notifier<String?> {
  bool changed = false;
  @override
  String? build() => null;
  // Only the invitation capability is persisted, never passwords or auth tokens.
  Future<void> restore() async {
    try {
      final value = (await SharedPreferences.getInstance()).getString(
        'pending_partner_invitation',
      );
      if (ref.mounted &&
          !changed &&
          state == null &&
          value != null &&
          invitationTokenPattern.hasMatch(value)) {
        state = value;
      }
    } catch (_) {}
  }

  void open(String token) {
    if (!invitationTokenPattern.hasMatch(token)) {
      return;
    }
    changed = true;
    state = token;
    unawaited(_save(token));
  }

  void clearIf(String token) {
    if (ref.mounted && state == token) {
      clear();
    }
  }

  void clear() {
    changed = true;
    state = null;
    unawaited(_save(null));
  }

  Future<void> _save(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove('pending_partner_invitation');
      } else {
        await prefs.setString('pending_partner_invitation', token);
      }
    } catch (_) {}
  }
}

final invitationEmailServiceProvider = Provider<InvitationEmailService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return EmailJsInvitationEmailService(client);
});
