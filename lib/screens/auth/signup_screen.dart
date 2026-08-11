import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Tracks which user type is selected - defaults to bachelor
  // 0 = Bachelor, 1 = Diploma, 2 = Guest
  int _selectedUserType = 0;

  // GlobalKey links our Form widget to this state class
  // It lets us trigger validation from outside the form
  final _formKey = GlobalKey<FormState>();

  // TextEditingController reads and controls what's typed in a TextField
  // We need one for each input field
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _webmailController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Controls whether password text is visible or hidden
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // Controls the loading spinner when submitting
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  // User type labels shown on the selector tabs
  final List<String> _userTypes = ['Bachelor', 'Diploma', 'Guest'];

  // Icons for each user type tab
  final List<IconData> _userTypeIcons = [
    Icons.school,
    Icons.badge,
    Icons.people,
  ];

  @override
  void dispose() {
    // Dispose ALL controllers when screen is removed - prevents memory leaks
    _fullNameController.dispose();
    _emailController.dispose();
    _webmailController.dispose();
    _regNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validates the form and submits - called when user taps Sign Up
  void _onSignupPressed() async {
    if (_formKey.currentState!.validate()) {
      // Show loading spinner
      setState(() => _isLoading = true);

      // Determine email and user type based on selected tab
      String email = '';
      String userType = '';
      String? webmail;
      String? regNumber;

      if (_selectedUserType == 0) {
        // Bachelor - email is their webmail
        email = _webmailController.text.trim();
        userType = 'bachelor';
        webmail = _webmailController.text.trim();
      } else if (_selectedUserType == 1) {
        // Diploma - email is their personal email
        email = _emailController.text.trim();
        userType = 'diploma';
        regNumber = _regNumberController.text.trim();
      } else {
        // Guest
        email = _emailController.text.trim();
        userType = 'guest';
      }

      // Call our AuthService signup method
      Map<String, dynamic> result = await _authService.signUp(
        fullName: _fullNameController.text.trim(),
        email: email,
        password: _passwordController.text,
        userType: userType,
        webmail: webmail,
        regNumber: regNumber,
      );

      // Hide loading spinner
      setState(() => _isLoading = false);

      // Show result message to user using SnackBar
      // SnackBar is the small notification bar that pops up at the bottom
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            // Green for success, red for error
            backgroundColor:
                result['success'] ? AppColors.accent : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
          ),
        );

        // If signup was successful, go to login screen

        // If signup successful, go to OTP verification screen
        if (result['success']) {
          Navigator.pushReplacementNamed(
            context,
            '/verify-otp',
            // arguments passes data to the next screen
            arguments: {
              'userId': result['userId'],
              'email': result['email'],
              'name': result['name'],
            },
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // SingleChildScrollView makes the screen scrollable
      // Without this, keyboard popping up would cause overflow errors
      body: SingleChildScrollView(
        child: Column(
          children: [
            // TOP GREEN HEADER SECTION
            _buildHeader(),

            // FORM SECTION
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingMedium),
              child: Form(
                // key connects this Form to _formKey
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // USER TYPE SELECTOR
                    _buildUserTypeSelector(),

                    const SizedBox(height: 24),

                    // DYNAMIC FORM FIELDS based on selected user type
                    _buildFormFields(),

                    const SizedBox(height: 24),

                    // SIGN UP BUTTON
                    _buildSignupButton(),

                    const SizedBox(height: 16),

                    // LOGIN LINK
                    _buildLoginLink(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the green header at the top of the screen
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 60,
        bottom: 32,
        left: AppSizes.paddingLarge,
        right: AppSizes.paddingLarge,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        // Only round the bottom corners
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App logo small
          const Icon(
            Icons.sports_soccer,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 16),
          const Text(
            'Create Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join the JC Sports community',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: AppSizes.fontMedium,
            ),
          ),
        ],
      ),
    );
  }

  // Builds the 3-tab user type selector
  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'I am a...',
          style: TextStyle(
            fontSize: AppSizes.fontMedium,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 12),
        // Row of 3 selectable cards
        Row(
          children: List.generate(
            _userTypes.length,
            (index) => Expanded(
              // Expanded makes each card take equal width
              child: GestureDetector(
                // GestureDetector detects taps, swipes, long presses etc
                onTap: () {
                  setState(() {
                    _selectedUserType = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: index < _userTypes.length - 1 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    // Active tab gets primary color, inactive gets white
                    color: _selectedUserType == index
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    border: Border.all(
                      color: _selectedUserType == index
                          ? AppColors.primary
                          : Colors.grey.shade300,
                    ),
                    boxShadow: _selectedUserType == index
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _userTypeIcons[index],
                        color: _selectedUserType == index
                            ? Colors.white
                            : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userTypes[index],
                        style: TextStyle(
                          color: _selectedUserType == index
                              ? Colors.white
                              : Colors.grey,
                          fontSize: AppSizes.fontSmall,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Builds form fields dynamically based on selected user type
  Widget _buildFormFields() {
    return Column(
      children: [
        // Full name - shown for ALL user types
        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person,
          validator: (value) {
            // validator runs when form.validate() is called
            // Return null means valid, return a string means error message
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            if (value.trim().length < 3) {
              return 'Name must be at least 3 characters';
            }
            return null; // null means no error
          },
        ),

        const SizedBox(height: 16),

        // BACHELOR SPECIFIC - webmail field
        if (_selectedUserType == 0) ...[
          // The '...' spread operator adds multiple widgets to the list
          _buildTextField(
            controller: _webmailController,
            label: 'University Webmail',
            hint: 'lastname.firstname@students.mak.ac.ug',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your webmail';
              }
              // Check if webmail ends with correct domain
              if (!value.trim().endsWith(AppStrings.bachelorDomain)) {
                return 'Must be a valid @students.mak.ac.ug email';
              }
              return null;
            },
          ),
        ],

        // DIPLOMA SPECIFIC - reg number + personal email
        if (_selectedUserType == 1) ...[
          _buildTextField(
            controller: _regNumberController,
            label: 'Registration Number',
            hint: 'Enter your registration number',
            icon: Icons.badge,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your registration number';
              }
              if (!value.trim().toUpperCase().contains('JJA')) {
                return 'Incorrect format';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Personal Email',
            hint: 'Enter your personal email',
            icon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              // Simple email format check using contains
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
        ],

        // GUEST SPECIFIC - just personal email
        if (_selectedUserType == 2) ...[
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'Enter your email address',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
        ],

        const SizedBox(height: 16),

        // Password - shown for ALL user types
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create a strong password',
          icon: Icons.lock,
          // obscureText hides the typed characters
          obscureText: !_passwordVisible,
          // suffixIcon is the eye icon to toggle visibility
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _passwordVisible = !_passwordVisible;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Confirm password
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          icon: Icons.lock_outline,
          obscureText: !_confirmPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _confirmPasswordVisible = !_confirmPasswordVisible;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            // Check if passwords match
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  // Reusable text field builder - avoids repeating the same styling
  // every time we need a text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      // TextFormField is a TextField that works inside a Form with validation
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // prefixIcon shows an icon on the left side of the field
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffixIcon,
        // filled adds a background color to the field
        filled: true,
        fillColor: Colors.white,
        // OutlineInputBorder gives the field a bordered box style
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
          // focusedBorder shows when the user taps on the field
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
    );
  }

  // Builds the signup button
  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onSignupPressed,
        // When loading, disable button by passing null to onPressed
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
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
                'Create Account',
                style: TextStyle(
                  fontSize: AppSizes.fontMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // Builds the "Already have an account? Login" link
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
          child: const Text(
            'Login',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
