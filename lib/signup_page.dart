import 'package:flutter/material.dart';
import 'readloop_live_server.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // ✅ KEY FIX: Call ApiService.register() directly instead of
      // userProvider.register() — the provider version calls login()
      // internally which sets isLoggedIn = true and causes AuthWrapper
      // to auto-navigate to MainScreen before the user sees anything.
      final result = await ApiService.register(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
        _fullNameController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // ✅ Show success, stay on this page
        setState(() {
          _isSubmitting = false;
          _successMessage =
              'Your account was created successfully! Please sign in.';
        });

        // ✅ Wait 2 seconds then go back to login page
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        final raw =
            result['message']?.toString() ?? result['error']?.toString() ?? '';
        final message = raw.contains('already') ||
                raw.contains('exist') ||
                raw.contains('duplicate')
            ? 'This email is already registered. Please sign in instead.'
            : raw.isNotEmpty
                ? raw
                : 'Registration failed. Please try again.';
        setState(() {
          _isSubmitting = false;
          _errorMessage = message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _errorMessage = raw.contains('Network') || raw.contains('Connection')
            ? 'No internet connection. Please check your network.'
            : raw;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue.shade700),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.menu_book,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('ReadLoop',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                  const SizedBox(height: 4),
                  Text('Start Your Reading Journey',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 28),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Create Account',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Join our reading community today',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 14)),
                          const SizedBox(height: 24),

                          //  Success message
                          if (_successMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.blue.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_successMessage!,
                                      style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_errorMessage!,
                                      style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // full Name field
                          TextFormField(
                            controller: _fullNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration(
                                'Enter your full name', Icons.person_outline),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Please enter your full name';
                              if (v.trim().length < 2)
                                return 'Name must be at least 2 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                                'Email Address', Icons.email_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Please enter your email';
                              if (!RegExp(
                                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                  .hasMatch(v.trim()))
                                return 'Please enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration:
                                _inputDecoration('Password', Icons.lock_outline)
                                    .copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(_isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(() =>
                                    _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Please enter a password';
                              if (v.length < 8)
                                return 'Password must be at least 8 characters';
                              if (!RegExp(r'[A-Z]').hasMatch(v))
                                return 'Must contain an uppercase letter';
                              if (!RegExp(r'[a-z]').hasMatch(v))
                                return 'Must contain a lowercase letter';
                              if (!RegExp(r'[0-9]').hasMatch(v))
                                return 'Must contain a number';
                              if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]')
                                  .hasMatch(v))
                                return 'Must contain a special character';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            decoration: _inputDecoration(
                                    'Confirm Password', Icons.lock_outline)
                                .copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(_isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(() =>
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Please confirm your password';
                              if (v != _passwordController.text)
                                return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Create Account',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Sign in link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account? ',
                                  style:
                                      TextStyle(color: Colors.grey.shade600)),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text('Sign In',
                                    style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue.shade600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
    );
  }
}