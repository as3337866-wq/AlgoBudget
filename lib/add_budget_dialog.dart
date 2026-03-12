// add_budget_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'services.dart';

class AddBudgetDialog extends StatefulWidget {
  final List<Team> userTeams;
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
  final Color primaryColor;
  final Color secondaryColor;

  const AddBudgetDialog({
    super.key,
    required this.userTeams,
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
    required this.primaryColor,
    required this.secondaryColor,
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
  Team? selectedTeam;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    selectedTime = TimeOfDay.now();
    selectedExpense = widget.expenseTypes.isNotEmpty ? widget.expenseTypes[0] : '';

    // Automatically select the user's team if they belong to one
    if (widget.userTeams.isNotEmpty) {
      selectedTeam = widget.userTeams.first;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      // INCREASED quality for text readability
      imageQuality: 90,
      // CAPPING dimensions so it doesn't upload a massive 4K file
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (pickedFile != null) setState(() => selectedImage = File(pickedFile.path));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expenseTypes.isEmpty) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Text('No categories available. Please ask admin to add categories.', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 20,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text('Add Expense', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.5)),
              const SizedBox(height: 30),

              // Amount Input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: amountController,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: widget.primaryColor),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.normal),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: widget.primaryColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedExpense,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: widget.primaryColor, size: 30),
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700),
                    items: widget.expenseTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => selectedExpense = v!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Team Dropdown Selection
              if (widget.userTeams.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Team?>(
                      isExpanded: true,
                      value: selectedTeam,
                      hint: const Text("Select Team (Optional)", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
                      icon: Icon(Icons.groups_rounded, color: widget.primaryColor, size: 30),
                      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("Personal Expense")),
                        ...widget.userTeams.map((t) => DropdownMenuItem(value: t, child: Text('Team: ${t.name}'))),
                      ],
                      onChanged: (v) => setState(() => selectedTeam = v),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Date & Time Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: widget.primaryColor),
                            const SizedBox(height: 8),
                            Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: selectedTime);
                        if (picked != null) setState(() => selectedTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          children: [
                            Icon(Icons.access_time_filled_rounded, color: widget.primaryColor),
                            const SizedBox(height: 8),
                            Text('${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ... existing code ...

              // Image Picker (Updated UI)
              selectedImage != null
                  ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(selectedImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              )
                  : GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    // Changed border to red to indicate it is a required field
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, color: widget.primaryColor, size: 36),
                      const SizedBox(height: 8),
                      // Updated text to explicitly state it is required
                      Text('Attach Receipt (Required)', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              Container(
                width: double.infinity,
                height: 65,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(colors: [widget.primaryColor, widget.secondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: widget.primaryColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    if (amountController.text.isEmpty) {
                      scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Please enter an amount')));
                      return;
                    }

                    // --- NEW VALIDATION: Check if image is null ---
                    if (selectedImage == null) {
                      scaffoldMessengerKey.currentState?.showSnackBar(
                          const SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text('❌ A receipt image is required to add an expense.')
                          )
                      );
                      return;
                    }
                    // ----------------------------------------------

                    final amount = double.parse(amountController.text);
                    final categoryBudget = widget.categoryBudgets[selectedExpense] ?? 0.0;

                    // ... rest of your save logic ...
                    final used = widget.getCategoryExpense(selectedExpense);

                    if (categoryBudget > 0 && used + amount > categoryBudget) {
                      scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Budget exceeded for $selectedExpense')));
                      return;
                    }

                    final dateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                    final budgetId = DateTime.now().millisecondsSinceEpoch.toString();
                    String? imageUrl;

                    if (selectedImage != null) {
                      final userId = widget.authService.getCurrentUserId();
                      imageUrl = await widget.storageService.uploadExpenseImage(userId ?? '', budgetId, selectedImage!);
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
                      teamId: selectedTeam?.id,
                      teamName: selectedTeam?.name,
                    );

                    widget.addBudgetToFirestore(budget);
                    widget.onBudgetAdded();
                  },
                  child: const Text('Save Expense', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}