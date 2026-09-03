import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PostLoginAgeDialog extends StatefulWidget {
  const PostLoginAgeDialog({super.key});

  static Future<int?> show(BuildContext context) async {
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PostLoginAgeDialog(),
    );
  }

  @override
  State<PostLoginAgeDialog> createState() => _PostLoginAgeDialogState();
}

class _PostLoginAgeDialogState extends State<PostLoginAgeDialog> {
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Blocca il back button
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔞', style: TextStyle(fontSize: 50)),
              const SizedBox(height: 16),
              Text(
                'age_verification'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'post_login_age_message'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: CheckboxListTile(
                  value: _isConfirmed,
                  onChanged: (value) {
                    setState(() {
                      _isConfirmed = value ?? false;
                    });
                  },
                  title: Text(
                    'age_confirmation_checkbox'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_isConfirmed ? 1 : 2),
                  child: Text('continue_button'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
