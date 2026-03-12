// home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'services.dart';
import 'add_budget_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _budgetService = BudgetService();
  final _authService = AuthService();
  final _teamService = TeamService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  List<Budget> budgets = [];
  List<Team> userTeams = [];
  StreamSubscription? _teamSubscription;

  String currentUsername = '';
  double masterBudget = 0.0;
  double totalExpenses = 0.0;
  Map<String, double> categoryBudgets = {};
  String currentProfile = 'You';
  bool isExpanded = false;

  // For managing activity navigation easily
  String _selectedCategoryFilter = 'All';

  List<String> expenseTypes = [
    'Stationary',
    'Trophy Material',
    'Food',
    'Transport',
    'Entertainment',
    'Utilities',
    'Other',
  ];

  // Modern, Bright Fintech Color Palette
  final Color primaryColor = const Color(0xFF2563EB); // Vibrant Royal Blue
  final Color secondaryColor = const Color(0xFF06B6D4); // Bright Cyan
  final Color bgColor = const Color(0xFFF8FAFC); // Clean Slate Off-White
  final Color textDark = const Color(0xFF1E293B); // Deep Slate for readability

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadExpenseTypes();
    _listenToTeams();
  }

  @override
  void dispose() {
    _teamSubscription?.cancel();
    super.dispose();
  }

  void _listenToTeams() {
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId != null) {
      _teamSubscription = _teamService.watchUserTeams(currentUserId).listen((teams) {
        if (mounted) {
          setState(() {
            userTeams = teams;
          });
        }
      });
    }
  }

  Future<void> _loadExpenseTypes() async {
    final savedTypes = await _budgetService.getExpenseTypes();
    if (savedTypes.isNotEmpty) {
      if (mounted) setState(() => expenseTypes = savedTypes);
    }
  }

  Future<void> _loadUsername() async {
    final username = await _authService.getCurrentUsername();
    if (mounted) setState(() => currentUsername = username);
  }

  double getTotalAmount() => budgets.fold(0, (sum, budget) => sum + budget.amount);

  List<Budget> getCurrentProfileBudgets() {
    final isAdmin = _authService.isAdmin();
    final currentUserId = _authService.getCurrentUserId();
    final userTeamIds = userTeams.map((t) => t.id).toList();

    if (isAdmin && currentProfile == 'All') return budgets;

    return budgets.where((b) {
      if (isAdmin) return b.profileName == currentProfile;
      // Show if user created it OR if it belongs to a team the user is in
      return b.createdBy == currentUserId || (b.teamId != null && userTeamIds.contains(b.teamId));
    }).toList();
  }

  double getCurrentProfileTotal() => getCurrentProfileBudgets().fold(0, (sum, budget) => sum + budget.amount);

  double getCategoryExpense(String category) {
    final isAdmin = _authService.isAdmin();
    final currentUserId = _authService.getCurrentUserId();
    final userTeamIds = userTeams.map((t) => t.id).toList();

    final filtered = budgets.where((b) {
      final matchesCategory = b.expenseType == category;
      if (isAdmin) return matchesCategory;
      return matchesCategory && (b.createdBy == currentUserId || (b.teamId != null && userTeamIds.contains(b.teamId)));
    });
    return filtered.fold(0, (sum, budget) => sum + budget.amount);
  }

  void addBudgetToFirestore(Budget budget) async => await _budgetService.addBudget(budget);

  void removeBudgetFromFirestore(String id, String budgetCreatedBy) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid != budgetCreatedBy) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('You can only delete your own expenses'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await _budgetService.deleteBudget(id);
  }

  // --- DIALOGS ---

  void _showSetBudgetDialog() {
    bool isEditing = false;
    final budgetController = TextEditingController(text: masterBudget > 0 ? masterBudget.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Master Budget', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),

                      if (!isEditing) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primaryColor.withOpacity(0.2))
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Allocation', style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text('₹ ${masterBudget.toStringAsFixed(0)}', style: TextStyle(color: primaryColor, fontSize: 36, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Close', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)))),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                ),
                                onPressed: () => setDialogState(() => isEditing = true),
                                child: const Text('Edit Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        )
                      ] else ...[
                        TextField(
                          controller: budgetController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark),
                          decoration: InputDecoration(
                            labelText: 'Enter New Budget',
                            prefixText: '₹ ',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(child: TextButton(onPressed: () => setDialogState(() => isEditing = false), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)))),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                ),
                                onPressed: () async {
                                  if (budgetController.text.trim().isEmpty) return;
                                  await _budgetService.setMasterBudget(double.parse(budgetController.text.trim()));
                                  if (mounted) Navigator.pop(dialogContext);
                                },
                                child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  void _showManageCategoriesDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Manage Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: expenseTypes.isEmpty
                            ? const Center(child: Text('No categories available.'))
                            : ListView.builder(
                          itemCount: expenseTypes.length,
                          itemBuilder: (context, index) {
                            final type = expenseTypes[index];
                            final limit = categoryBudgets[type] ?? 0.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Limit: ₹${limit.toStringAsFixed(0)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () async {
                                    setDialogState(() => expenseTypes.removeAt(index));
                                    await _budgetService.saveExpenseTypes(expenseTypes);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showAddExpenseTypeDialog();
                        },
                        child: const Text('+ Add New Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  void _showAddExpenseTypeDialog() {
    final nameController = TextEditingController();
    final limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Category', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Office Supplies',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monthly Limit (Required)',
                    prefixText: '₹ ',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showManageCategoriesDialog();
                        },
                        child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final newType = nameController.text.trim();
                          final newLimitStr = limitController.text.trim();

                          if (newType.isEmpty || newLimitStr.isEmpty) {
                            scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Both Name and Limit are required!')));
                            return;
                          }

                          if (expenseTypes.contains(newType)) {
                            scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Category already exists')));
                            return;
                          }

                          final newLimit = double.tryParse(newLimitStr);
                          if (newLimit == null) return;

                          setState(() => expenseTypes.add(newType));
                          await _budgetService.saveExpenseTypes(expenseTypes);

                          final updatedBudgets = Map<String, double>.from(categoryBudgets);
                          updatedBudgets[newType] = newLimit;
                          await _budgetService.setCategoryBudgets(updatedBudgets);

                          if (mounted) {
                            Navigator.pop(dialogContext);
                            _showManageCategoriesDialog();
                          }
                        },
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UPDATED: Manage Teams Dialog with robust error checking ---
  void _showManageTeamsDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        bool isCreating = false;
        bool isAdding = false;

        return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Create a Team', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                              labelText: 'Team Name',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: isCreating ? null : () async {
                            if (nameController.text.trim().isEmpty) {
                              scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Enter a team name first')));
                              return;
                            }

                            setDialogState(() => isCreating = true);
                            try {
                              await _teamService.createTeam(nameController.text.trim(), _authService.getCurrentUserId()!);
                              scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ Team created successfully!')));
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Failed: Check Firestore rules ($e)')));
                              setDialogState(() => isCreating = false);
                            }
                          },
                          child: isCreating
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Create Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),

                        const Divider(height: 40),

                        const Text('Add Member to Team', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Adds member to your first available team.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                              labelText: 'User Email to Add',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: secondaryColor,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: isAdding ? null : () async {
                            if (userTeams.isEmpty) {
                              scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Please create a team first!')));
                              return;
                            }
                            if (emailController.text.trim().isEmpty) {
                              scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Enter an email address')));
                              return;
                            }

                            setDialogState(() => isAdding = true);
                            try {
                              final msg = await _teamService.addMemberByEmail(userTeams.first.id, emailController.text.trim());
                              scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg!)));
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Failed: $e')));
                              setDialogState(() => isAdding = false);
                            }
                          },
                          child: isAdding
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Invite Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
        );
      },
    );
  }

  // --- FULL SCREEN ACTIVITY MODAL ---
  void _showFullActivityModal(List<String> allGroupKeys, Map<String, List<Budget>> groupedBudgets, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final categoryLabel = _selectedCategoryFilter == 'All' ? 'Transactions' : '$_selectedCategoryFilter Transactions';
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text('All $categoryLabel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark)),
              const SizedBox(height: 8),
              Expanded(
                child: _buildGroupedDatesList(allGroupKeys, groupedBudgets, isAdmin, bottomPadding: 40),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MAIN UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final isAdmin = _authService.isAdmin();

    return StreamBuilder<List<Budget>>(
      stream: _budgetService.watchBudgets(),
      builder: (context, snapshotBudgets) {
        if (snapshotBudgets.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: primaryColor)));
        }

        budgets = snapshotBudgets.data ?? [];
        totalExpenses = getTotalAmount();

        return StreamBuilder<double>(
          stream: _budgetService.watchMasterBudget(),
          builder: (context, snapshotMaster) {
            if (snapshotMaster.hasData) masterBudget = snapshotMaster.data ?? 0.0;

            return StreamBuilder<Map<String, double>>(
              stream: _budgetService.watchCategoryBudgets(),
              builder: (context, snapshotCategories) {
                if (snapshotCategories.hasData) categoryBudgets = snapshotCategories.data ?? {};

                final currentProfileBudgets = getCurrentProfileBudgets();
                final currentTotal = getCurrentProfileTotal();
                final remainingBudget = masterBudget - totalExpenses;

                if (!isAdmin && !isExpanded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => isExpanded = true);
                  });
                }

                // FILTERING LOGIC
                List<Budget> displayBudgets = currentProfileBudgets;
                if (_selectedCategoryFilter != 'All') {
                  displayBudgets = currentProfileBudgets.where((b) => b.expenseType == _selectedCategoryFilter).toList();
                }

                // GROUPING BY TEAM FOR FOLDERS
                Map<String, List<Budget>> groupedBudgets = {};
                for (var budget in displayBudgets) {
                  final groupKey = budget.teamName ?? 'Personal'; // Group by Team
                  if (!groupedBudgets.containsKey(groupKey)) {
                    groupedBudgets[groupKey] = [];
                  }
                  groupedBudgets[groupKey]!.add(budget);
                }

                List<String> allGroupKeys = groupedBudgets.keys.toList();

                // Truncate logic for home screen: Only show Top 3
                final recentGroupKeys = allGroupKeys.take(3).toList();
                final hasMore = allGroupKeys.length > 3;

                return Scaffold(
                  backgroundColor: bgColor,
                  appBar: _buildAppBar(isAdmin),
                  drawer: _buildDrawer(isAdmin),
                  body: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeHeader(isAdmin),

                        if (isAdmin)
                          _buildDashboardCard(remainingBudget, totalExpenses, isMaster: true)
                        else
                          _buildDashboardCard(currentTotal, 0, isMaster: false),

                        const SizedBox(height: 24),

                        // NEW: Added Teams quick-access button to the Home screen
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isAdmin ? 'Activity Overview' : 'My Activity',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                              ),
                              InkWell(
                                onTap: _showManageTeamsDialog,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.group_add_rounded, size: 16, color: primaryColor),
                                      const SizedBox(width: 6),
                                      Text('Teams', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildCategoryFilters(),

                        Expanded(
                          child: allGroupKeys.isEmpty
                              ? _buildEmptyState(isAdmin)
                              : Column(
                            children: [
                              Expanded(
                                  child: _buildGroupedDatesList(recentGroupKeys, groupedBudgets, isAdmin, bottomPadding: hasMore ? 16 : 100)
                              ),
                              if (hasMore)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(left: 24, right: 24, bottom: 90), // Clears the FAB
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                    ),
                                    onPressed: () => _showFullActivityModal(allGroupKeys, groupedBudgets, isAdmin),
                                    child: Text(
                                        'View All ${allGroupKeys.length} Teams/Folders',
                                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15)
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
                  floatingActionButton: _buildFloatingActionButton(),
                );
              },
            );
          },
        );
      },
    );
  }

  AppBar _buildAppBar(bool isAdmin) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textDark),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pie_chart_rounded, color: primaryColor, size: 24),
          const SizedBox(width: 8),
          Text('AlgoBudget', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 20)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            child: IconButton(
              icon: Icon(isAdmin ? Icons.shield_rounded : Icons.person, color: primaryColor),
              onPressed: () => scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Logged in as $currentUsername'))),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildWelcomeHeader(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isAdmin ? 'Overview,' : 'Welcome back,', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          Text(
            currentUsername.isNotEmpty ? currentUsername : (isAdmin ? 'Admin' : 'User'),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(double mainAmount, double subAmount, {required bool isMaster}) {
    return GestureDetector(
      onTap: isMaster ? () => setState(() => isExpanded = !isExpanded) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(colors: [primaryColor, secondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.35), blurRadius: 25, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(isMaster ? Icons.account_balance_rounded : Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(isMaster ? 'Master Budget Remaining' : 'My Total Spending', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                if (isMaster) Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 24),
            Text('₹ ${mainAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1)),

            if (isMaster && isExpanded) ...[
              const SizedBox(height: 24),
              const Divider(color: Colors.white30, thickness: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Org. Spent', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('₹ ${subAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Allocated', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('₹ ${masterBudget.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    List<String> filters = ['All', ...expenseTypes];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedCategoryFilter == filter;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
                boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupedDatesList(List<String> groupKeys, Map<String, List<Budget>> groupedBudgets, bool isAdmin, {double bottomPadding = 100}) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPadding),
      physics: const BouncingScrollPhysics(),
      itemCount: groupKeys.length,
      itemBuilder: (context, index) {
        String groupKey = groupKeys[index];
        List<Budget> groupBudgets = groupedBudgets[groupKey]!;

        double groupTotal = groupBudgets.fold(0, (sum, b) => sum + b.amount);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              iconColor: primaryColor,
              collapsedIconColor: Colors.grey.shade400,
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                child: Icon(groupKey == 'Personal' ? Icons.person : Icons.groups_rounded, color: primaryColor),
              ),
              title: Text(groupKey, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textDark)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('${groupBudgets.length} Bills • Total: ₹${groupTotal.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                      color: bgColor.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))
                  ),
                  child: Column(
                    children: groupBudgets.map((budget) {
                      final isOwnExpense = FirebaseAuth.instance.currentUser?.uid == budget.createdBy;
                      return _buildCompactTransactionTile(budget, isAdmin, isOwnExpense);
                    }).toList(),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactTransactionTile(Budget budget, bool isAdmin, bool isOwnExpense) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTransactionDetailsBottomSheet(budget, isAdmin, isOwnExpense),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.receipt_long_rounded, color: Colors.grey.shade700, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(budget.expenseType, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textDark)),
                  const SizedBox(height: 2),
                  Text('${budget.dateTime.day}/${budget.dateTime.month}/${budget.dateTime.year} - By: ${budget.createdByUsername}', style: TextStyle(fontSize: 11, color: secondaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text('- ₹${budget.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textDark)),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailsBottomSheet(Budget budget, bool isAdmin, bool isOwnExpense) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(budget.expenseType, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
                  ],
                ),
                const SizedBox(height: 16),
                Text('₹${budget.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -1)),
                const SizedBox(height: 24),
                _buildDetailRow(Icons.calendar_today, 'Date', '${budget.dateTime.day}/${budget.dateTime.month}/${budget.dateTime.year}'),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.access_time, 'Time', '${budget.dateTime.hour}:${budget.dateTime.minute.toString().padLeft(2, '0')}'),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.person_outline, 'Added By', budget.createdByUsername),
                if (budget.teamName != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.groups_rounded, 'Team', budget.teamName!),
                ],
                const SizedBox(height: 32),
                const Text('Receipt Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (budget.imageUrl != null)
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(budget.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover))
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('No receipt attached', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                  ),
                const SizedBox(height: 32),
                if (isOwnExpense)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      onPressed: () {
                        removeBudgetFromFirestore(budget.id, budget.createdBy);
                        Navigator.pop(context);
                      },
                      child: const Text('Delete Transaction', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(color: textDark, fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }

  Widget _buildEmptyState(bool isAdmin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
            child: Icon(Icons.rocket_launch_rounded, color: secondaryColor, size: 48),
          ),
          const SizedBox(height: 24),
          Text(isAdmin && _selectedCategoryFilter == 'All' ? 'No Org Expenses Yet' : 'No expenses found!', style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Hit the button below to add an expense.', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      height: 65,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [primaryColor, secondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _showAddBudgetDialog,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text('Add Expense', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBudgetDialog() {
    showDialog(
      context: context,
      barrierColor: textDark.withOpacity(0.8),
      builder: (dialogContext) {
        return AddBudgetDialog(
          userTeams: userTeams,
          expenseTypes: expenseTypes,
          categoryBudgets: categoryBudgets,
          currentProfile: currentProfile,
          currentUsername: currentUsername,
          authService: _authService,
          storageService: _storageService,
          budgetService: _budgetService,
          imagePicker: _imagePicker,
          getCategoryExpense: getCategoryExpense,
          addBudgetToFirestore: addBudgetToFirestore,
          onBudgetAdded: () => Navigator.pop(dialogContext),
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        );
      },
    );
  }

  void _showAnalyticsScreen() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              children: [
                Text('Organization Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark)),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: expenseTypes.map((category) {
                      final allocated = categoryBudgets[category] ?? 0.0;
                      final used = getCategoryExpense(category);
                      final percentage = allocated > 0 ? (used / allocated) * 100 : 0.0;
                      final isExceeded = used > allocated && allocated > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: isExceeded ? const Color(0xFFFFF0F0) : bgColor, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: isExceeded ? 1.0 : (percentage / 100),
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(isExceeded ? Colors.redAccent : primaryColor),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Used: ₹${used.toStringAsFixed(0)}', style: TextStyle(color: isExceeded ? Colors.red : Colors.black, fontWeight: FontWeight.bold)),
                                Text('Alloc: ₹${allocated.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(bool isAdmin) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(40), bottomRight: Radius.circular(40))),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, secondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                  child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person_pin, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(isAdmin ? 'Admin Console' : 'My Account', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                Text('@$currentUsername', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildDrawerItem(Icons.home_filled, 'Home', () => Navigator.pop(context)),

          if (isAdmin) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text('ADMIN ZONE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
            _buildDrawerItem(Icons.account_balance_wallet_rounded, 'Master Budget', () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 150), _showSetBudgetDialog);
            }),
            _buildDrawerItem(Icons.category_rounded, 'Manage Categories', () {
              Navigator.pop(context);
              Future.delayed(Duration.zero, _showManageCategoriesDialog);
            }),
            _buildDrawerItem(Icons.insights_rounded, 'Analytics', () {
              Navigator.pop(context);
              Future.delayed(Duration.zero, _showAnalyticsScreen);
            }),
          ],

          const Divider(indent: 24, endIndent: 24),
          _buildDrawerItem(Icons.group_add_rounded, 'Manage Teams', () {
            Navigator.pop(context);
            _showManageTeamsDialog();
          }),

          const SizedBox(height: 20),
          const Divider(indent: 24, endIndent: 24),
          _buildDrawerItem(Icons.logout_rounded, 'Logout', () async {
            await AuthService().signOut();
            if (mounted) Navigator.pop(context);
          }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : primaryColor),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : textDark, fontSize: 16, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}