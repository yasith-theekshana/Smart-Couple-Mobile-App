import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_couple/features/invitations/data/invitation_email_service.dart';
import 'package:smart_couple/features/invitations/domain/partner_invitation.dart';

PartnerInvitation makeInvite(
  DateTime now, {
  String status = 'pending',
  Duration lifetime = const Duration(hours: 1),
}) => PartnerInvitation(
  token: 'A' * 43,
  coupleId: 'space',
  createdBy: 'owner',
  spaceName: 'Our world',
  status: status,
  expiresAt: now.add(lifetime),
);
const config = EmailJsConfig(
  serviceId: 'service_axodek6',
  templateId: 'template_a1r850t',
  publicKey: 'public-key',
);
void main() {
  final now = DateTime.utc(2026, 11, 16);
  test(
    'EmailJS request uses the confirmed template and recipient/link variables',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.emailjs.com/api/v1.0/email/send',
        );
        expect(request.headers['content-type'], 'application/json');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['service_id'], 'service_axodek6');
        expect(body['template_id'], 'template_a1r850t');
        expect(body['user_id'], 'public-key');
        expect(body.containsKey('accessToken'), isFalse);
        expect(body['template_params']['to_email'], 'partner@example.com');
        expect(
          body['template_params']['invitation_link'],
          makeInvite(now).link,
        );
        expect(body['template_params']['from_name'], 'Alice');
        expect(body['template_params']['couple_name'], 'Our world');
        return http.Response('OK', 200);
      });
      addTearDown(client.close);
      await EmailJsInvitationEmailService(
        client,
        config: config,
        now: () => now,
      ).send(
        recipientEmail: ' partner@example.com ',
        senderName: 'Alice',
        invitation: makeInvite(now),
      );
    },
  );
  test(
    'Invalid email, expired links, and revoked links never reach EmailJS',
    () async {
      int requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('OK', 200);
      });
      addTearDown(client.close);
      final service = EmailJsInvitationEmailService(
        client,
        config: config,
        now: () => now,
      );
      await expectLater(
        service.send(
          recipientEmail: 'bad@',
          senderName: 'Alice',
          invitation: makeInvite(now),
        ),
        throwsA(isA<InvitationEmailFailure>()),
      );
      await expectLater(
        service.send(
          recipientEmail: 'p@example.com',
          senderName: 'Alice',
          invitation: makeInvite(now, lifetime: const Duration(seconds: -1)),
        ),
        throwsA(isA<InvitationEmailFailure>()),
      );
      await expectLater(
        service.send(
          recipientEmail: 'p@example.com',
          senderName: 'Alice',
          invitation: makeInvite(now, status: 'revoked'),
        ),
        throwsA(isA<InvitationEmailFailure>()),
      );
      expect(requests, 0);
    },
  );
  test('Repeated sends are throttled without duplicate requests', () async {
    int requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('OK', 200);
    });
    addTearDown(client.close);
    final service = EmailJsInvitationEmailService(
      client,
      config: config,
      now: () => now,
    );
    await service.send(
      recipientEmail: 'p@example.com',
      senderName: 'Alice',
      invitation: makeInvite(now),
    );
    await expectLater(
      service.send(
        recipientEmail: 'p@example.com',
        senderName: 'Alice',
        invitation: makeInvite(now),
      ),
      throwsA(
        predicate((e) => e is InvitationEmailFailure && e.code == 'rate-limit'),
      ),
    );
    expect(requests, 1);
  });
  test(
    'Provider errors and uncertain transport failures are actionable',
    () async {
      for (final entry in {
        429: 'rate-limit',
        403: 'configuration',
        422: 'recipient',
        500: 'delivery',
      }.entries) {
        final client = MockClient(
          (_) async => http.Response('Private provider diagnostic', entry.key),
        );
        try {
          await expectLater(
            EmailJsInvitationEmailService(
              client,
              config: config,
              now: () => now,
            ).send(
              recipientEmail: 'p@example.com',
              senderName: 'Alice',
              invitation: makeInvite(now),
            ),
            throwsA(
              predicate(
                (e) => e is InvitationEmailFailure && e.code == entry.value,
              ),
            ),
          );
        } finally {
          client.close();
        }
      }
      final client = MockClient((_) async => throw TimeoutException('timeout'));
      addTearDown(client.close);
      await expectLater(
        EmailJsInvitationEmailService(
          client,
          config: config,
          now: () => now,
        ).send(
          recipientEmail: 'p@example.com',
          senderName: 'Alice',
          invitation: makeInvite(now),
        ),
        throwsA(
          predicate(
            (e) => e is InvitationEmailFailure && e.code == 'unconfirmed',
          ),
        ),
      );
      expect(
        invitationEmailError(const InvitationEmailFailure('configuration')),
        isNot(contains('Private provider diagnostic')),
      );
    },
  );
  test('Strict-mode rejection has a specific safe fix', () async {
    final client = MockClient(
      (_) async => http.Response(
        'API access in strict mode, but no Private Key was provided',
        403,
      ),
    );
    addTearDown(client.close);
    try {
      await EmailJsInvitationEmailService(
        client,
        config: config,
        now: () => now,
      ).send(
        recipientEmail: 'p@example.com',
        senderName: 'Alice',
        invitation: makeInvite(now),
      );
      fail('The strict-mode response must fail');
    } on InvitationEmailFailure catch (error) {
      expect(error.code, 'private-key-required');
      expect(error.statusCode, 403);
      expect(invitationEmailError(error), contains('Use Private Key'));
      expect(
        invitationEmailError(error),
        isNot(
          contains(
            'API access in strict mode, but no Private Key was provided',
          ),
        ),
      );
    }
  });
  test('Common EmailJS configuration errors have distinct classifications', () {
    for (final entry in <String, String>{
      'API calls are disabled for non-browser applications':
          'non-browser-disabled',
      'No records found. Please verify your Public Key, Service ID, and Template ID':
          'identifiers',
      'The public key is invalid': 'public-key',
      'The service ID is invalid': 'service-id',
      'The template ID not found': 'template-id',
      'Access from this origin is forbidden': 'origin-blocked',
      'The recipients address is empty': 'template-recipient',
      'Gmail_API: Request had insufficient authentication scopes':
          'mail-service',
    }.entries) {
      expect(classifyEmailJsFailure(400, entry.key).code, entry.value);
    }
  });
}
