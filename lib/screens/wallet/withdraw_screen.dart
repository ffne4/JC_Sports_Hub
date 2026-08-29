import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/wallet_service.dart';
import '../../utils/constants.dart';

// Withdrawal flow: user requests an amount (minimum UGX 5,000), sees the
// 12% charge applied live as they type, and submits. The requested
// amount is moved out of their spendable balance immediately so it can't
// be double-spent while the admin processes the manual payout.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _momoNumberController = TextEditingController();
  final WalletService _walletService = WalletService();
  bool _isSubmitting = false;
  double _enteredAmount = 0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    setState(() {
      _enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _momoNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_enteredAmount < WalletService.minimumWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Minimum withdrawal is UGX ${WalletService.minimumWithdrawal.toInt()}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final String momoNumber = _momoNumberController.text.trim();
    if (momoNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the mobile money number to receive your payout'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Confirm the number before any Firestore write happens.
    final bool confirmed = await _confirmWithdrawal(
      amount: _enteredAmount,
      netAmount: _enteredAmount * (1 - WalletService.withdrawalChargeRate),
      momoNumber: momoNumber,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    final result = await _walletService.requestWithdrawal(
      userId: user.uid,
      userName: user.displayName ?? user.email ?? 'User',
      amount: _enteredAmount,
      momoNumber: momoNumber,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result['success']) {
        Navigator.pop(context);
      }
    }
  }

  // Shows a confirmation dialog with the entered mobile money number and the
  // net amount the user will receive. Returns true only if the user confirms,
  // false if they cancel (the user stays on the screen either way).
  Future<bool> _confirmWithdrawal({
    required double amount,
    required double netAmount,
    required String momoNumber,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
        title: const Text('Confirm Withdrawal',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to withdraw UGX ${amount.toInt()} to the following mobile money number:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          momoNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.fontLarge,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'You will receive UGX ${netAmount.toInt()} after the 12% charge',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Is this number correct?',
              style: TextStyle(
                  color: Colors.grey.shade800, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check),
            label: const Text('Confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final double netAmount =
        _enteredAmount * (1 - WalletService.withdrawalChargeRate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Withdraw', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How much do you want to withdraw?',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Minimum UGX ${WalletService.minimumWithdrawal.toInt()}. A 12% withdrawal charge applies.',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: AppSizes.fontSmall),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    decoration: InputDecoration(
                      labelText: 'Amount (UGX)',
                      prefixIcon: const Icon(Icons.payments_outlined,
                          color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _momoNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile money number to receive money',
                      hintText: 'e.g. 07XXXXXXXX',
                      prefixIcon: const Icon(Icons.phone_android,
                          color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LIVE NET AMOUNT PREVIEW
            if (_enteredAmount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('You requested',
                            style: TextStyle(color: Colors.grey.shade600)),
                        const Spacer(),
                        Text('UGX ${_enteredAmount.toInt()}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('12% withdrawal charge',
                            style: TextStyle(color: Colors.grey.shade600)),
                        const Spacer(),
                        Text('- UGX ${(_enteredAmount - netAmount).toInt()}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Text("You'll receive",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          'UGX ${netAmount.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: AppSizes.fontLarge,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitWithdrawal,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_circle_up_outlined),
                label: const Text('Request Withdrawal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The admin will send this to you manually and confirm once paid.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: AppSizes.fontSmall),
            ),
          ],
        ),
      ),
    );
  }
}
