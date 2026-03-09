// home_screen.dart

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
  bool _openAddCategoryDialog = false;
  final _budgetService = BudgetService();
  final _authService = AuthService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  List<Budget> budgets = [];
  String currentUsername = '';
  double masterBudget = 0.0;
  double totalExpenses = 0.0;
  Map<String, double> categoryBudgets = {};
  String currentProfile = 'You';
  bool isExpanded = false;

  List<String> expenseTypes = [
    'Stationary',
    'Trophy Material',
    'Food',
    'Transport',
    'Entertainment',
    'Utilities',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadExpenseTypes();
  }

  /// Load saved expense types from Firestore
  Future<void> _loadExpenseTypes() async {
    final savedTypes = await _budgetService.getExpenseTypes();
    if (savedTypes.isNotEmpty) {
      setState(() {
        expenseTypes = savedTypes;
      });
    }
  }

  void _showAddExpenseTypeDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Expense Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Category Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newType = controller.text.trim();
                if (newType.isEmpty) return;

                if (expenseTypes.contains(newType)) {
                  if (mounted) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(content: Text('Category already exists')),
                    );
                  }
                  return;
                }

                // Add to local list
                setState(() {
                  expenseTypes.add(newType);
                });

                // Save to Firestore
                await _budgetService.saveExpenseTypes(expenseTypes);

                controller.dispose();
                if (mounted) Navigator.pop(dialogContext);

                if (mounted) {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(content: Text('✅ "$newType" added')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadUsername() async {
    final username = await _authService.getCurrentUsername();
    if (mounted) {
      setState(() {
        currentUsername = username;
      });
    }
  }

  double getTotalAmount() {
    return budgets.fold(0, (sum, budget) => sum + budget.amount);
  }

  List<Budget> getCurrentProfileBudgets() {
    final isAdmin = _authService.isAdmin();
    final currentUserId = _authService.getCurrentUserId();

    if (isAdmin && currentProfile == 'All') {
      return budgets;
    }

    return budgets.where((b) {
      if (isAdmin) {
        return b.profileName == currentProfile;
      } else {
        return b.createdBy == currentUserId;
      }
    }).toList();
  }

  double getCurrentProfileTotal() {
    return getCurrentProfileBudgets().fold(
      0,
      (sum, budget) => sum + budget.amount,
    );
  }

  double getCategoryExpense(String category) {
    final isAdmin = _authService.isAdmin();
    final currentUserId = _authService.getCurrentUserId();

    final filtered = budgets.where((b) {
      final matchesCategory = b.expenseType == category;
      if (isAdmin) {
        return matchesCategory;
      } else {
        return matchesCategory && b.createdBy == currentUserId;
      }
    });

    return filtered.fold(0, (sum, budget) => sum + budget.amount);
  }

  void addBudgetToFirestore(Budget budget) async {
    await _budgetService.addBudget(budget);
  }

  void removeBudgetFromFirestore(String id, String budgetCreatedBy) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid != budgetCreatedBy) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('You can only delete your own expenses')),
      );
      return;
    }
    await _budgetService.deleteBudget(id);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _authService.isAdmin();

    return StreamBuilder<List<Budget>>(
      stream: _budgetService.watchBudgets(),
      builder: (context, snapshotBudgets) {
        if (snapshotBudgets.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color.fromARGB(255, 244, 244, 245),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshotBudgets.hasError) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 248, 247, 246),
            body: Center(child: Text('Error: ${snapshotBudgets.error}')),
          );
        }

        budgets = snapshotBudgets.data ?? [];
        totalExpenses = getTotalAmount();

        return StreamBuilder<double>(
          stream: _budgetService.watchMasterBudget(),
          builder: (context, snapshotMaster) {
            if (snapshotMaster.hasData) {
              masterBudget = snapshotMaster.data ?? 0.0;
            }

            return StreamBuilder<Map<String, double>>(
              stream: _budgetService.watchCategoryBudgets(),
              builder: (context, snapshotCategories) {
                if (snapshotCategories.hasData) {
                  categoryBudgets = snapshotCategories.data ?? {};
                }

                final currentProfileBudgets = getCurrentProfileBudgets();
                final currentTotal = getCurrentProfileTotal();
                final remainingBudget = masterBudget - totalExpenses;
                final displayAmount =
                    masterBudget > 0 ? remainingBudget : currentTotal;

                // Force expanded state for non-admin users
                if (!isAdmin && !isExpanded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        isExpanded = true;
                      });
                    }
                  });
                }

                if (_openAddCategoryDialog) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;

                    _openAddCategoryDialog = false;
                    _showAddExpenseTypeDialog();
                  });
                }

                return Scaffold(
                  backgroundColor: const Color.fromARGB(255, 246, 243, 243),
                  appBar: AppBar(
                    backgroundColor: const Color.fromARGB(255, 81, 134, 240),
                    title: const Text(
                      'Algo Budget',
                      style: TextStyle(color: Colors.black),
                    ),
                    centerTitle: true,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await AuthService().signOut();
                        },
                      ),
                    ],
                  ),
                  drawer: _buildDrawer(),
                  body: isAdmin
                      ? _buildAdminBody(
                          currentProfileBudgets,
                          currentTotal,
                          displayAmount,
                          isAdmin,
                        )
                      : _buildUserBody(
                          currentProfileBudgets,
                          currentTotal,
                          displayAmount,
                        ),
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: _showAddBudgetDialog,
                    label: const Text('Add Budget'),
                    icon: const Icon(Icons.add),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // UI for admin users (show collapsed/expanded card)
  Widget _buildAdminBody(
    List<Budget> budgets,
    double currentTotal,
    double displayAmount,
    bool isAdmin,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            color: Colors.blue.shade500,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(radius: 22, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      Text(
                        currentUsername,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Budget',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isExpanded ? double.infinity : 280,
                height: isExpanded ? double.infinity : 200,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isExpanded ? 0 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: isExpanded
                    ? _buildExpandedCard(
                        budgets,
                        currentTotal,
                        displayAmount,
                        isAdmin,
                      )
                    : _buildCollapsedCard(displayAmount, true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // UI for regular users (show transactions directly, no welcome card)
  Widget _buildUserBody(
    List<Budget> budgets,
    double currentTotal,
    double displayAmount,
  ) {
    return _buildExpandedCard(budgets, currentTotal, displayAmount, false);
  }

  Widget _buildCollapsedCard(double amount, bool isAdminView) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount),
      duration: UIConfig.slow,
      curve: UIConfig.curve,
      builder: (context, value, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Budget',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '₹ ${value.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap to expand',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpandedCard(
    List<Budget> budgets,
    double currentTotal,
    double displayAmount,
    bool isAdmin,
  ) {
    return Column(
      children: [
        if (isAdmin)
          AnimatedContainer(
            duration: UIConfig.medium,
            curve: UIConfig.curve,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade900, Colors.blue.shade600],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Budget Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isExpanded = false;
                        });
                      },
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total: ₹ ${displayAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade900, Colors.blue.shade600],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Budget Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your transactions',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        Expanded(
          child: budgets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.inbox, color: Colors.black12, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'No expenses yet',
                        style: TextStyle(color: Colors.black12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: budgets.length,
                  itemBuilder: (context, index) {
                    final budget = budgets[index];
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isOwnExpense = currentUser?.uid == budget.createdBy;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1),
                      duration: UIConfig.medium,
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.receipt,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(
                                budget.expenseType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'By: ${budget.createdByUsername}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${budget.dateTime.day}/${budget.dateTime.month}/${budget.dateTime.year} ${budget.dateTime.hour}:${budget.dateTime.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹ ${budget.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (isOwnExpense)
                                    GestureDetector(
                                      onTap: () {
                                        removeBudgetFromFirestore(
                                          budget.id,
                                          budget.createdBy,
                                        );
                                      },
                                      child: const Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 18),
                                ],
                              ),
                            ),
                            if (budget.imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    budget.imageUrl!,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddBudgetDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AddBudgetDialog(
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
          onBudgetAdded: () {
            Navigator.pop(dialogContext);
          },
        );
      },
    );
  }

  void _showSetBudgetDialog() {
    final budgetController = TextEditingController();

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Master Budget'),
          content: TextField(
            controller: budgetController,
            decoration: const InputDecoration(
              labelText: 'Budget Amount (₹)',
              prefixText: '₹ ',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                budgetController.dispose();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (budgetController.text.trim().isEmpty) return;

                final amount = double.parse(budgetController.text.trim());
                await _budgetService.setMasterBudget(amount);

                Navigator.of(dialogContext, rootNavigator: true).pop();
                budgetController.dispose();

                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text(
                          '✅ Budget set to ₹${amount.toStringAsFixed(0)}',
                        ),
                      ),
                    );
                  }
                });
              },
              child: const Text('Set Budget'),
            ),
          ],
        );
      },
    );
  }

  void _showSetCategoryBudgetsDialog() {
    final controllers = <String, TextEditingController>{};

    for (var type in expenseTypes) {
      controllers[type] = TextEditingController(
        text: categoryBudgets[type]?.toStringAsFixed(0) ?? '',
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Category Budgets'),
          content: SingleChildScrollView(
            child: Column(
              children: expenseTypes.map((type) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[type],
                    decoration: InputDecoration(
                      labelText: type,
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                for (var c in controllers.values) {
                  c.dispose();
                }
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final map = <String, double>{};

                for (var type in expenseTypes) {
                  final txt = controllers[type]!.text.trim();
                  if (txt.isNotEmpty) {
                    map[type] = double.parse(txt);
                  }
                }

                if (map.isEmpty) {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text('Please enter at least one budget'),
                    ),
                  );
                  return;
                }

                await _budgetService.setCategoryBudgets(map);

                Navigator.pop(dialogContext);
                for (var c in controllers.values) {
                  c.dispose();
                }

                if (mounted) {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(content: Text('Category budgets updated')),
                  );
                }
              },
              child: const Text('Save Budgets'),
            ),
          ],
        );
      },
    );
  }

  void _showAnalyticsScreen() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Budget Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...expenseTypes.map((category) {
                          final allocated = categoryBudgets[category] ?? 0.0;
                          final used = getCategoryExpense(category);
                          final remaining = allocated - used;
                          final percentage = allocated > 0
                              ? (used / allocated) * 100
                              : 0.0;
                          final isExceeded = used > allocated && allocated > 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        category,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (isExceeded)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            '❌ EXCEEDED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Allocated: ₹${allocated.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Used: ₹${used.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isExceeded
                                              ? Colors.red
                                              : Colors.black,
                                          fontWeight: isExceeded
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: isExceeded
                                          ? 1.0
                                          : (percentage / 100),
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isExceeded
                                            ? Colors.red
                                            : (percentage > 80
                                                  ? Colors.orange
                                                  : Colors.green),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isExceeded
                                        ? 'Exceeded by: ₹${(used - allocated).toStringAsFixed(2)}'
                                        : 'Remaining: ₹${remaining.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}% used)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isExceeded
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    final isAdmin = _authService.isAdmin();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Algorithm X.O',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Logged in as: $currentUsername',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Set Master Budget'),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(
                  const Duration(milliseconds: 150),
                  _showSetBudgetDialog,
                );
              },
            ),

            /// 🔽 EXPANDABLE MANAGE CATEGORIES
            ExpansionTile(
              leading: const Icon(Icons.category),
              title: const Text('Manage Categories'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                ...expenseTypes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final type = entry.value;
                  return ListTile(
                    key: ValueKey<String>(type),
                    leading: const Icon(Icons.arrow_right),
                    title: Text(type),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text('Delete Category?'),
                              content: Text(
                                'Are you sure you want to delete "$type"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    setState(() {
                                      expenseTypes.removeAt(index);
                                    });
                                    await _budgetService
                                        .saveExpenseTypes(expenseTypes);
                                    if (mounted) Navigator.pop(dialogContext);
                                    if (mounted) {
                                      scaffoldMessengerKey.currentState
                                          ?.showSnackBar(
                                        SnackBar(
                                          content: Text('✅ "$type" deleted'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  );
                }).toList(),
                const Divider(),
                ListTile(
                  key: const ValueKey<String>('add_category'),
                  leading: const Icon(Icons.add, color: Colors.blue),
                  title: const Text(
                    'Add New Category',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _openAddCategoryDialog = true;
                    });
                  },
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Set Category Budgets'),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(Duration.zero, _showSetCategoryBudgetsDialog);
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(Duration.zero, _showAnalyticsScreen);
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await AuthService().signOut();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
