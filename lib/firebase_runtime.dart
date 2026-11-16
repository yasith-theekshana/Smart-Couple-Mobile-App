import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Debug builds consistently use the local stack unless explicitly overridden.
const useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: kDebugMode,
);
const localFirebaseAppName = 'smart-couple-local';

// Android can initialize its default Firebase app from google-services.json
// before Dart starts. A separate named app keeps local project IDs and sessions
// isolated from that production default app.
FirebaseApp get activeFirebaseApp =>
    Firebase.app(useFirebaseEmulators ? localFirebaseAppName : '[DEFAULT]');
FirebaseAuth get activeFirebaseAuth =>
    FirebaseAuth.instanceFor(app: activeFirebaseApp);
FirebaseFirestore get activeFirestore =>
    FirebaseFirestore.instanceFor(app: activeFirebaseApp);
FirebaseFunctions get activeFunctions =>
    FirebaseFunctions.instanceFor(app: activeFirebaseApp);
