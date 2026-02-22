// lib/screens/user/user_profile_screen.dart

// ignore_for_file: deprecated_member_use, avoid_print, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/theme_service.dart';
import '../../services/language_service.dart';
import '../../services/session_manager.dart';
import '../../services/member_service.dart';
import '../../services/photo_service.dart';
import '../../services/auth_service.dart';
import '../../models/member_model.dart';
import '../../auth/login_screen.dart';

// Helper widget to handle profile images with error handling
class ProfileImage extends StatefulWidget {
  final String? photoUrl;
  final String fullName;
  final double radius;

  const ProfileImage({
    super.key,
    this.photoUrl,
    required this.fullName,
    this.radius = 60,
  });

  @override
  State<ProfileImage> createState() => _ProfileImageState();
}

class _ProfileImageState extends State<ProfileImage> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.photoUrl ?? '';
    final hasValidUrl = photoUrl.isNotEmpty && photoUrl.startsWith('http');

    if (!hasValidUrl || _hasError) {
      // Show initials when no valid URL or error occurred
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.blue.shade900,
        child: Text(
          widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
          style: TextStyle(fontSize: widget.radius * 0.6, color: Colors.white),
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.blue.shade900,
      backgroundImage: CachedNetworkImageProvider(photoUrl),
      onBackgroundImageError: (_, __) {
        if (mounted) {
          setState(() => _hasError = true);
        }
      },
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ThemeService _themeService = ThemeService();
  final LanguageService _languageService = LanguageService();
  final MemberService _memberService = MemberService();
  final PhotoService _photoService = PhotoService();

  MemberModel? _currentUser;
  bool _loading = true;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _themeService.initialize();
    _languageService.initialize();
  }

  Future<void> _loadUserData() async {
    final memberDocId = await SessionManager.getMemberDocId();
    final mainFamilyDocId = await SessionManager.getFamilyDocId();
    final subFamilyDocId = await SessionManager.getSubFamilyDocId();

    if (memberDocId != null && mainFamilyDocId != null) {
      final member = await _memberService.getMember(
        mainFamilyDocId: mainFamilyDocId,
        subFamilyDocId: subFamilyDocId ?? '',
        memberId: memberDocId,
      );

      // Debug: Log photo URL
      if (member != null) {
        print('UserProfileScreen - Member: ${member.fullName}');
        print('UserProfileScreen - Photo URL: ${member.photoUrl}');
        print(
          'UserProfileScreen - Photo URL isEmpty: ${member.photoUrl.isEmpty}',
        );
        print(
          'UserProfileScreen - Photo URL startsWith http: ${member.photoUrl.startsWith('http')}',
        );
      }

      setState(() {
        _currentUser = member;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Profile Photo
                  Center(
                    child: Stack(
                      children: [
                        ProfileImage(
                          photoUrl: _currentUser?.photoUrl,
                          fullName: _currentUser?.fullName ?? 'Guest',
                          radius: 60,
                        ),
                        if (_uploadingPhoto)
                          const Positioned(
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.black45,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue.shade900,
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                              onPressed:
                                  _currentUser != null && !_uploadingPhoto
                                  ? _changePhoto
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // User Name
                  Text(
                    _currentUser?.fullName ?? 'Guest',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentUser?.mid != null)
                    Text(
                      _currentUser!.mid,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Family Details
                  if (_currentUser != null)
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Family Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow('Family', _currentUser!.familyName),
                            _buildDetailRow('Phone', _currentUser!.phone),
                            _buildDetailRow('Address', _currentUser!.address),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Settings
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Theme Toggle
                        ListTile(
                          leading: Icon(
                            _themeService.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                          ),
                          title: Text(
                            _themeService.isDarkMode
                                ? 'Dark Mode'
                                : 'Light Mode',
                          ),
                          trailing: Switch(
                            value: _themeService.isDarkMode,
                            onChanged: (_) => _themeService.toggleTheme(),
                          ),
                        ),
                        const Divider(),

                        // Language Toggle
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: const Text('Language'),
                          subtitle: Text(
                            _languageService.locale.languageCode == 'gu'
                                ? 'Gujarati'
                                : 'English',
                          ),
                          onTap: _showLanguageDialog,
                        ),
                        const Divider(),

                        // Settings Options
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Notifications'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip),
                          title: const Text('Privacy'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.help),
                          title: const Text('Help & Support'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.info),
                          title: const Text('About'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'en',
                groupValue: _languageService.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    _languageService.setLocale(value);
                    Navigator.pop(context);
                  }
                },
              ),
              title: const Text('English'),
            ),
            ListTile(
              leading: Radio<String>(
                value: 'gu',
                groupValue: _languageService.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    _languageService.setLocale(value);
                    Navigator.pop(context);
                  }
                },
              ),
              title: const Text('Gujarati'),
            ),
          ],
        ),
      ),
    );
  }

  void _changePhoto() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _uploadFromCamera();
                  },
                  icon: const Icon(Icons.camera),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _uploadFromGallery();
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            if (_currentUser?.photoUrl.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
                child: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFromCamera() async {
    if (_currentUser == null) return;

    try {
      setState(() => _uploadingPhoto = true);

      final image = await _photoService.pickFromCamera();
      if (image != null) {
        final photoUrl = await _photoService.uploadProfilePhoto(
          memberId: _currentUser!.id,
          image: image,
        );

        if (photoUrl != null) {
          await _memberService.updateMember(
            mainFamilyDocId: _currentUser!.familyDocId,
            subFamilyDocId: _currentUser!.subFamilyDocId,
            memberId: _currentUser!.id,
            updates: {'photoUrl': photoUrl},
          );

          // Refresh user data
          final updatedMember = await _memberService.getMember(
            mainFamilyDocId: _currentUser!.familyDocId,
            subFamilyDocId: _currentUser!.subFamilyDocId,
            memberId: _currentUser!.id,
          );
          setState(() {
            _currentUser = updatedMember;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    if (_currentUser == null) return;

    try {
      setState(() => _uploadingPhoto = true);

      final image = await _photoService.pickImage();
      if (image != null) {
        final photoUrl = await _photoService.uploadProfilePhoto(
          memberId: _currentUser!.id,
          image: image,
        );

        if (photoUrl != null) {
          await _memberService.updateMember(
            mainFamilyDocId: _currentUser!.familyDocId,
            subFamilyDocId: _currentUser!.subFamilyDocId,
            memberId: _currentUser!.id,
            updates: {'photoUrl': photoUrl},
          );

          // Refresh user data
          final updatedMember = await _memberService.getMember(
            mainFamilyDocId: _currentUser!.familyDocId,
            subFamilyDocId: _currentUser!.subFamilyDocId,
            memberId: _currentUser!.id,
          );
          setState(() {
            _currentUser = updatedMember;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _removePhoto() async {
    if (_currentUser == null || _currentUser!.photoUrl.isEmpty) return;

    try {
      setState(() => _uploadingPhoto = true);

      // Delete from Firebase Storage
      await _photoService.deleteProfilePhoto(_currentUser!.photoUrl);

      // Update member to remove photo URL
      await _memberService.updateMember(
        mainFamilyDocId: _currentUser!.familyDocId,
        subFamilyDocId: _currentUser!.subFamilyDocId,
        memberId: _currentUser!.id,
        updates: {'photoUrl': ''},
      );

      // Refresh user data
      final updatedMember = await _memberService.getMember(
        mainFamilyDocId: _currentUser!.familyDocId,
        subFamilyDocId: _currentUser!.subFamilyDocId,
        memberId: _currentUser!.id,
      );
      setState(() {
        _currentUser = updatedMember;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing photo: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Clear the session using AuthService
        await AuthService().logout();

        if (mounted) {
          // Navigate to login screen and remove all previous routes
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
