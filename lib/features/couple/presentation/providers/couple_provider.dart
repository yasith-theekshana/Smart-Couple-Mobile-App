import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/couple_repository.dart';
import '../../domain/couple_space.dart';

final coupleRepositoryProvider = Provider<CoupleRepository>(
  (ref) => FirestoreCoupleRepository(FirebaseFirestore.instance),
);
final coupleSpaceProvider = StreamProvider.autoDispose
    .family<CoupleSpace?, String>(
      (ref, id) => ref.watch(coupleRepositoryProvider).watchCoupleSpace(id),
    );
