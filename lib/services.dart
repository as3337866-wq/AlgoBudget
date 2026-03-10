// services.dart - ALL SERVICES IN ONE FILE

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'main.dart';

// ==================== AUTH SERVICE ====================
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<UserCredential> signUp(
    String email,
    String password,
    String username,
  ) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'username': username,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return userCredential;
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<String> getCurrentUsername() async {
    final user = _auth.currentUser;
    if (user == null) return 'Unknown';

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc['username'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  bool isAdmin() {
    final adminEmails = [
      'mueezhajwani05@gmail.com',
      'ansarihuzaifa899@gmail.com',
      '23co56@aiktc.ac.in',
      '23co48@aiktc.ac.in',
      '23dco01@aiktc.ac.in',
      'abcd@gmail.com'
    ];
    return adminEmails.contains(_auth.currentUser?.email);
  }
}

// ==================== BUDGET SERVICE ====================
class BudgetService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _budgetsCol => _db.collection('budgets');
  CollectionReference get _masterBudgetCol => _db.collection('masterBudget');
  CollectionReference get _categoryBudgetCol =>
      _db.collection('categoryBudgets');
  DocumentReference get _expenseTypesDoc =>
      _db.collection('settings').doc('expenseTypes');

  // ---------- BUDGETS ----------
  Future<void> addBudget(Budget budget) {
    return _budgetsCol.doc(budget.id).set({
      'id': budget.id,
      'amount': budget.amount,
      'expenseType': budget.expenseType,
      'dateTime': budget.dateTime.toIso8601String(),
      'profileName': budget.profileName,
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
      'createdByUsername': budget.createdByUsername,
      if (budget.imageUrl != null) 'imageUrl': budget.imageUrl,
    });
  }

  Future<void> deleteBudget(String id) {
    return _budgetsCol.doc(id).delete();
  }

  Stream<List<Budget>> watchBudgets() {
    return _budgetsCol
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Budget.fromJson(d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  // ---------- MASTER BUDGET ----------
  Future<void> setMasterBudget(double amount) {
    return _masterBudgetCol.doc('budget').set({
      'amount': amount,
      'setBy': FirebaseAuth.instance.currentUser?.email,
      'setAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<double> watchMasterBudget() {
    return _masterBudgetCol.doc('budget').snapshots().map((snap) {
      if (snap.exists && snap['amount'] != null) {
        return snap['amount'] as double;
      }
      return 0.0;
    });
  }

  Future<double> getMasterBudget() async {
    try {
      final doc = await _masterBudgetCol.doc('budget').get();
      if (doc.exists && doc['amount'] != null) {
        return doc['amount'] as double;
      }
    } catch (e) {
      return 0.0;
    }
    return 0.0;
  }

  // ---------- CATEGORY BUDGETS ----------
  Future<void> setCategoryBudgets(Map<String, double> categoryBudgets) {
    return _categoryBudgetCol.doc('budgets').set({
      'budgets': categoryBudgets,
      'setBy': FirebaseAuth.instance.currentUser?.email,
      'setAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<Map<String, double>> watchCategoryBudgets() {
    return _categoryBudgetCol.doc('budgets').snapshots().map((snap) {
      if (snap.exists && snap['budgets'] != null) {
        final data = snap['budgets'] as Map<String, dynamic>;
        return data.cast<String, double>();
      }
      return {};
    });
  }

  Future<Map<String, double>> getCategoryBudgets() async {
    try {
      final doc = await _categoryBudgetCol.doc('budgets').get();
      if (doc.exists && doc['budgets'] != null) {
        final data = doc['budgets'] as Map<String, dynamic>;
        return data.cast<String, double>();
      }
    } catch (e) {
      return {};
    }
    return {};
  }

  // ==================== EXPENSE TYPES / CATEGORIES ====================

  /// Save expense types to Firestore
  Future<void> saveExpenseTypes(List<String> types) async {
    try {
      await _expenseTypesDoc.set({
        'types': types,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email,
      });
    } catch (e) {
      print('Error saving expense types: $e');
    }
  }

  /// Get expense types from Firestore (one-time fetch)
  Future<List<String>> getExpenseTypes() async {
    try {
      final doc = await _expenseTypesDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['types'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting expense types: $e');
      return [];
    }
  }

  /// Watch expense types in real-time
/// Watch expense types in real-time
Stream<List<String>> watchExpenseTypes() {
  return _expenseTypesDoc.snapshots().map((doc) {
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['types'] ?? []);
    }
    return [];
  });
}

}

// ==================== STORAGE SERVICE ====================
class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String?> uploadExpenseImage(
    String userId,
    String expenseId,
    File imageFile,
  ) async {
    try {
      final path = 'expenses/$userId/$expenseId.jpg';
      await _storage.ref(path).putFile(imageFile);
      final url = await _storage.ref(path).getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> deleteExpenseImage(String userId, String expenseId) async {
    try {
      final path = 'expenses/$userId/$expenseId.jpg';
      await _storage.ref(path).delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}
