import '../../../../firebase_runtime.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/couple_repository.dart';
import '../../domain/couple_space.dart';

final coupleRepositoryProvider = Provider<CoupleRepository>(
  (ref) => FirestoreCoupleRepository(activeFirestore, activeFunctions),
);
final coupleSpaceProvider = StreamProvider.autoDispose
    .family<CoupleSpace?, String>(
      (ref, id) => ref.watch(coupleRepositoryProvider).watchCoupleSpace(id),
    );
