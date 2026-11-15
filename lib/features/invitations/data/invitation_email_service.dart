import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/app_user.dart';
import '../domain/partner_invitation.dart';

class EmailJsConfig {
  // EmailJS service/template IDs and public key are public client configuration.
  // Never put an EmailJS private key or mailbox password in the app.
  final String serviceId, templateId, publicKey;
  const EmailJsConfig({
    this.serviceId = const String.fromEnvironment(
      'EMAILJS_SERVICE_ID',
      defaultValue: 'service_axodek6',
    ),
    this.templateId = const String.fromEnvironment(
      'EMAILJS_TEMPLATE_ID',
      defaultValue: 'template_a1r850t',
    ),
    this.publicKey = const String.fromEnvironment(
      'EMAILJS_PUBLIC_KEY',
      defaultValue: 'mMxHOlZqU8mF29mLZ',
    ),
  });
  bool get configured =>
      serviceId.trim().isNotEmpty &&
      templateId.trim().isNotEmpty &&
      publicKey.trim().isNotEmpty;
}

abstract class InvitationEmailService {
  Future<void> send({
    required String recipientEmail,
    required String senderName,
    required PartnerInvitation invitation,
  });
}

class InvitationEmailFailure implements Exception {
  final String code;
  final int? statusCode;
  const InvitationEmailFailure(this.code, {this.statusCode});
}

class EmailJsInvitationEmailService implements InvitationEmailService {
  final http.Client _client;
  final EmailJsConfig config;
  final DateTime Function() _now;
  DateTime? _lastAttempt;
  EmailJsInvitationEmailService(
    this._client, {
    this.config = const EmailJsConfig(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  @override
  Future<void> send({
    required String recipientEmail,
    required String senderName,
    required PartnerInvitation invitation,
  }) async {
    if (!config.configured) {
      throw const InvitationEmailFailure('not-configured');
    }
    if (validateEmail(recipientEmail) != null) {
      throw const InvitationEmailFailure('invalid-email');
    }
    if (invitation.status != 'pending' ||
        !invitation.expiresAt.isAfter(_now())) {
      throw const InvitationEmailFailure('unavailable-invite');
    }
    final now = _now();
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) < const Duration(seconds: 2)) {
      throw const InvitationEmailFailure('rate-limit');
    }
    _lastAttempt = now;
    try {
      final response = await _client
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': config.serviceId,
              'template_id': config.templateId,
              'user_id': config.publicKey,
              'template_params': {
                'to_email': recipientEmail.trim(),
                'invitation_link': invitation.link,
                'from_name': senderName.trim().isEmpty
                    ? 'Your partner'
                    : senderName.trim(),
                'couple_name': invitation.spaceName,
                'app_name': 'SmartCouple',
                'expires_in': '24 hours',
                'message':
                    'Join my couple space on SmartCouple: ${invitation.link}',
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return;
      }
      throw classifyEmailJsFailure(response.statusCode, response.body);
    } on TimeoutException {
      throw const InvitationEmailFailure('unconfirmed');
    } on http.ClientException {
      throw const InvitationEmailFailure('unconfirmed');
    }
  }
}

// Classify known provider responses without exposing arbitrary response bodies,
// recipient addresses, invitation capabilities, or credential values in the UI.
InvitationEmailFailure classifyEmailJsFailure(int status, String response) {
  final message = response.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ');
  String code;
  if (message.contains('strict mode') ||
      message.contains('private key') ||
      message.contains('accesstoken')) {
    code = 'private-key-required';
  } else if (message.contains('non browser') ||
      message.contains('api calls are disabled') ||
      message.contains('api requests are disabled')) {
    code = 'non-browser-disabled';
  } else if (message.contains('no records found')) {
    code = 'identifiers';
  } else if (message.contains('public key') || message.contains('user id')) {
    code = 'public-key';
  } else if (message.contains('service id') &&
      (message.contains('invalid') || message.contains('not found'))) {
    code = 'service-id';
  } else if (message.contains('template id') &&
      (message.contains('invalid') || message.contains('not found'))) {
    code = 'template-id';
  } else if (message.contains('origin') || message.contains('domain')) {
    code = 'origin-blocked';
  } else if (message.contains('captcha')) {
    code = 'captcha-required';
  } else if (message.contains('insufficient authentication scopes') ||
      message.contains('invalid grant') ||
      message.contains('gmail api') ||
      message.contains('smtp')) {
    code = 'mail-service';
  } else if (message.contains('recipient') && message.contains('empty')) {
    code = 'template-recipient';
  } else if (status == 429) {
    code = 'rate-limit';
  } else if (status == 422) {
    code = 'recipient';
  } else if ([400, 401, 403, 404].contains(status)) {
    code = 'configuration';
  } else {
    code = 'delivery';
  }
  return InvitationEmailFailure(code, statusCode: status);
}

String invitationEmailError(Object error) {
  final failure = error is InvitationEmailFailure ? error : null;
  return switch (failure?.code) {
    'invalid-email' || 'recipient' => 'Enter a valid partner email address.',
    'unavailable-invite' => 'This invitation is expired or no longer available. Create a new link first.',
    'private-key-required' => 'EmailJS strict mode requires a private key. For the selected public-key setup, turn off Use Private Key in EmailJS Account → Security and save. Never paste a private key into this app.',
    'non-browser-disabled' => 'EmailJS is blocking mobile requests. Enable API requests for non-browser applications in EmailJS Account → Security.',
    'identifiers' => 'EmailJS could not find the account configuration. Verify the public key, service ID, and template ID belong to the same EmailJS account.',
    'public-key' => 'EmailJS rejected the public key. Check the public key in the EmailJS account settings.',
    'service-id' => 'EmailJS could not find the email service. Check the service ID in EmailJS.',
    'template-id' => 'EmailJS could not find the invitation template. Check the template ID in EmailJS.',
    'origin-blocked' => 'EmailJS blocked this app’s origin. Add this website to the allowed origins in EmailJS Account → Security.',
    'captcha-required' => 'This EmailJS template requires CAPTCHA. Its CAPTCHA setup must be completed before email sending can work.',
    'mail-service' => 'The sending mailbox needs attention. Reconnect the email service in EmailJS and check its permissions.',
    'template-recipient' => 'The EmailJS template has no recipient. Set its To Email field to {{to_email}} and save.',
    'rate-limit' => 'Please wait a moment before sending again. If this continues, check your email sending limit.',
    'configuration' =>
      'EmailJS rejected the request${failure?.statusCode == null ? '' : ' (HTTP ${failure!.statusCode})'}. Check the email service configuration, or use Copy link.',
    'not-configured' => 'Email invitations are not configured. Please use Share link or Copy link.',
    'unconfirmed' => 'We could not confirm whether the email was sent. Check the inbox before retrying to avoid sending it twice.',
    _ => 'The email could not be sent. Please try again or use Copy link.',
  };
}
