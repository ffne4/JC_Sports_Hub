import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jc_sports_hub/utils/constants.dart';
import 'package:jc_sports_hub/services/otp_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final OtpService _otpService = OtpService();

  // We need 6 separate controllers - one for each OTP digit box
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  // FocusNodes control which text field is currently active (has keyboard focus)
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResending = false;

  // Countdown timer for resend button - starts at 60 seconds
  int _resendCountdown = 60;
  bool _canResend = false;

  // These come from the previous screen via Navigator arguments
  late String _userId;
  late String _email;
  late String _name;
  bool _argumentsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Start the countdown timer when screen loads
    _startResendCountdown();
  }

  // didChangeDependencies is called after initState and when dependencies change
  // We load Navigator arguments here because context isn't ready in initState
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentsLoaded) {
      // ModalRoute.of(context)!.settings.arguments gets data passed via Navigator
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _userId = args['userId'];
      _email = args['email'];
      _name = args['name'];
      _argumentsLoaded = true;
    }
  }

  // Counts down from 60 to 0 then enables the resend button
  void _startResendCountdown() async {
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });

    // Loop 60 times, waiting 1 second each time
    for (int i = 60; i > 0; i--) {
      // Check if screen is still mounted before updating state
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _resendCountdown = i - 1;
      });
    }

    if (mounted) {
      setState(() {
        _canResend = true;
      });
    }
  }

  // Gets the complete 6-digit code from all 6 controllers
  String get _otpCode {
    // .map() transforms each controller to its text value
    // .join() combines them into one string
    return _controllers.map((c) => c.text).join();
  }

  // Called when user types in any OTP box
  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      // If a digit was entered and we're not on the last box,
      // automatically move focus to the next box
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      // If user deleted a digit, move focus back to previous box
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-submit when all 6 digits are filled
    if (_otpCode.length == 6) {
      _verifyOtp();
    }
  }

  // Verifies the entered OTP code
  void _verifyOtp() async {
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 6 digits'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> result = await _otpService.verifyOtp(
      userId: _userId,
      enteredCode: _otpCode,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Navigate to login screen after successful verification
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // Show error and clear the boxes
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Clear all OTP boxes so user can try again
        for (var controller in _controllers) {
          controller.clear();
        }
        // Move focus back to first box
        _focusNodes[0].requestFocus();
      }
    }
  }

  // Resends a fresh OTP code
  void _resendOtp() async {
    setState(() => _isResending = true);

    Map<String, dynamic> result = await _otpService.resendOtp(
      userId: _userId,
      email: _email,
      name: _name,
    );

    setState(() => _isResending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? AppColors.accent : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (result['success']) {
        // Clear boxes and restart countdown
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
        _startResendCountdown();
      }
    }
  }

  @override
  void dispose() {
    // Dispose all 6 controllers and focus nodes
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // GREEN HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                bottom: 40,
                left: AppSizes.paddingLarge,
                right: AppSizes.paddingLarge,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/signup'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Shield icon for verification feel
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontXL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Show masked email like: dr***@students.mak.ac.ug
                  Text(
                    _argumentsLoaded
                        ? 'Code sent to $_email'
                        : 'Code sent to your email',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                ],
              ),
            ),

            // BODY
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingLarge),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  const Text(
                    'Enter the 6-digit code we sent to your email address',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: AppSizes.fontMedium,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 6 OTP INPUT BOXES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      6,
                      (index) => _buildOtpBox(index),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // VERIFY BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusLarge),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Verify Email',
                              style: TextStyle(
                                fontSize: AppSizes.fontMedium,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // RESEND CODE SECTION
                  _isResending
                      ? const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        )
                      : _canResend
                          ? TextButton(
                              onPressed: _resendOtp,
                              child: const Text(
                                'Resend Code',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppSizes.fontMedium,
                                ),
                              ),
                            )
                          : Text(
                              // Shows countdown: "Resend code in 45s"
                              'Resend code in ${_resendCountdown}s',
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: AppSizes.fontSmall,
                              ),
                            ),

                  const SizedBox(height: 16),

                  // Info text
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          // Expanded fills remaining horizontal space
                          child: Text(
                            'Check your spam folder if you don\'t see the email in your inbox.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: AppSizes.fontSmall,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a single OTP digit input box
  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 52,
      height: 60,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontSize: AppSizes.fontXL,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) => _onOtpChanged(value, index),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
