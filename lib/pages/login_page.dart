import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/system_ui_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _authService = AuthService();
  
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  
  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
    _usernameFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await _authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        // Navigation will be handled by auth state listener in main.dart
      } else {
        // Sign up flow - signUp method handles Auth, Firestore, and success check in order
        await _authService.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          username: _usernameController.text.trim().isEmpty
              ? null
              : _usernameController.text.trim(),
        );
        
        // Navigation will be handled automatically by StreamBuilder in main.dart
        // The auth state change is triggered by createUserWithEmailAndPassword
        // and the Firestore document is created before signUp returns
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set immersive status bar for light background
    SystemUIService.setLightStatusBar();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // App logo - single visual focus
                  Center(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 48),
                    // Username field (only in register mode)
                    if (!_isLoginMode) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _usernameFocusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: TextFormField(
                          controller: _usernameController,
                          focusNode: _usernameFocusNode,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Color(0xFF1A1A1A)),
                          decoration: InputDecoration(
                          labelText: 'Username (Optional)',
                          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                          hintText: 'Leave empty for auto-generated username',
                          hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Email field
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _emailFocusNode.hasFocus
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                        hintText: 'Enter your email',
                        hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password field
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _passwordFocusNode.hasFocus
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleAuth(),
                        style: const TextStyle(color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                        hintText: 'Enter your password',
                        hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (!_isLoginMode && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Submit button - lighter and calmer
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleAuth,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2D2D2D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isLoginMode ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                    ),
                    const SizedBox(height: 24),
                    // Toggle between login and register
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isLoginMode = !_isLoginMode;
                                _formKey.currentState?.reset();
                                _usernameController.clear();
                              });
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: _isLoginMode
                                  ? "Don't have an account? "
                                  : 'Already have an account? ',
                            ),
                            TextSpan(
                              text: _isLoginMode ? 'Sign Up' : 'Sign In',
                              style: TextStyle(
                                color: const Color(0xFF4285F4).withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationThickness: 1.5,
                                decorationColor: const Color(0xFF4285F4).withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}
