import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Edit Profile Screen
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  
  String _gender = 'Male';
  
  double get _bmi {
    final w = double.tryParse(_weightController.text) ?? 0;
    final hCm = double.tryParse(_heightController.text) ?? 0;
    if (w <= 0 || hCm <= 0) return 0;
    final hM = hCm / 100;
    return w / (hM * hM);
  }

  String get _bmiCategory {
    final bmi = _bmi;
    if (bmi == 0) return '';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
  
  double _stepGoal = 5000;
  int _selectedAvatarIndex = 0;
  
  // Avatars
  List<dynamic> _avatars = [];
  bool _isLoadingAvatars = false;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();

    _loadUser();
    _fetchAvatars();
  }

  Future<void> _fetchAvatars() async {
    setState(() => _isLoadingAvatars = true);
    try {
      final response = await ref.read(apiServiceProvider).get('/users/avatars');
      if (mounted) {
        setState(() {
          _avatars = response.data;
          _matchAvatarSelection();
        });
      }
    } catch (e) {
      // Fallback or silence
    } finally {
      if (mounted) {
        setState(() => _isLoadingAvatars = false);
      }
    }
  }

  void _loadUser() {
    final user = StorageService.getUser();
    if (user != null) {
      _nameController.text = user['name'] ?? '';
      
      if (user['email'] != null) {
        _emailController.text = user['email'];
      }
      
      if (user['phone'] != null) {
        _phoneController.text = user['phone'];
      }
      
      if (user['dailyStepGoal'] != null) {
        _stepGoal = (user['dailyStepGoal'] as num).toDouble();
      }
      if (user['age'] != null) _ageController.text = user['age'].toString();
      if (user['weightKg'] != null) _weightController.text = user['weightKg'].toString();
      if (user['heightCm'] != null) _heightController.text = user['heightCm'].toString();
      if (user['gender'] != null) _gender = user['gender'] as String;
    }
  }

  void _matchAvatarSelection() {
    final user = StorageService.getUser();
    final currentAvatarUrl = user?['avatarUrl'];
    
    if (currentAvatarUrl != null && _avatars.isNotEmpty) {
      final index = _avatars.indexWhere((a) => a['url'] == currentAvatarUrl);
      if (index != -1) {
        _selectedAvatarIndex = index;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final age = int.tryParse(_ageController.text) ?? 25;
      final weight = int.tryParse(_weightController.text) ?? 70;
      final height = int.tryParse(_heightController.text) ?? 170;

      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'gender': _gender,
        'heightCm': height,
        'weightKg': weight,
        'age': age,
        'dailyStepGoal': _stepGoal.toInt(),
        'avatarUrl': _avatars.isNotEmpty ? _avatars[_selectedAvatarIndex]['url'] : 'default',
      };
      
      // Update via Provider (calls API and updates storage)
      await ref.read(authProvider.notifier).updateProfile(data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop(); // Return to Profile Screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: ${e.toString()}')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Avatar Selection
                Semantics(
                  header: true,
                  label: 'Choose an Avatar',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_avatars.length, (index) {
                        final avatar = _avatars[index];
                        final isSelected = index == _selectedAvatarIndex;
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label: 'Avatar ${index + 1}',
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedAvatarIndex = index),
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                backgroundImage: NetworkImage(avatar['url']),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Name
                _buildTextField(
                  context: context,
                  label: 'Full Name',
                  controller: _nameController,
                  icon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    if (v.trim().length < 2) return 'Name must be at least 2 chars';
                    if (!RegExp(r"^[a-zA-Z\s\-\']+$").hasMatch(v.trim())) return 'Please enter a valid name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email
                _buildTextField(
                  context: context,
                  label: 'Email',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Please enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Phone
                _buildTextField(
                  context: context,
                  label: 'Phone',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone is required';
                    final phoneStr = v.replaceAll(RegExp(r'\s+'), '');
                    if (!RegExp(r'^(?:\+91|91)?[6-9]\d{9}$').hasMatch(phoneStr)) return 'Please enter a valid Indian mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Gender
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                    prefixIcon: Icon(Icons.people_outline, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  items: ['Male', 'Female', 'Other'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() => _gender = newValue);
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Age
                _buildTextField(
                  context: context,
                  label: 'Age',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  icon: Icons.cake_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Age is required';
                    final age = int.tryParse(v.trim());
                    if (age == null || age < 10 || age > 120) return 'Invalid age (10-120)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Weight
                _buildTextField(
                  context: context,
                  label: 'Weight (kg)',
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  icon: Icons.monitor_weight_outlined,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Weight is required';
                    final w = double.tryParse(v.trim());
                    if (w == null || w < 20 || w > 300) return 'Invalid weight (20-300 kg)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Height
                _buildTextField(
                  context: context,
                  label: 'Height (cm)',
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  icon: Icons.height,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Height is required';
                    final h = double.tryParse(v.trim());
                    if (h == null || h < 50 || h > 250) return 'Invalid height (50-250 cm)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // BMI Display
                if (_bmi > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryGreen.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('BMI: ${_bmi.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_bmiCategory, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                
                // Step Goal
                Semantics(
                  label: 'Daily step goal is ${_stepGoal.toInt()}',
                  child: Text(
                    'Daily Step Goal: ${_stepGoal.toInt()}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ),
                Semantics(
                  slider: true,
                  value: '${_stepGoal.toInt()} steps',
                  child: Slider(
                    value: _stepGoal,
                    min: 1000,
                    max: 20000,
                    divisions: 19,
                    activeColor: AppTheme.primaryGreen,
                    inactiveColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    label: _stepGoal.round().toString(),
                    onChanged: (val) => setState(() => _stepGoal = val),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Save Button
                Semantics(
                  button: true,
                  label: 'Save Profile Changes',
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        filled: true,
        fillColor: readOnly 
            ? Theme.of(context).dividerColor.withValues(alpha: 0.1) 
            : Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
