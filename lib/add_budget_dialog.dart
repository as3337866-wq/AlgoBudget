// add_budget_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'services.dart';

class AddBudgetDialog extends StatefulWidget {
  final List<String> expenseTypes;
  final Map<String, double> categoryBudgets;
  final String currentProfile;
  final String currentUsername;
  final AuthService authService;
  final StorageService storageService;
  final BudgetService budgetService;
  final ImagePicker imagePicker;
  final double Function(String) getCategoryExpense;
  final Function(Budget) addBudgetToFirestore;
  final VoidCallback onBudgetAdded;

  const AddBudgetDialog({
    super.key,
    required this.expenseTypes,
    required this.categoryBudgets,
    required this.currentProfile,
    required this.currentUsername,
    required this.authService,
    required this.storageService,
    required this.budgetService,
    required this.imagePicker,
    required this.getCategoryExpense,
    required this.addBudgetToFirestore,
    required this.onBudgetAdded,
  });

  @override
  State<AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<AddBudgetDialog> {
  late DateTime selectedDate;
  late TimeOfDay selectedTime;
  final amountController = TextEditingController();
  late String selectedExpense;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    selectedTime = TimeOfDay.now();
    selectedExpense = widget.expenseTypes[0];
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Date'),
              subtitle: Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
            ),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(
                '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (picked != null) {
                  setState(() => selectedTime = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedExpense,
              items: widget.expenseTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => selectedExpense = v!),
              decoration: const InputDecoration(labelText: 'Expense Type'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  if (selectedImage != null)
                    Stack(
                      children: [
                        Image.file(
                          selectedImage!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => selectedImage = null);
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (amountController.text.isEmpty) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Please enter amount')),
              );
              return;
            }

            final amount = double.parse(amountController.text);
            final categoryBudget =
                widget.categoryBudgets[selectedExpense] ?? 0.0;
            final used = widget.getCategoryExpense(selectedExpense);

            if (categoryBudget > 0 && used + amount > categoryBudget) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red,
                  content: Text('❌ Budget exceeded for $selectedExpense'),
                ),
              );
              return;
            }

            final dateTime = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );

            final budgetId = DateTime.now().millisecondsSinceEpoch.toString();
            String? imageUrl;

            if (selectedImage != null) {
              final userId = widget.authService.getCurrentUserId();
              imageUrl = await widget.storageService.uploadExpenseImage(
                userId ?? '',
                budgetId,
                selectedImage!,
              );
            }

            final budget = Budget(
              id: budgetId,
              amount: amount,
              expenseType: selectedExpense,
              dateTime: dateTime,
              profileName: widget.currentProfile,
              createdByUsername: widget.currentUsername,
              createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
              imageUrl: imageUrl,
            );

            widget.addBudgetToFirestore(budget);
            widget.onBudgetAdded();

            scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text('✅ Expense added successfully')),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
