// services.dart - ALL SERVICES IN ONE FILE

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'main.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';


import 'package:cloudinary_public/cloudinary_public.dart';

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
      'teamId': budget.teamId,
      'teamName': budget.teamName,
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
        // FIX: Safely convert all incoming numbers (int or double) to double
        return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
      }
      return {};
    });
  }

  Future<Map<String, double>> getCategoryBudgets() async {
    try {
      final doc = await _categoryBudgetCol.doc('budgets').get();
      if (doc.exists && doc['budgets'] != null) {
        final data = doc['budgets'] as Map<String, dynamic>;
        // FIX: Safely convert all incoming numbers (int or double) to double
        return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
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
  // TODO: Replace these with your actual Cloudinary details
  final String cloudName = 'dar7wm820';
  final String uploadPreset = 'xnblalbp';

  Future<String?> uploadExpenseImage({
    required String userId,
    required String budgetId,
    required File imageFile,
    String? teamId,
    required String expenseType,
  }) async {
    try {
      final year = DateTime.now().year.toString();
      final month = DateTime.now().month.toString().padLeft(2, '0');

      String folderPath;
      if (teamId != null) {
        folderPath = 'algobudget/teams/$teamId/$year/$month';
      } else {
        folderPath = 'algobudget/personal/$userId/$year/$month';
      }

      // Replace these with your actual Cloudinary details
      final cloudinary = CloudinaryPublic('dar7wm820', 'receipts_cloudinary', cache: false);

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folderPath,
          publicId: 'receipt_$budgetId',
          tags: ['receipt', expenseType, teamId ?? 'personal'],
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }

  Future<void> deleteExpenseImage(String userId, String expenseId) async {
    // Note: Deleting images securely from the client-side via Cloudinary requires
    // an API Secret, which should not be exposed in a Flutter app.
    // It is best to handle deletions through a backend server.
    print('Client-side deletion is not supported without exposing Cloudinary API Secret.');
  }

  // Permanently delete image from Cloudinary
  Future<void> deleteCloudinaryImage(String imageUrl) async {
    try {
      // 1. Extract the "public_id" from the image URL
      final parts = imageUrl.split('/upload/');
      if (parts.length < 2) return;

      String publicId = parts[1];
      // Remove the version tag (e.g., v1712345678/)
      if (publicId.startsWith('v') && publicId.contains('/')) {
        publicId = publicId.substring(publicId.indexOf('/') + 1);
      }
      // Remove the file extension (.jpg or .png)
      if (publicId.contains('.')) {
        publicId = publicId.substring(0, publicId.lastIndexOf('.'));
      }

      // 2. YOUR CLOUDINARY CREDENTIALS (Find these on your dashboard)
      const String cloudName = 'YOUR_CLOUD_NAME';
      const String apiKey = 'YOUR_API_KEY';
      const String apiSecret = 'YOUR_API_SECRET';

      // 3. Send the secure destroy request
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      await http.post(
        uri,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}',
        },
        body: {'public_id': publicId},
      );
      print('Cloudinary Image Deleted!');
    } catch (e) {
      print("Cloudinary Delete Error: $e");
    }
  }
}


// ==================== TEAM MODEL ====================
class Team {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members; // List of user UIDs

  Team({required this.id, required this.name, required this.createdBy, required this.members});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'createdBy': createdBy, 'members': members};

  factory Team.fromJson(Map<String, dynamic> json) => Team(
      id: json['id'],
      name: json['name'],
      createdBy: json['createdBy'],
      members: List<String>.from(json['members'] ?? [])
  );
}

// ==================== TEAM SERVICE ====================
class TeamService {
  final _db = FirebaseFirestore.instance;

  Future<void> createTeam(String name, String currentUserId) async {
    final doc = _db.collection('teams').doc();
    await doc.set(Team(
        id: doc.id,
        name: name,
        createdBy: currentUserId,
        members: [currentUserId])
        .toJson());
  }

  Future<void> addMemberById(String teamId, String userId) async {
    await _db.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> removeMemberById(String teamId, String userId) async {
    await _db.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayRemove([userId])
    });
  }

  // NEW: Delete Entire Team
  Future<void> deleteTeam(String teamId) async {
    await _db.collection('teams').doc(teamId).delete();
  }

  Future<String?> addMemberByEmail(String teamId, String email) async {
    final userQuery = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .get();
    if (userQuery.docs.isNotEmpty) {
      final userId = userQuery.docs.first.id;
      await _db.collection('teams').doc(teamId).update({
        'members': FieldValue.arrayUnion([userId])
      });
      return "Member added successfully!";
    }
    return "User not found. Ensure they have registered.";
  }

  Stream<List<Team>> watchUserTeams(String userId) {
    return _db
        .collection('teams')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Team.fromJson(d.data())).toList());
  }

  Future<List<Map<String, dynamic>>> getAllRegisteredUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'email': data['email'] ?? '',
        'username': data['username'] ?? 'Unknown User',
        // Check if user is admin based on flag or hardcoded logic
        'isAdmin': data['isAdmin'] == true || data['role'] == 'admin',
      };
    }).toList();
  }
}