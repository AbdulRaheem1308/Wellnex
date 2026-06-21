import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';

/// OTP Verification Screen
class OtpScreen extends ConsumerStatefulWidget {
  final String? phone;
  final String? email;

  const OtpScreen({
    super.key,
    this.phone,
    this.email,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otp {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length != 6) {
      final l10n = AppLocalizations.of(context);
      _showError(l10n?.enterCompleteOtp ?? 'Please enter the complete OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isNewUser = await ref.read(authProvider.notifier).verifyOtp(
        phone: widget.phone,
        email: widget.email,
        otp: otp,
      );
      
      if (mounted) {
        if (isNewUser) {
          context.go(AppRoutes.completeProfile);
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      _showError(e.toString());
      // Clear OTP fields
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendTimer > 0) return;

    try {
      await ref.read(authProvider.notifier).sendOtp(
        phone: widget.phone,
        email: widget.email,
      );
      
      final l10n = AppLocalizations.of(context);
      _showSuccess(l10n?.otpSentSuccess ?? 'OTP sent successfully');
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    
    // Auto-verify when all digits entered
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final identifier = (widget.phone ?? widget.email ?? '').trim();
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Title
              Text(
                AppLocalizations.of(context)?.verifyOtpTitle ?? 'Verify OTP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                AppLocalizations.of(context)?.enterOtpSentTo(identifier) ?? 'Enter the 6-digit code sent to\n$identifier',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.neutral600,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // OTP Input Fields
              // OTP Input Fields
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildOtpField(index)
                  )),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppLocalizations.of(context)?.verifyButton ?? 'Verify'),
              ),
              
              const SizedBox(height: 24),
              
              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)?.didNotReceiveCode ?? "Didn't receive the code? ",
                    style: TextStyle(color: AppTheme.neutral600),
                  ),
                  TextButton(
                    onPressed: _resendTimer > 0 ? null : _resendOtp,
                    child: Text(
                      _resendTimer > 0 
                          ? (AppLocalizations.of(context)?.resendInSeconds(_resendTimer) ?? 'Resend in ${_resendTimer}s')
                          : (AppLocalizations.of(context)?.resendButton ?? 'Resend'),
                    ),
                  ),
                ],
              ),
              

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return Semantics(
      label: 'OTP digit ${index + 1}',
      child: SizedBox(
        width: 48,
        height: 56,
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) => _onKeyPressed(index, event),
          child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: AppTheme.neutral100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryGreen,
                width: 2,
              ),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) => _onOtpChanged(index, value),
        ),
      ),
    ),
    );
  }
}
