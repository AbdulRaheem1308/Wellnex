import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';

/// Complete Profile Screen (Single step form)
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController(text: '25');
  final _weightController = TextEditingController(text: '70');
  final _heightController = TextEditingController(text: '170');
  
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
  
  bool _isEmailReadOnly = false;
  
  double _stepGoal = 5000;
  int _selectedAvatarIndex = 0;
  
  // Avatars
  List<dynamic> _avatars = [];
  bool _isLoadingAvatars = false;
  
  // No longer needed
  // final List<Color> _avatarColors = ...
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchAvatars();
  }

  Future<void> _fetchAvatars() async {
    setState(() => _isLoadingAvatars = true);
    try {
      final response = await ref.read(apiServiceProvider).get('/users/avatars');
      setState(() {
        _avatars = response.data;
        // Default to first if available and none selected yet
        if (_avatars.isNotEmpty && _selectedAvatarIndex >= _avatars.length) {
          _selectedAvatarIndex = 0;
        }
      });
    } catch (e) {
      // Fallback
    } finally {
      setState(() => _isLoadingAvatars = false);
    }
  }

  void _loadUser() {
    final user = StorageService.getUser();
    if (user != null) {
      _nameController.text = user['name'] ?? '';
      
      if (user['email'] != null && (user['email'] as String).isNotEmpty) {
        _emailController.text = user['email'];
        _isEmailReadOnly = true;
      }
      
      if (user['phone'] != null && (user['phone'] as String).isNotEmpty) {
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
      final user = StorageService.getUser() ?? {};
      
      final age = int.tryParse(_ageController.text) ?? 25;
      final weight = int.tryParse(_weightController.text) ?? 70;
      final height = int.tryParse(_heightController.text) ?? 170;

      String phoneVal = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
      if (phoneVal.length == 10 && !phoneVal.startsWith('+')) {
        phoneVal = '+91$phoneVal';
      } else if (phoneVal.startsWith('91') && phoneVal.length == 12) {
        phoneVal = '+$phoneVal';
      }

      final data = {
        'name': _nameController.text.trim(),
        'phone': phoneVal,
        'email': _emailController.text.trim(),
        'gender': _gender,
        'heightCm': height,
        'weightKg': weight,
        'age': age,
        'dailyStepGoal': _stepGoal.toInt(),
        'avatarUrl': _avatars.isNotEmpty ? _avatars[_selectedAvatarIndex]['url'] : 'default',
        'isProfileCreated': true,
      };
      
      // Call API
      await ref.read(apiServiceProvider).put('/users/me', data: data);
      
      // Update local
      final currentUser = StorageService.getUser();
      if (currentUser != null) {
        currentUser.addAll(data);
        await StorageService.saveUser(currentUser);
      }
      
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.errorSavingProfile(e.toString()) ?? 'Error saving profile: $e')),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.completeProfileTitle ?? 'Complete Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n?.completeProfileSubtitle ?? "Tell us about yourself to personalize your experience.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.neutral500,
                        ),
                      ).animate().fadeIn(),
                      
                      const SizedBox(height: 32),
                      
                      // 1. Name Input
                      _buildLabel(l10n?.yourName ?? 'Your Name'),
                      Semantics(
                        label: l10n?.yourName ?? 'Your Name',
                        child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: _buildInputDecoration(l10n?.nameHint ?? 'e.g. Alex Step', Icons.person_outline),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l10n?.fieldRequired ?? 'Name is required';
                          }
                          if (v.trim().length < 2) {
                            return l10n?.nameTooShort ?? 'Name must be at least 2 chars';
                          }
                          final nameRegex = RegExp(r"^[a-zA-Z\s\-\']+$");
                          if (!nameRegex.hasMatch(v.trim())) {
                            return 'Please enter a valid name (letters only)';
                          }
                          return null;
                        },
                      )).animate(delay: 100.ms).fadeIn(),
                      
                      const SizedBox(height: 24),
                      
                      // 1.1 Contact Info
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(l10n?.emailLabel ?? 'Email'),
                                Semantics(
                                  label: l10n?.emailLabel ?? 'Email',
                                  child: TextFormField(
                                  controller: _emailController,
                                  readOnly: _isEmailReadOnly,
                                  style: TextStyle(color: _isEmailReadOnly ? AppTheme.neutral500 : Theme.of(context).textTheme.bodyLarge?.color),
                                  decoration: _buildInputDecoration(l10n?.emailHint ?? 'email@example.com', Icons.email_outlined, isReadOnly: _isEmailReadOnly),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return l10n?.fieldRequired ?? 'Email is required';
                                    }
                                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(v.trim())) {
                                      return l10n?.invalidEmail ?? 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                )),
                              ],
                            ),
                          ),
                        ],
                      ).animate(delay: 150.ms).fadeIn(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(l10n?.phoneLabel ?? 'Phone'),
                                Semantics(
                                  label: l10n?.phoneLabel ?? 'Phone',
                                  child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                                  decoration: _buildInputDecoration('+91 98765 43210', Icons.phone_outlined),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return l10n?.fieldRequired ?? 'Phone number is required';
                                    final phoneStr = v.replaceAll(RegExp(r'\s+'), '');
                                    final phoneRegex = RegExp(r'^(?:\+91|91)?[6-9]\d{9}$');
                                    if (!phoneRegex.hasMatch(phoneStr)) {
                                      return 'Please enter a valid Indian mobile number';
                                    }
                                    return null;
                                  },
                                )),
                              ],
                            ),
                          ),
                        ],
                      ).animate(delay: 150.ms).fadeIn(),

                      const SizedBox(height: 24),

                      // 2. Personal & Physical Stats
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Gender'),
                                DropdownButtonFormField<String>(
                                  value: _gender,
                                  decoration: _buildInputDecoration('Gender', null),
                                  items: ['Male', 'Female', 'Other'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      setState(() => _gender = newValue);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(l10n?.ageLabel ?? 'Age'),
                                Semantics(
                                  label: l10n?.ageLabel ?? 'Age',
                                  child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration('25', null),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return l10n?.fieldRequired ?? 'Required';
                                    final age = int.tryParse(v.trim());
                                    if (age == null) return 'Must be a number';
                                    if (age < 10 || age > 120) return 'Invalid age (10-120)';
                                    return null;
                                  },
                                )),
                              ],
                            ),
                          ),
                        ],
                      ).animate(delay: 200.ms).fadeIn(),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(l10n?.weightLabel ?? 'Weight (kg)'),
                                Semantics(
                                  label: l10n?.weightLabel ?? 'Weight (kg)',
                                  child: TextFormField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration('70', null),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return l10n?.fieldRequired ?? 'Required';
                                    final weight = double.tryParse(v.trim());
                                    if (weight == null) return 'Must be a number';
                                    if (weight < 20 || weight > 300) return 'Invalid weight (20-300 kg)';
                                    return null;
                                  },
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(l10n?.heightLabel ?? 'Height (cm)'),
                                Semantics(
                                  label: l10n?.heightLabel ?? 'Height (cm)',
                                  child: TextFormField(
                                  controller: _heightController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration('170', null),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return l10n?.fieldRequired ?? 'Required';
                                    final height = double.tryParse(v.trim());
                                    if (height == null) return 'Must be a number';
                                    if (height < 50 || height > 250) return 'Invalid height (50-250 cm)';
                                    return null;
                                  },
                                )),
                              ],
                            ),
                          ),
                        ],
                      ).animate(delay: 250.ms).fadeIn(),
                      
                      const SizedBox(height: 16),
                      
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
                              Text('BMI: ${_bmi.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        ).animate().fadeIn(),

                      const SizedBox(height: 24),
                      
                      // 3. Avatar Carousel
                      _buildLabel(l10n?.chooseAvatar ?? 'Choose Avatar'),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _avatars.isEmpty ? 5 : _avatars.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            if (_isLoadingAvatars) {
                              return Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                              ).animate(onPlay: (c) => c.repeat()).shimmer();
                            }
                            
                            if (_avatars.isEmpty) {
                              // Fallback placeholders
                              return Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withAlpha(51),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person, color: Colors.grey),
                              );
                            }
                            
                            final isSelected = _selectedAvatarIndex == index;
                            final avatarUrl = _avatars[index]['url'];
                            
                            return Semantics(
                              label: 'Avatar Option ${index + 1}',
                              selected: isSelected,
                              onTapHint: 'Select this avatar',
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedAvatarIndex = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.elasticOut,
                                  width: isSelected ? 70 : 50,
                                  height: isSelected ? 70 : 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                                      width: 3,
                                    ),
                                    color: Colors.white,
                                    boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryGreen.withAlpha(102), blurRadius: 8)] : null,
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(imageUrl: 
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => const Icon(Icons.person, size: 40, color: AppTheme.neutral400),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ).animate(delay: 300.ms).fadeIn(),
                      
                      const SizedBox(height: 24),
                      
                      // 4. Goal Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel(l10n?.dailyStepGoal ?? 'Daily Step Goal'),
                          Text(
                            l10n?.stepsCount(_stepGoal.toInt()) ?? '${_stepGoal.toInt()} steps',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      
                      Semantics(
                        label: 'Daily Step Goal Slider',
                        value: '${_stepGoal.toInt()} steps',
                        child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.primaryGreen,
                          inactiveTrackColor: AppTheme.neutral200,
                          thumbColor: AppTheme.primaryGreen,
                          overlayColor: AppTheme.primaryGreen.withAlpha(51),
                          trackHeight: 6,
                        ),
                        child: Slider(
                          value: _stepGoal,
                          min: 2000,
                          max: 20000,
                          divisions: 18,
                          onChanged: (value) => setState(() => _stepGoal = value),
                        ),
                      ),
                      ).animate(delay: 400.ms).fadeIn(),
                    ],
                  ),
                ),
              ),
              
              // Bottom Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            l10n?.completeSetupButton ?? "Complete Setup",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 1, end: 0),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text, 
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData? icon, {bool isReadOnly = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalBorderColor = isDark ? AppTheme.neutral700 : AppTheme.neutral200;
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      filled: true,
      fillColor: isReadOnly
          ? (isDark ? AppTheme.neutral900 : AppTheme.neutral100)
          : (isDark ? AppTheme.neutral800 : AppTheme.neutral50),
      // Normal border
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: normalBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: normalBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
      ),
      // Error borders — these make validation errors visible
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 2),
      ),
      errorStyle: const TextStyle(
        color: AppTheme.error,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
