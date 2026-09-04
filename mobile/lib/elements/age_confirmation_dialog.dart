import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AgeConfirmationDialog extends StatefulWidget {
  const AgeConfirmationDialog({super.key});

  static Future<int> show(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => const AgeConfirmationDialog(),
    );

    // 2 = utente non ha dichiarato di essere maggiorenne
    return result ?? 2;
  }

  @override
  State<AgeConfirmationDialog> createState() => _AgeConfirmationDialogState();
}

class _AgeConfirmationDialogState extends State<AgeConfirmationDialog> {
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 20,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔞',
              style: TextStyle(fontSize: 50),
            ),
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
              'age_confirmation_message'.tr(),
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
              child: Row(
                children: [
                  Checkbox(
                    value: _isConfirmed,
                    onChanged: (value) {
                      setState(() {
                        _isConfirmed = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'age_confirmation_checkbox'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    // 2 = dichiara/non conferma maggiorenne
                    onPressed: () => Navigator.of(context).pop(0),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // checked => 1, unchecked => 2
                    onPressed: () =>
                        Navigator.of(context).pop(_isConfirmed ? 1 : 2),
                    child: Text('continue_button'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
