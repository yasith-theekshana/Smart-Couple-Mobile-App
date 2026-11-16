import '../../../invitations/presentation/invitation_screens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui.dart';
import '../providers/couple_provider.dart';

class CoupleSpaceHeader extends ConsumerWidget {
  final String coupleId;
  const CoupleSpaceHeader({super.key, required this.coupleId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(coupleSpaceProvider(coupleId))
      .when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to load your couple space.'),
                Text(
                  authErrorMessage(error),
                  style: const TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(coupleSpaceProvider(coupleId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (space) => Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Panel(
            color: cream,
            child: Row(
              children: [
                iconBox(Icons.favorite_outline, gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        space?.name ?? 'Couple space unavailable',
                        style: serif(19),
                      ),
                      if (space != null &&
                          space.memberIds.length == 1 &&
                          ref.watch(authStateProvider).asData?.value?.uid ==
                              space.createdBy)
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => InvitePartnerScreen(
                                uid: space.createdBy,
                                senderName:
                                    ref
                                        .read(
                                          userProfileProvider(space.createdBy),
                                        )
                                        .asData
                                        ?.value
                                        ?.name ??
                                    'Your partner',
                                coupleId: coupleId,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Invite partner'),
                        ),
                      const SizedBox(height: 4),
                      if (space != null && space.memberIds.length == 2)
                        Text(
                          space.memberIds
                              .where(
                                (uid) =>
                                    uid !=
                                    ref
                                        .watch(authStateProvider)
                                        .asData
                                        ?.value
                                        ?.uid,
                              )
                              .map(
                                (uid) =>
                                    'Connected with ${space.memberNames[uid] ?? 'your partner'}',
                              )
                              .join(', '),
                          style: const TextStyle(color: royal, fontSize: 12),
                        ),
                      Text(
                        space == null
                            ? 'Please contact support.'
                            : space.memberIds.length == 1
                            ? 'Your space is ready. Invite your partner to join.'
                            : '${space.memberIds.length} members · Your shared space',
                        style: const TextStyle(
                          color: royal,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
