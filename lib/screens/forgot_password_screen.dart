import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _resetComplete = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.resetPasswordWithCode(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _resetComplete = true);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFA7A9BE), size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: _resetComplete
                    ? _buildCompleteView()
                    : _codeSent
                        ? _buildResetView()
                        : _buildEmailView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailView() {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconCircle(Icons.lock_reset_rounded, const Color(0xFFFF8906)),
          const SizedBox(height: 28),
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Enter your email and we'll send you a 6-digit verification code to reset your password in the app.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFFA7A9BE), height: 1.5),
          ),
          const SizedBox(height: 36),
          _emailField(_emailController),
          const SizedBox(height: 28),
          _primaryButton(
            label: 'Send Verification Code',
            onPressed: _sendCode,
          ),
          const SizedBox(height: 24),
          _backToLoginLink(),
        ],
      ),
    );
  }

  Widget _buildResetView() {
    return Form(
      key: _resetFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconCircle(Icons.pin_rounded, const Color(0xFFFF8906)),
          const SizedBox(height: 28),
          const Text(
            'Enter Verification Code',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We sent a 6-digit code to\n${_emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFFA7A9BE), height: 1.5),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
            ),
            decoration: _inputDecoration(
              hint: '000000',
              icon: Icons.verified_outlined,
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().length != 6) {
                return 'Enter the 6-digit code from your email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              hint: 'New password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFA7A9BE),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
              hint: 'Confirm new password',
              icon: Icons.lock_rounded,
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFA7A9BE),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Use 8+ characters with uppercase, lowercase, number, and symbol.',
              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
          _primaryButton(
            label: 'Reset Password',
            onPressed: _resetPassword,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : _sendCode,
            child: const Text(
              'Resend code',
              style: TextStyle(color: Color(0xFFFF8906)),
            ),
          ),
          _backToLoginLink(),
        ],
      ),
    );
  }

  Widget _buildCompleteView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconCircle(Icons.check_circle_rounded, const Color(0xFF2ECC71)),
        const SizedBox(height: 28),
        const Text(
          'Password Reset!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your password has been updated. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFFA7A9BE), height: 1.5),
        ),
        const SizedBox(height: 32),
        _primaryButton(
          label: 'Back to Login',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _iconCircle(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
      ),
      child: Icon(icon, size: 52, color: color),
    );
  }

  Widget _emailField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Enter your email';
        final emailRegex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
        return null;
      },
      decoration: _inputDecoration(hint: 'Email Address', icon: Icons.email_outlined),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    String counterText = '',
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
      prefixIcon: Icon(icon, color: const Color(0xFFA7A9BE), size: 22),
      suffixIcon: suffix,
      counterText: counterText,
      filled: true,
      fillColor: const Color(0xFF1E1F29),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF8906), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE74C3C), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFE74C3C), fontSize: 12),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF8906),
          foregroundColor: const Color(0xFF0F0E17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F0E17)),
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _backToLoginLink() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_back_rounded,
              size: 16, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(
            'Back to Login',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
