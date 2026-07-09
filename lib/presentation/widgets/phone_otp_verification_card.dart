import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../../services/phone_verification_service.dart';

class PhoneOtpVerificationCard extends StatefulWidget {
  const PhoneOtpVerificationCard({
    super.key,
    required this.phone,
    required this.purpose,
    required this.onVerified,
    this.enabled = true,
    this.service,
  });

  final String phone;
  final String purpose;
  final ValueChanged<String> onVerified;
  final bool enabled;
  final PhoneVerificationService? service;

  @override
  State<PhoneOtpVerificationCard> createState() =>
      _PhoneOtpVerificationCardState();
}

class _PhoneOtpVerificationCardState extends State<PhoneOtpVerificationCard> {
  late final PhoneVerificationService service;
  final codeController = TextEditingController();
  bool codeSent = false;
  bool sending = false;
  bool verifying = false;
  String? verifiedPhone;

  bool get isVerified => verifiedPhone == widget.phone && widget.phone.isNotEmpty;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? PhoneVerificationService();
  }

  @override
  void didUpdateWidget(covariant PhoneOtpVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phone != widget.phone && verifiedPhone != widget.phone) {
      codeController.clear();
      codeSent = false;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (widget.phone.isEmpty || sending || !widget.enabled) return;
    setState(() => sending = true);
    try {
      await service.requestCode(phone: widget.phone, purpose: widget.purpose);
      if (!mounted) return;
      setState(() => codeSent = true);
      _showMessage('Verification code sent to ${widget.phone}.');
    } catch (error) {
      if (mounted) _showMessage('Could not send verification code: $error');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = codeController.text.trim();
    if (code.length != 6 || verifying || !widget.enabled) {
      _showMessage('Enter the 6-digit SMS code.');
      return;
    }
    setState(() => verifying = true);
    try {
      await service.verifyCode(
        phone: widget.phone,
        purpose: widget.purpose,
        code: code,
      );
      if (!mounted) return;
      setState(() => verifiedPhone = widget.phone);
      widget.onVerified(widget.phone);
      _showMessage('Phone number verified.');
    } catch (error) {
      if (mounted) _showMessage('Could not verify code: $error');
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && widget.phone.isNotEmpty && !isVerified;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isVerified
            ? AppColors.primarySoft
            : AppColors.surface.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVerified
              ? AppColors.primary.withValues(alpha: .35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified
                    ? Icons.verified_rounded
                    : Icons.sms_outlined,
                color: isVerified ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVerified ? 'Phone verified' : 'SMS phone verification',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isVerified
                ? 'This phone number can now be saved.'
                : 'Send a 6-digit code to confirm the phone owner agrees to use this number.',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (!isVerified) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canSend ? _requestCode : null,
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(codeSent ? 'Resend code' : 'Send code'),
                  ),
                ),
              ],
            ),
            if (codeSent) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        hintText: '6-digit code',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: verifying ? null : _verifyCode,
                    child: verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
