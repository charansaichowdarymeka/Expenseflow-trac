import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class ReceiptPhotoPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChange;
  final AppColors colors;

  const ReceiptPhotoPicker({super.key, required this.value, required this.onChange, required this.colors});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 60);
      if (picked != null) onChange(picked.path);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access ${source == ImageSource.camera ? 'camera' : 'photo library'}: $e')),
      );
    }
  }

  Future<void> _handlePress(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) await _pick(context, source);
  }

  @override
  Widget build(BuildContext context) {
    if (value != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(value!), width: 96, height: 96, fit: BoxFit.cover),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: InkWell(
                  onTap: () => onChange(null),
                  child: Container(
                    decoration: BoxDecoration(color: colors.card, shape: BoxShape.circle),
                    child: Icon(Icons.cancel, size: 22, color: colors.expense),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _handlePress(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 20, color: colors.secondary),
              const SizedBox(width: 8),
              AppText.body('Add receipt photo', style: TextStyle(color: colors.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}
