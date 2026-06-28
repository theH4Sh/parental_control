import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? errorMessage;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _profilePasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isUpdatingProfile = false;
  bool _isChangingPassword = false;
  bool _obscureProfilePassword = true;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _profilePasswordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await AuthService.instance.getProfile();
      if (!mounted) return;
      setState(() {
        profile = data;
        _usernameController.text = data['username'] as String? ?? '';
        _emailController.text = data['email'] as String? ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_profilePasswordController.text.isEmpty) {
      _showError('Enter your current password to save profile changes');
      return;
    }

    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final currentUsername = profile?['username'] as String? ?? '';
    final currentEmail = profile?['email'] as String? ?? '';

    if (newUsername == currentUsername && newEmail == currentEmail) {
      _showError('Change username or email before saving');
      return;
    }

    setState(() => _isUpdatingProfile = true);
    try {
      final result = await AuthService.instance.updateProfile(
        username: newUsername != currentUsername ? newUsername : null,
        email: newEmail != currentEmail ? newEmail : null,
        currentPassword: _profilePasswordController.text,
      );
      if (!mounted) return;
      _profilePasswordController.clear();
      await _loadProfile();
      _showSuccess(result['message'] as String? ?? 'Profile updated');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUpdatingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showError('Fill in all password fields');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('New passwords do not match');
      return;
    }
    if (_newPasswordController.text.length < 8) {
      _showError('New password must be at least 8 characters');
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final message = await AuthService.instance.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSuccess(message);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFE74C3C)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF2ECC71)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8906)))
          : errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: const Color(0xFFFF8906),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      _sectionTitle('Update Profile'),
                      _buildProfileCard(),
                      const SizedBox(height: 20),
                      _sectionTitle('Change Password'),
                      _buildPasswordCard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage!, style: const TextStyle(color: Color(0xFFE74C3C))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard() {
    final role = profile?['role'] as String? ?? '';
    final isVerified = profile?['isVerified'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0E17),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF8906).withValues(alpha: 0.3), width: 2),
              ),
              child: Center(
                child: Text(
                  (_usernameController.text.isNotEmpty
                          ? _usernameController.text[0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFF8906),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _usernameController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _emailController.text,
                    style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _badge(role == 'parent' ? 'Parent' : 'Child',
                          const Color(0xFFFF8906)),
                      const SizedBox(width: 8),
                      _badge(
                        isVerified ? 'Verified' : 'Unverified',
                        isVerified ? const Color(0xFF2ECC71) : const Color(0xFFE53170),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _profilePasswordController,
              label: 'Current password (required to save)',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureProfilePassword,
              suffix: IconButton(
                icon: Icon(
                  _obscureProfilePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFA7A9BE),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureProfilePassword = !_obscureProfilePassword),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdatingProfile ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8906),
                  foregroundColor: const Color(0xFF0F0E17),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isUpdatingProfile
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0E17)),
                      )
                    : const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field(
              controller: _currentPasswordController,
              label: 'Current password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureCurrent,
              suffix: _toggleVisibility(() => _obscureCurrent, (v) => _obscureCurrent = v),
            ),
            const SizedBox(height: 12),
            _field(
              controller: _newPasswordController,
              label: 'New password',
              icon: Icons.lock_rounded,
              obscure: _obscureNew,
              suffix: _toggleVisibility(() => _obscureNew, (v) => _obscureNew = v),
            ),
            const SizedBox(height: 12),
            _field(
              controller: _confirmPasswordController,
              label: 'Confirm new password',
              icon: Icons.lock_rounded,
              obscure: _obscureConfirm,
              suffix: _toggleVisibility(() => _obscureConfirm, (v) => _obscureConfirm = v),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Use 8+ characters with uppercase, lowercase, number, and symbol.',
                style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isChangingPassword ? null : _changePassword,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE53170),
                  side: const BorderSide(color: Color(0xFFE53170)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isChangingPassword
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53170)),
                      )
                    : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleVisibility(bool Function() getter, void Function(bool) setter) {
    return IconButton(
      icon: Icon(
        getter() ? Icons.visibility_off : Icons.visibility,
        color: const Color(0xFFA7A9BE),
        size: 20,
      ),
      onPressed: () => setState(() => setter(!getter())),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFA7A9BE)),
        prefixIcon: Icon(icon, color: const Color(0xFFA7A9BE), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF0F0E17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
