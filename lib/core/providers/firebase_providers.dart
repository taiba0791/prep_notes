import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/firebase_config.dart';

part 'firebase_providers.g.dart';

// The raw Firebase services. ONLY repositories may read these
// (UI widgets never touch Firebase directly — see CLAUDE.md).
// Tests override them with in-memory fakes.

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
FirebaseStorage firebaseStorage(Ref ref) => FirebaseStorage.instance;

/// Cloud Functions in our region (asia-south1).
@Riverpod(keepAlive: true)
FirebaseFunctions functions(Ref ref) => FirebaseConfig.functions;
