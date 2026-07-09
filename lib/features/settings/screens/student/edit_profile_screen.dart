// lib/features/settings/screens/student/edit_profile_screen.dart
//
// Uses the global theme configured in main.dart (SHTheme) rather than
// hardcoded colors, so it automatically matches buttons/inputs/cards
// elsewhere in the app.
//
// Requires the `image_picker` package (add to pubspec.yaml if not present):
//   image_picker: ^1.0.0

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/api_service.dart';
import '../../../../models/user.dart';
import '../../repositories/settings_repository.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SettingsRepository();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;

  // Bytes + filename instead of dart:io File — works on web, mobile, desktop.
  Uint8List? _pickedImageBytes;
  String? _existingPictureUrl;
  bool _saving = false;
  bool _uploadingPicture = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.user.firstName);
    _lastNameCtrl = TextEditingController(text: widget.user.lastName);
    _existingPictureUrl = widget.user.profilePictureUrl;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  String _fullPictureUrl(String relativeUrl) {
    final origin = Uri.parse(ApiService.baseUrl).origin;
    return '$origin$relativeUrl';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _pickedImageBytes = bytes;
      _uploadingPicture = true;
    });

    try {
      final url = await _repo.uploadProfilePicture(bytes, picked.name);
      setState(() => _existingPictureUrl = url);
      if (mounted) {
        _showSnack('Profile picture updated', isError: false);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to upload picture', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPicture = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _repo.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
      );
      if (mounted) {
        _showSnack('Profile updated successfully', isError: false);
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB00020) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Priority: freshly picked local bytes > existing server picture > initials.
    ImageProvider? avatarImage;
    if (_pickedImageBytes != null) {
      avatarImage = MemoryImage(_pickedImageBytes!);
    } else if (_existingPictureUrl != null && _existingPictureUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_fullPictureUrl(_existingPictureUrl!));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile · 编辑资料')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              widget.user.initials,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: cs.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploadingPicture ? null : _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2),
                          ),
                          child: _uploadingPicture
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_rounded,
                                  size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _firstNameCtrl,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'First name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameCtrl,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes · 保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}