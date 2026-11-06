import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/gradient_button.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _level;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _name = TextEditingController(text: auth.displayName);
    _level = auth.fitnessLevel;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<AuthProvider>().updateProfile(_name.text, _level);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save your profile')),
      );
    }
  }

  Future<void> _changePhoto() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!SupabaseService.canSync) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Sign in to add a profile picture.'),
      ));
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (auth.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      if (choice == 'remove') {
        await SupabaseService.removeAvatar();
        auth.setAvatarUrl(null);
      } else {
        final file = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (bytes.length > AppConstants.maxAvatarBytes) {
          messenger.showSnackBar(const SnackBar(
            content: Text('That picture is larger than 5 MB.'),
          ));
          return;
        }
        final png = file.name.toLowerCase().endsWith('.png') ||
            file.mimeType == 'image/png';
        auth.setAvatarUrl(await SupabaseService.uploadAvatar(bytes, png: png));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not update your picture. Check your connection.'),
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: 'Change profile picture',
              child: GestureDetector(
                onTap: _uploading ? null : _changePhoto,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const UserAvatar(radius: 44),
                    if (_uploading)
                      const SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: context.cardBg,
                        child: const Icon(Icons.photo_camera_rounded,
                            size: 16, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => Validators.required(v, 'Name'),
                ),
                if (auth.email.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: auth.email,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Fitness level',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final l in AppConstants.fitnessLevels)
                      ButtonSegment(
                        value: l,
                        label: Text(l[0].toUpperCase() + l.substring(1)),
                      ),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) => setState(() => _level = s.first),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: 'Save changes',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
