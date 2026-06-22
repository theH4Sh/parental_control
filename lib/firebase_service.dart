import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppFirebaseService {
  // Private constructor for singleton
  AppFirebaseService._privateConstructor();
  static final AppFirebaseService instance = AppFirebaseService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// Performs anonymous authentication and stores the user.
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      _currentUser = credential.user;
      return _currentUser;
    } catch (e) {
      debugPrint('Firebase Auth Error: $e');
      rethrow;
    }
  }

  /// Syncs usage data to Firestore under usage_stats/{userId}/daily_stats/{yyyy-MM-dd}
  Future<void> syncUsageStats({
    required String userId,
    required List<Map<String, dynamic>> usageData,
  }) async {
    try {
      final dateStr = DateTime.now().toIso8601String().substring(0, 10); // Format: yyyy-MM-dd
      final docRef = _firestore
          .collection('usage_stats')
          .doc(userId)
          .collection('daily_stats')
          .doc(dateStr);

      final totalScreenTimeMs = usageData.fold<int>(
        0,
        (acc, item) => acc + (item['totalMs'] as int? ?? 0),
      );

      await docRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'deviceInfo': 'Android Device (${Platform.operatingSystemVersion})',
        'totalScreenTimeMs': totalScreenTimeMs,
        'apps': usageData,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      rethrow;
    }
  }
}
