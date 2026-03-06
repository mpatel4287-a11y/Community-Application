// ignore_for_file: prefer_final_fields, deprecated_member_use, use_build_context_synchronously, avoid_print, depend_on_referenced_packages, unused_element, unused_field

import 'dart:io';


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/member_model.dart';
import '../../services/imagekit_config.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/member_service.dart';
import '../../services/photo_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/animation_utils.dart';
import '../user/member_detail_screen.dart';

// Placeholder for AddMemberScreen
class AddMemberScreen extends StatefulWidget {
  final String familyDocId;
  final String familyName;
  final String? subFamilyDocId; // NEW: Optional sub-family ID
  final String? initialParentMid;

  const AddMemberScreen({
    super.key,
    required this.familyDocId,
    required this.familyName,
    this.subFamilyDocId,
    this.initialParentMid,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
    bool obscureText = false,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      enabled: enabled,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryColor) : null,
        filled: true,
        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade700, 
          fontWeight: FontWeight.w400
        ),
        floatingLabelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, 
            width: 1
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _gotraCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _educationCtrl = TextEditingController(); // Added
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // Added
  final _addressCtrl = TextEditingController();
  final _googleMapLinkCtrl = TextEditingController();
  final _surdhanCtrl = TextEditingController(); // Added
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _nativeHomeCtrl = TextEditingController();
  final _parentMidCtrl = TextEditingController();
  final _dktFamilyIdCtrl = TextEditingController();
  String? _profilePhotoUrl;
  String? _pendingPhotoPath; // Store for upload after member creation
  String? _pendingPhotoId;
  final ImagePicker _imagePicker = ImagePicker();
  final PhotoService _photoService = PhotoService();

  String _gender = 'male'; // Added
  String _bloodGroup = '';
  String _marriageStatus = 'unmarried';
  String _relationToHead = 'none';
  String _subFamilyHeadRelation = '';
  bool _hasFamilyHead = false;
  List<String> _tags = [];
  List<Map<String, String>> _firms = [];
  List<String> _allFirmNames = [];
  bool _loading = false;
  String? _selectedSpouseMid;
  String _spouseRelation = 'none';
  List<MemberModel> _familyMembers = [];
  String _currentUserRole = 'member';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    if (widget.initialParentMid != null) {
      _parentMidCtrl.text = widget.initialParentMid!;
    }
    _checkExistingHead();
    _loadFirmNames();
    _loadFamilyMembers();
  }

  Future<void> _loadUserRole() async {
    final role = await SessionManager.getRole();
    if (mounted) {
      setState(() => _currentUserRole = role ?? 'member');
    }
  }

  Future<void> _loadFamilyMembers() async {
    // Fetch members from the current sub-family as requested by user
    final members = await MemberService().getSubFamilyMembers(
      widget.familyDocId,
      widget.subFamilyDocId ?? '',
    );
    if (mounted) {
      setState(() {
        _familyMembers = members;
      });
    }
  }

  Future<void> _loadFirmNames() async {
    final names = await MemberService().getAllFirmNames();
    if (mounted) {
      setState(() => _allFirmNames = names);
    }
  }

  Future<void> _checkExistingHead() async {
    final hasHead = await MemberService().hasSubFamilyHead(
      widget.familyDocId,
      widget.subFamilyDocId ?? '',
    );
    if (mounted) {
      setState(() => _hasFamilyHead = hasHead);
    }
  }

  Future<void> _launchWhatsApp() async {
    final url = 'https://wa.me/${_whatsappCtrl.text.trim()}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchInstagram() async {
    final username = _instagramCtrl.text.trim();
    final url = username.startsWith('https://')
        ? username
        : 'https://instagram.com/$username';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchFacebook() async {
    final username = _facebookCtrl.text.trim();
    final url = username.startsWith('https://')
        ? username
        : 'https://facebook.com/$username';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchMap(String mapUrl) async {
    if (mapUrl.isNotEmpty && await canLaunchUrl(Uri.parse(mapUrl))) {
      await launchUrl(Uri.parse(mapUrl));
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: ImageKitConfig.maxImageWidth.toDouble(),
        maxHeight: ImageKitConfig.maxImageHeight.toDouble(),
        imageQuality: ImageKitConfig.imageQuality,
      );

      if (image != null) {
        // Store the photo path locally for preview and later upload
        setState(() {
          _pendingPhotoPath = image.path;
          _profilePhotoUrl = image.path; // Preview local image
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Get family data for familyId
      final familyDoc = await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyDocId)
          .get();
      final familyData = familyDoc.data() as Map<String, dynamic>;
      final familyId = familyData['familyId'].toString();

      // Get subFamilyId if subFamilyDocId is provided
      String subFamilyId = '';
      if (widget.subFamilyDocId != null) {
        final subFamilyDoc = await FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyDocId)
            .collection('subfamilies')
            .doc(widget.subFamilyDocId)
            .get();
        subFamilyId = subFamilyDoc.data()?['subFamilyId']?.toString() ?? '';
      }

      // Upload photo first if there's a pending photo
      String photoUrl = '';
      if (_pendingPhotoPath != null && _pendingPhotoPath!.isNotEmpty) {
        try {
          final photoFile = XFile(_pendingPhotoPath!);
          // Generate a temporary member ID for the photo naming
          final tempMemberId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
          final uploadedUrl = await _photoService.uploadProfilePhoto(
            memberId: tempMemberId,
            image: photoFile,
          );
          if (uploadedUrl != null && uploadedUrl.startsWith('http')) {
            photoUrl = uploadedUrl;
          } else {
             // Show error if upload fails
             throw Exception('Failed to get valid photo URL from ImageKit');
          }
        } catch (e) {
          print('Error uploading photo: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo upload failed: $e. Member will be added without photo.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Continue without photo on error, do NOT save local path
          photoUrl = '';
        }
      }

      final newMemberId = await MemberService().addMemberWithId(
        mainFamilyDocId: widget.familyDocId,
        subFamilyDocId: widget.subFamilyDocId ?? '',
        subFamilyId: subFamilyId,
        familyId: _dktFamilyIdCtrl.text.trim().isEmpty
            ? familyId
            : _dktFamilyIdCtrl.text.trim(),
        familyName: widget.familyName,
        fullName: _fullNameCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        fatherName: _fatherNameCtrl.text.trim(),
        motherName: _motherNameCtrl.text.trim(),
        gotra: _gotraCtrl.text.trim(),
        gender: _gender,
        birthDate: _birthDateCtrl.text.trim(),
        education: _educationCtrl.text.trim(),
        bloodGroup: _bloodGroup,
        marriageStatus: _marriageStatus,
        nativeHome: _nativeHomeCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        googleMapLink: _googleMapLinkCtrl.text.trim(),
        surdhan: _surdhanCtrl.text.trim(),
        firms: _firms,
        whatsapp: _whatsappCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim(),
        facebook: _facebookCtrl.text.trim(),
        tags: _tags,
        parentMid: _parentMidCtrl.text.trim(),
        password: _passwordCtrl.text.trim().isEmpty ? '123456' : _passwordCtrl.text.trim(),
        photoUrl: photoUrl,
        relationToHead: _relationToHead,
        subFamilyHeadRelationToMainHead: _subFamilyHeadRelation,
        spouseMid: _selectedSpouseMid ?? '',
      );

      // If a spouse was selected, link them
      if (_selectedSpouseMid != null && _selectedSpouseMid!.isNotEmpty) {
        final spouseMember = _familyMembers.firstWhere((m) => m.mid == _selectedSpouseMid);
        await MemberService().updateSpouseLink(
          mainFamilyDocId: widget.familyDocId,
          member1Id: newMemberId,
          member1SubFamilyDocId: widget.subFamilyDocId ?? '',
          member2Id: spouseMember.id,
          member2SubFamilyDocId: spouseMember.subFamilyDocId,
          relation: _spouseRelation,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(lang.translate('add_member')),
            backgroundColor: Colors.blue.shade900,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo
                  _buildSectionHeader(lang.translate('profile_photo'), Icons.camera_alt),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickProfilePhoto,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                backgroundImage: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                                    ? (_profilePhotoUrl!.startsWith('http')
                                        ? CachedNetworkImageProvider(_profilePhotoUrl!) as ImageProvider
                                        : FileImage(File(_profilePhotoUrl!)))
                                    : null,
                                child: _profilePhotoUrl == null || _profilePhotoUrl!.isEmpty
                                    ? Icon(Icons.add_a_photo, size: 40, color: Theme.of(context).colorScheme.primary)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              lang.translate('tap_to_add_photo'),
                              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Personal Information
                  _buildSectionHeader(lang.translate('personal_information'), Icons.person),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(_fullNameCtrl, '${lang.translate('full_name')} *',
                              validator: (v) => v == null || v.isEmpty ? lang.translate('required') : null),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_surnameCtrl, lang.translate('surname'))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTextField(_gotraCtrl, lang.translate('gotra'))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(_fatherNameCtrl, lang.translate('father_name')),
                          const SizedBox(height: 12),
                          _buildTextField(_motherNameCtrl, lang.translate('mother_name')),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _gender,
                                  decoration: InputDecoration(
                                    labelText: lang.translate('gender'),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                  ),
                                  items: ['male', 'female']
                                      .map((g) => DropdownMenuItem(value: g, child: Text(lang.translate(g))))
                                      .toList(),
                                  onChanged: (v) => setState(() => _gender = v ?? 'male'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(_birthDateCtrl, 'Birth Date (dd/MM/yyyy) *',
                                    hint: '15/08/1990',
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _bloodGroup.isEmpty ? null : _bloodGroup,
                                  decoration: InputDecoration(
                                    labelText: lang.translate('blood_group'),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                  ),
                                  items: ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                                      .map((bg) => DropdownMenuItem(
                                            value: bg,
                                            child: Text(bg.isEmpty ? 'Select' : bg),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _bloodGroup = v ?? ''),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _marriageStatus,
                                  decoration: InputDecoration(
                                    labelText: lang.translate('marriage_status'),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                  ),
                                  items: ['unmarried', 'married']
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _marriageStatus = v ?? 'unmarried'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Contact Information
                  _buildSectionHeader(lang.translate('contact_information'), Icons.contact_mail),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(_phoneCtrl, '${lang.translate('phone')} *',
                                    keyboardType: TextInputType.phone,
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(_emailCtrl, 'E-mail ID',
                                    keyboardType: TextInputType.emailAddress),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(_addressCtrl, lang.translate('address'), maxLines: 2),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_nativeHomeCtrl, 'Native Home')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTextField(_surdhanCtrl, 'Surdhan')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(_googleMapLinkCtrl, lang.translate('google_map_link'),
                              hint: 'https://maps.google.com/...', prefixIcon: Icons.map),
                        ],
                      ),
                    ),
                  ),

                  // Social Media Section
                  _buildSectionHeader(lang.translate('social_media'), Icons.share),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildTextField(_whatsappCtrl, lang.translate('whatsapp'),
                              keyboardType: TextInputType.phone, prefixIcon: Icons.chat_bubble_outline),
                          const SizedBox(height: 12),
                          _buildTextField(_instagramCtrl, lang.translate('instagram'), prefixIcon: Icons.camera_alt_outlined),
                          const SizedBox(height: 12),
                          _buildTextField(_facebookCtrl, lang.translate('facebook'), prefixIcon: Icons.facebook),
                        ],
                      ),
                    ),
                  ),

                  // Professional & Account Section
                  _buildSectionHeader(lang.translate('professional_account'), Icons.business_center),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(_educationCtrl, lang.translate('education'), hint: 'e.g., B.Tech, MBA'),
                          const SizedBox(height: 12),
                          _buildTextField(_passwordCtrl, '${lang.translate('member_login_password')} *',
                              prefixIcon: Icons.lock,
                              obscureText: true,
                              validator: (v) => (v == null || v.length != 8 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v))
                                  ? lang.translate('must_be_8_chars')
                                  : null),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lang.translate('firms_business'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              if (_currentUserRole == 'admin')
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    _firms.add({'name': '', 'phone': '', 'mapLink': ''});
                                  }),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(lang.translate('add_firm')),
                                ),
                            ],
                          ),
                          ..._firms.asMap().entries.map((entry) {
                            final index = entry.key;
                            final firm = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Autocomplete<String>(
                                              optionsBuilder: (TextEditingValue textEditingValue) {
                                                if (textEditingValue.text.isEmpty) {
                                                  return const Iterable<String>.empty();
                                                }
                                                return _allFirmNames.where((String option) {
                                                  return option
                                                      .toLowerCase()
                                                      .contains(textEditingValue.text.toLowerCase());
                                                });
                                              },
                                              onSelected: (String selection) =>
                                                  _currentUserRole != 'member'
                                                      ? setState(() => _firms[index]['name'] = selection)
                                                      : null,
                                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                                if (controller.text != firm['name']) {
                                                  controller.text = firm['name'] ?? '';
                                                }
                                                return TextFormField(
                                                  controller: controller,
                                                  focusNode: focusNode,
                                                  enabled: _currentUserRole != 'member',
                                                  decoration: InputDecoration(
                                                    labelText: lang.translate('firm_name'),
                                                    isDense: true,
                                                  ),
                                                  onChanged: (value) => _firms[index]['name'] = value,
                                                  onFieldSubmitted: (value) => onFieldSubmitted(),
                                                );
                                              },
                                              optionsViewBuilder: (context, onSelected, options) {
                                                return Align(
                                                  alignment: Alignment.topLeft,
                                                  child: Material(
                                                    elevation: 4.0,
                                                    child: Container(
                                                      width: constraints.maxWidth,
                                                      constraints: const BoxConstraints(maxHeight: 200),
                                                      color: Theme.of(context).cardColor,
                                                      child: ListView.builder(
                                                        padding: EdgeInsets.zero,
                                                        shrinkWrap: true,
                                                        itemCount: options.length,
                                                        itemBuilder: (BuildContext context, int index) {
                                                          final String option = options.elementAt(index);
                                                          return ListTile(
                                                            title: Text(option),
                                                            onTap: () => onSelected(option),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      if (_currentUserRole == 'admin')
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          onPressed: () => setState(() => _firms.removeAt(index)),
                                        ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: firm['phone'],
                                          enabled: _currentUserRole != 'member',
                                          decoration: InputDecoration(
                                            labelText: 'Phone',
                                            filled: true,
                                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                            isDense: true,
                                          ),
                                          onChanged: (value) => _firms[index]['phone'] = value,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: firm['mapLink'],
                                          enabled: _currentUserRole != 'member',
                                          decoration: InputDecoration(
                                        labelText: 'Map Link',
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                        isDense: true,
                                      ),
                                          onChanged: (value) => _firms[index]['mapLink'] = value,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Family Information Section
                  _buildSectionHeader(lang.translate('family_information'), Icons.family_restroom),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(_dktFamilyIdCtrl, lang.translate('dkt_family_id'),
                                    hint: 'Enter DKT Family ID'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(_parentMidCtrl, lang.translate('parent_member_id'),
                                    hint: 'Enter parent MID'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _relationToHead,
                            decoration: InputDecoration(
                              labelText: lang.translate('relation_to_head'),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                            ),
                            items: [
                              DropdownMenuItem(value: 'none', child: Text(lang.translate('none'))),
                              DropdownMenuItem(
                                value: 'head',
                                enabled: !_hasFamilyHead,
                                child: Text(
                                  lang.translate('head_of_family') + (_hasFamilyHead ? ' (Already Assigned)' : ''),
                                ),
                              ),
                              DropdownMenuItem(value: 'wife', child: Text(lang.translate('wife'))),
                              DropdownMenuItem(value: 'husband', child: Text(lang.translate('husband'))),
                              DropdownMenuItem(value: 'son', child: Text(lang.translate('son'))),
                              DropdownMenuItem(value: 'daughter', child: Text(lang.translate('daughter'))),
                              DropdownMenuItem(value: 'son_in_law', child: Text(lang.translate('son_in_law'))),
                              DropdownMenuItem(value: 'daughter_in_law', child: Text(lang.translate('daughter_in_law'))),
                              DropdownMenuItem(value: 'grandson', child: Text(lang.translate('grandson'))),
                              DropdownMenuItem(value: 'granddaughter', child: Text(lang.translate('granddaughter'))),
                              DropdownMenuItem(value: 'other', child: Text(lang.translate('other'))),
                            ],
                            onChanged: (val) => setState(() => _relationToHead = val ?? 'none'),
                          ),
                          if (_relationToHead == 'head' && widget.subFamilyDocId != null) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: _subFamilyHeadRelation,
                              decoration: InputDecoration(
                                labelText: lang.translate('relation_to_main_head'),
                                hintText: 'Relationship of this head with main head (e.g. Son)',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                              ),
                              onChanged: (val) => setState(() => _subFamilyHeadRelation = val),
                            ),
                          ],
                          if (_marriageStatus == 'married') ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text(
                              lang.translate('spouse_details'),
                              style: TextStyle(
                                fontSize: 14, 
                                fontWeight: FontWeight.bold, 
                                color: Theme.of(context).colorScheme.primary
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Ask for relation first as requested
                            DropdownButtonFormField<String>(
                              value: _spouseRelation == 'none' ? null : _spouseRelation,
                              decoration: InputDecoration(
                                labelText: lang.translate('relation_to_spouse'),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                              ),
                              items: [
                                DropdownMenuItem(value: 'wife_of', child: Text(lang.translate('wife_of'))),
                                DropdownMenuItem(value: 'husband_of', child: Text(lang.translate('husband_of'))),
                              ],
                              onChanged: (val) => setState(() => _spouseRelation = val ?? 'none'),
                            ),
                            if (_spouseRelation != 'none') ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _selectedSpouseMid,
                                decoration: InputDecoration(
                                  labelText: lang.translate('select_spouse'),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                ),
                                items: [
                                  DropdownMenuItem(value: null, child: Text(lang.translate('none'))),
                                  ..._familyMembers
                                      .map((m) {
                                    final subName = m.subFamilyDocId == (widget.subFamilyDocId ?? '') ? ' (This Sub-family)' : '';
                                    return DropdownMenuItem(
                                      value: m.mid,
                                      child: Text('${m.fullName} (${m.mid})$subName'),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSpouseMid = val;
                                  });
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Tags Section
                  _buildSectionHeader(lang.translate('tags'), Icons.label_outline),
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 30),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(_tagsCtrl, lang.translate('add_tag'),
                                    hint: 'Enter tag and press +'),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  radius: 18,
                                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                                ),
                                onPressed: () {
                                  final v = _tagsCtrl.text.trim();
                                  if (v.isNotEmpty && v.length <= 15 && !_tags.contains(v)) {
                                    setState(() {
                                      _tags.add(v);
                                      _tagsCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _tags.map((tag) {
                                return Chip(
                                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  onDeleted: () => setState(() => _tags.remove(tag)),
                                  deleteIconColor: Colors.red,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      lang.translate('add_member'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        // Loading overlay
        if (_loading)
          Container(
            color: Colors.black45,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Adding member...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class EditMemberScreen extends StatefulWidget {
  final String memberId;
  final String familyDocId;
  final String? subFamilyDocId; // NEW: Optional sub-family ID

  const EditMemberScreen({
    super.key,
    required this.memberId,
    required this.familyDocId,
    this.subFamilyDocId,
  });

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
    bool obscureText = false,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      enabled: enabled,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryColor) : null,
        filled: true,
        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade700, 
          fontWeight: FontWeight.w400
        ),
        floatingLabelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, 
            width: 1
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _gotraCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _educationCtrl = TextEditingController(); // Added
  final _passwordCtrl = TextEditingController(); // Added
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // Added
  final _addressCtrl = TextEditingController();
  final _googleMapLinkCtrl = TextEditingController();
  final _surdhanCtrl = TextEditingController(); // Added
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _nativeHomeCtrl = TextEditingController();
  final _parentMidCtrl = TextEditingController();
  final _dktFamilyIdCtrl = TextEditingController();
  String? _profilePhotoUrl;
  String? _pendingPhotoPath; // New: Store local path for upload on save
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, String>> _firms = [];
  String _bloodGroup = '';
  String _gender = 'male'; // Added
  String _marriageStatus = 'unmarried';
  String _relationToHead = 'none';
  String _subFamilyHeadRelation = '';
  String _memberMid = ''; // New field
  bool _loading = true;
  bool _hasFamilyHead = false;
  bool _alreadyHead = false; // Is THIS member currently the head?
  List<String> _tags = [];
  List<String> _allFirmNames = [];
  String? _selectedSpouseMid;
  String _spouseRelation = 'none'; // wife_of | husband_of | none
  List<MemberModel> _familyMembers = [];
  String _currentUserRole = 'member';

  final PhotoService _photoService = PhotoService();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadMemberData();
    _checkExistingHead();
    _loadFirmNames();
  }

  Future<void> _loadUserRole() async {
    final role = await SessionManager.getRole();
    if (mounted) {
      setState(() => _currentUserRole = role ?? 'member');
    }
  }

  Future<void> _loadFirmNames() async {
    final names = await MemberService().getAllFirmNames();
    if (mounted) {
      setState(() => _allFirmNames = names);
    }
  }

  Future<void> _checkExistingHead() async {
    final hasHead = await MemberService().hasSubFamilyHead(
      widget.familyDocId,
      widget.subFamilyDocId ?? '',
    );
    if (mounted) {
      setState(() => _hasFamilyHead = hasHead);
    }
  }

  Future<void> _launchWhatsApp() async {
    final url = 'https://wa.me/${_whatsappCtrl.text.trim()}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchInstagram() async {
    final username = _instagramCtrl.text.trim();
    final url = username.startsWith('https://')
        ? username
        : 'https://instagram.com/$username';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchFacebook() async {
    final username = _facebookCtrl.text.trim();
    final url = username.startsWith('https://')
        ? username
        : 'https://facebook.com/$username';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Widget _buildSocialIcon(IconData icon, Color color, String label, TextEditingController controller, VoidCallback onPressed) {
    return Column(
      children: [
        IconButton(
          onPressed: controller.text.trim().isNotEmpty ? onPressed : null,
          icon: Icon(icon, color: controller.text.trim().isNotEmpty ? color : Colors.grey),
          iconSize: 32,
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Future<void> _launchMap(String mapUrl) async {
    if (mapUrl.isNotEmpty && await canLaunchUrl(Uri.parse(mapUrl))) {
      await launchUrl(Uri.parse(mapUrl));
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: ImageKitConfig.maxImageWidth.toDouble(),
        maxHeight: ImageKitConfig.maxImageHeight.toDouble(),
        imageQuality: ImageKitConfig.imageQuality,
      );

      if (image != null) {
        setState(() {
          _pendingPhotoPath = image.path;
          _profilePhotoUrl = image.path; // Preview local image
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    String photoUrl = _profilePhotoUrl ?? '';

    // Upload photo if changed
    if (_pendingPhotoPath != null) {
      try {
        final uploadedUrl = await _photoService.uploadProfilePhoto(
          memberId: widget.memberId,
          image: XFile(_pendingPhotoPath!),
        );

        if (uploadedUrl != null && uploadedUrl.startsWith('http')) {
          photoUrl = uploadedUrl;
        } else {
          throw Exception('Failed to upload photo');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      // Safety check: if URL is local path but no pending upload, clear it
      if (photoUrl.isNotEmpty && !photoUrl.startsWith('http')) {
        photoUrl = '';
      }
    }

    try {
      await MemberService().updateMember(
        mainFamilyDocId: widget.familyDocId,
        subFamilyDocId: widget.subFamilyDocId ?? '',
        memberId: widget.memberId,
        updates: {
          'fullName': _fullNameCtrl.text.trim(),
          'surname': _surnameCtrl.text.trim(),
          'fatherName': _fatherNameCtrl.text.trim(),
          'motherName': _motherNameCtrl.text.trim(),
          'gotra': _gotraCtrl.text.trim(),
          'gender': _gender,
          'birthDate': _birthDateCtrl.text.trim(),
          'education': _educationCtrl.text.trim(),
          'bloodGroup': _bloodGroup,
          'marriageStatus': _marriageStatus,
          'nativeHome': _nativeHomeCtrl.text.trim(),
          'mid': _memberMid,
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'googleMapLink': _googleMapLinkCtrl.text.trim(),
          'surdhan': _surdhanCtrl.text.trim(),
          'whatsapp': _whatsappCtrl.text.trim(),
          'instagram': _instagramCtrl.text.trim(),
          'facebook': _facebookCtrl.text.trim(),
          'firms': _firms,
          'tags': _tags,
          'parentMid': _parentMidCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
          'familyId': _dktFamilyIdCtrl.text.trim(),
          'photoUrl': photoUrl,
          'relationToHead': _relationToHead,
          'subFamilyHeadRelationToMainHead': _subFamilyHeadRelation,
          'spouseMid': _selectedSpouseMid ?? '',
          'spouseRelation': _spouseRelation,
        },
      );

      // If a spouse was selected, update the link
      if (_selectedSpouseMid != null && _selectedSpouseMid!.isNotEmpty) {
        final spouseMember = _familyMembers.firstWhere((m) => m.mid == _selectedSpouseMid);
        await MemberService().updateSpouseLink(
          mainFamilyDocId: widget.familyDocId,
          member1Id: widget.memberId,
          member1SubFamilyDocId: widget.subFamilyDocId ?? '',
          member2Id: spouseMember.id,
          member2SubFamilyDocId: spouseMember.subFamilyDocId,
          relation: _spouseRelation,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMemberData() async {
    final member = await MemberService().getMember(
      mainFamilyDocId: widget.familyDocId,
      subFamilyDocId: widget.subFamilyDocId ?? '',
      memberId: widget.memberId,
    );
    if (member != null) {
      _fullNameCtrl.text = member.fullName;
      _surnameCtrl.text = member.surname;
      _fatherNameCtrl.text = member.fatherName;
      _motherNameCtrl.text = member.motherName;
      _gotraCtrl.text = member.gotra;
      _birthDateCtrl.text = member.birthDate;
      _educationCtrl.text = member.education; // Added
      _phoneCtrl.text = member.phone;
      _emailCtrl.text = member.email; // Added
      _addressCtrl.text = member.address;
      _googleMapLinkCtrl.text = member.googleMapLink;
      _surdhanCtrl.text = member.surdhan; // Added
      _whatsappCtrl.text = member.whatsapp;
      _instagramCtrl.text = member.instagram;
      _facebookCtrl.text = member.facebook;
      _passwordCtrl.text = member.password; // Added
      _bloodGroup = member.bloodGroup;
      _gender = member.gender; // Added
      _marriageStatus = member.marriageStatus;
      _nativeHomeCtrl.text = member.nativeHome;
      _dktFamilyIdCtrl.text = member.familyId;
      _parentMidCtrl.text = member.parentMid;
      _tags = List.from(member.tags);
      _firms = List.from(member.firms);
      _profilePhotoUrl = member.photoUrl;
      _memberMid = member.mid;
      _relationToHead = member.relationToHead;
      _subFamilyHeadRelation = member.subFamilyHeadRelationToMainHead;
      _selectedSpouseMid = member.spouseMid.isEmpty ? null : member.spouseMid;
      _spouseRelation = member.spouseRelation.isEmpty ? 'none' : member.spouseRelation;
      _alreadyHead = _relationToHead == 'head';
      if (_memberMid.isEmpty) {
        _memberMid = MemberModel.generateMid(member.familyId, member.subFamilyId);
      }
    }
    
    // Load family members for spouse selection
    final familyMembers = await MemberService().getSubFamilyMembers(
      widget.familyDocId,
      widget.subFamilyDocId ?? '',
    );
    if (mounted) {
      setState(() {
        _familyMembers = familyMembers;
        _loading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lang = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(lang.translate('edit_member'))),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              _buildSectionHeader(lang.translate('profile_photo'), Icons.camera_alt),
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickProfilePhoto,
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            backgroundImage: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                                ? (_profilePhotoUrl!.startsWith('http')
                                    ? CachedNetworkImageProvider(_profilePhotoUrl!) as ImageProvider
                                    : FileImage(File(_profilePhotoUrl!)))
                                : null,
                            child: _profilePhotoUrl == null || _profilePhotoUrl!.isEmpty
                                ? Icon(Icons.add_a_photo, size: 40, color: Theme.of(context).colorScheme.primary)
                                : null,
                          ),
                        ),
                        if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              _profilePhotoUrl = null;
                              _pendingPhotoPath = null;
                            }),
                            child: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                          )
                        else ...[
                          const SizedBox(height: 12),
                          Text(
                            lang.translate('tap_to_add_photo'),
                            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Personal Information
              _buildSectionHeader(lang.translate('personal_information'), Icons.person),
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('MID: $_memberMid',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontSize: 16,
                              )),
                          if (_alreadyHead)
                            Chip(
                              label: Text(lang.translate('head_of_family'), style: const TextStyle(fontSize: 12, color: Colors.white)),
                              backgroundColor: Colors.orange.shade700,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_fullNameCtrl, '${lang.translate('full_name')} *',
                          validator: (v) => v == null || v.isEmpty ? lang.translate('required') : null),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_surnameCtrl, lang.translate('surname'))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(_gotraCtrl, lang.translate('gotra'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_fatherNameCtrl, lang.translate('father_name')),
                      const SizedBox(height: 12),
                      _buildTextField(_motherNameCtrl, lang.translate('mother_name')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: lang.translate('gender'),
                                border: const OutlineInputBorder(),
                              ),
                              items: ['male', 'female']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(lang.translate(g))))
                                  .toList(),
                              onChanged: (v) => setState(() => _gender = v ?? 'male'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(_birthDateCtrl, 'Birth Date (dd/MM/yyyy) *',
                                hint: '15/08/1990',
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _bloodGroup.isEmpty ? null : _bloodGroup,
                              decoration: const InputDecoration(
                                labelText: 'Blood Group',
                                border: OutlineInputBorder(),
                              ),
                              items: ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                                  .map((bg) => DropdownMenuItem(
                                        value: bg,
                                        child: Text(bg.isEmpty ? 'Select' : bg),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _bloodGroup = v ?? ''),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _marriageStatus,
                              decoration: const InputDecoration(
                                labelText: 'Marriage Status',
                                border: OutlineInputBorder(),
                              ),
                              items: ['unmarried', 'married']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => setState(() => _marriageStatus = v ?? 'unmarried'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_nativeHomeCtrl, 'Native Home')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(_surdhanCtrl, 'Surdhan')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Contact Info Section
              _buildSectionHeader(lang.translate('contact_information'), Icons.contact_mail),
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(_phoneCtrl, '${lang.translate('phone')} *',
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(_emailCtrl, 'E-mail ID',
                                keyboardType: TextInputType.emailAddress),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_addressCtrl, lang.translate('address'), maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField(_googleMapLinkCtrl, lang.translate('google_map_link'),
                          hint: 'https://maps.google.com/...', prefixIcon: Icons.map),
                    ],
                  ),
                ),
              ),

              // Social Media Section
              _buildSectionHeader(lang.translate('social_media'), Icons.share),
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTextField(_whatsappCtrl, lang.translate('whatsapp'),
                          keyboardType: TextInputType.phone, prefixIcon: Icons.chat_bubble_outline),
                      const SizedBox(height: 12),
                      _buildTextField(_instagramCtrl, lang.translate('instagram'), prefixIcon: Icons.camera_alt_outlined),
                      const SizedBox(height: 12),
                      _buildTextField(_facebookCtrl, lang.translate('facebook'), prefixIcon: Icons.facebook),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          _buildSocialIcon(Icons.message, Colors.teal, 'WhatsApp', _whatsappCtrl, _launchWhatsApp),
                          _buildSocialIcon(Icons.camera_alt, Colors.purple, 'Instagram', _instagramCtrl, _launchInstagram),
                          _buildSocialIcon(Icons.facebook, Colors.blue, 'Facebook', _facebookCtrl, _launchFacebook),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Professional & Account Section
              _buildSectionHeader(lang.translate('professional_account'), Icons.business_center),
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(_educationCtrl, lang.translate('education'), hint: 'e.g., B.Tech, MBA'),
                      const SizedBox(height: 12),
                      _buildTextField(_passwordCtrl, '${lang.translate('member_login_password')} *',
                          prefixIcon: Icons.lock,
                          obscureText: true,
                          validator: (v) => (v == null || v.length != 8 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v))
                              ? lang.translate('must_be_8_chars')
                              : null),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang.translate('firms_business'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (_currentUserRole == 'admin')
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _firms.add({'name': '', 'phone': '', 'mapLink': ''});
                              }),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(lang.translate('add_firm')),
                            ),
                        ],
                      ),
                      ..._firms.asMap().entries.map((entry) {
                        final index = entry.key;
                        final firm = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Autocomplete<String>(
                                          optionsBuilder: (TextEditingValue textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return const Iterable<String>.empty();
                                            }
                                            return _allFirmNames.where((String option) {
                                              return option
                                                  .toLowerCase()
                                                  .contains(textEditingValue.text.toLowerCase());
                                            });
                                          },
                                          onSelected: (String selection) =>
                                              _currentUserRole != 'member'
                                                  ? setState(() => _firms[index]['name'] = selection)
                                                  : null,
                                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                            if (controller.text != firm['name']) {
                                              controller.text = firm['name'] ?? '';
                                            }
                                            return TextFormField(
                                              controller: controller,
                                              focusNode: focusNode,
                                              enabled: _currentUserRole != 'member',
                                              decoration: InputDecoration(
                                                labelText: lang.translate('firm_name'),
                                                filled: true,
                                                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                                isDense: true,
                                              ),
                                              onChanged: (value) => _firms[index]['name'] = value,
                                              onFieldSubmitted: (value) => onFieldSubmitted(),
                                            );
                                          },
                                          optionsViewBuilder: (context, onSelected, options) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 4.0,
                                                child: Container(
                                                  width: constraints.maxWidth,
                                                  constraints: const BoxConstraints(maxHeight: 200),
                                                  color: Theme.of(context).cardColor,
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    shrinkWrap: true,
                                                    itemCount: options.length,
                                                    itemBuilder: (BuildContext context, int index) {
                                                      final String option = options.elementAt(index);
                                                      return ListTile(
                                                        title: Text(option),
                                                        onTap: () => onSelected(option),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  if (_currentUserRole == 'admin')
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => setState(() => _firms.removeAt(index)),
                                    ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: firm['phone'],
                                      enabled: _currentUserRole != 'member',
                                      decoration: InputDecoration(
                                        labelText: 'Phone',
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                        isDense: true,
                                      ),
                                      onChanged: (value) => _firms[index]['phone'] = value,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: firm['mapLink'],
                                      enabled: _currentUserRole != 'member',
                                      decoration: InputDecoration(
                                        labelText: 'Map Link',
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                                        isDense: true,
                                      ),
                                      onChanged: (value) => _firms[index]['mapLink'] = value,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Family Information Section
              _buildSectionHeader(lang.translate('family_information'), Icons.family_restroom),
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(_dktFamilyIdCtrl, lang.translate('dkt_family_id'), hint: 'Enter DKT Family ID'),
                      const SizedBox(height: 12),
                      _buildTextField(_parentMidCtrl, lang.translate('parent_member_id'), hint: 'Enter parent MID (optional)'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _relationToHead,
                        decoration: InputDecoration(
                          labelText: lang.translate('relation_to_head'),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                        ),
                        items: [
                          DropdownMenuItem(value: 'none', child: Text(lang.translate('none'))),
                          DropdownMenuItem(
                            value: 'head',
                            enabled: !_hasFamilyHead || _alreadyHead,
                            child: Text(lang.translate('head_of_family') +
                                ((_hasFamilyHead && !_alreadyHead) ? ' (Already Assigned)' : '')),
                          ),
                          DropdownMenuItem(value: 'wife', child: Text(lang.translate('wife'))),
                          DropdownMenuItem(value: 'husband', child: Text(lang.translate('husband'))),
                          DropdownMenuItem(value: 'son', child: Text(lang.translate('son'))),
                          DropdownMenuItem(value: 'daughter', child: Text(lang.translate('daughter'))),
                          DropdownMenuItem(value: 'son_in_law', child: Text(lang.translate('son_in_law'))),
                          DropdownMenuItem(value: 'daughter_in_law', child: Text(lang.translate('daughter_in_law'))),
                          DropdownMenuItem(value: 'grandson', child: Text(lang.translate('grandson'))),
                          DropdownMenuItem(value: 'granddaughter', child: Text(lang.translate('granddaughter'))),
                          DropdownMenuItem(value: 'other', child: Text(lang.translate('other'))),
                        ],
                        onChanged: (v) => setState(() => _relationToHead = v ?? 'none'),
                      ),
                      if (_relationToHead == 'head' && widget.subFamilyDocId != null) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: _subFamilyHeadRelation,
                          decoration: InputDecoration(
                            labelText: lang.translate('relation_to_main_head'),
                            hintText: 'Relationship of this head with main head (e.g. Son)',
                          ),
                          onChanged: (val) => setState(() => _subFamilyHeadRelation = val),
                        ),
                      ],
                      if (_marriageStatus == 'married') ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          lang.translate('spouse_details'),
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.bold, 
                            color: Theme.of(context).colorScheme.primary
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Ask for relation first as requested
                        DropdownButtonFormField<String>(
                          value: _spouseRelation == 'none' ? null : _spouseRelation,
                          decoration: InputDecoration(
                            labelText: lang.translate('relation_to_spouse'),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                          ),
                          items: [
                            DropdownMenuItem(value: 'wife_of', child: Text(lang.translate('wife_of'))),
                            DropdownMenuItem(value: 'husband_of', child: Text(lang.translate('husband_of'))),
                          ],
                          onChanged: (val) => setState(() => _spouseRelation = val ?? 'none'),
                        ),
                        if (_spouseRelation != 'none') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedSpouseMid,
                            decoration: InputDecoration(
                              labelText: lang.translate('select_spouse'),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                            ),
                            items: [
                              DropdownMenuItem(value: null, child: Text(lang.translate('none'))),
                              ..._familyMembers
                                  .where((m) => m.mid != _memberMid)
                                  .map((m) {
                                final subName = m.subFamilyDocId == (widget.subFamilyDocId ?? '') ? ' (This Sub-family)' : '';
                                return DropdownMenuItem(
                                  value: m.mid,
                                  child: Text('${m.fullName} (${m.mid})$subName'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedSpouseMid = val;
                              });
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // Tags Section
              _buildSectionHeader(lang.translate('tags'), Icons.label_outline),
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 30),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(_tagsCtrl, lang.translate('add_tag'), hint: 'Enter tag and press +'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              radius: 18,
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                            onPressed: () {
                              final v = _tagsCtrl.text.trim();
                              if (v.isNotEmpty && v.length <= 15 && !_tags.contains(v)) {
                                setState(() {
                                  _tags.add(v);
                                  _tagsCtrl.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _tags.map((tag) {
                            return Chip(
                              label: Text(tag, style: const TextStyle(fontSize: 12)),
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              onDeleted: () => setState(() => _tags.remove(tag)),
                              deleteIconColor: Colors.red,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    lang.translate('save_changes'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class MemberListScreen extends StatefulWidget {
  final String? familyDocId;
  final String familyName;
  final String? subFamilyDocId;
  final bool isGlobal;
  final bool showOnlyManagers;

  const MemberListScreen({
    super.key,
    this.familyDocId,
    this.familyName = 'Members',
    this.subFamilyDocId,
    this.isGlobal = false,
    this.showOnlyManagers = false,
  });

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen>
    with WidgetsBindingObserver {
  late Stream<QuerySnapshot> _membersStream;
  String _searchQuery = '';
  String _selectedTag = '';
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
    WidgetsBinding.instance.addObserver(this);

    // Debug logging
    print('MemberListScreen initialized:');
    print('  isGlobal: ${widget.isGlobal}');
    print('  familyDocId: ${widget.familyDocId}');
    print('  subFamilyDocId: ${widget.subFamilyDocId}');
    print('  familyName: ${widget.familyName}');

    if (widget.isGlobal) {
      // Remove orderBy for collectionGroup to avoid index requirement
      _membersStream = FirebaseFirestore.instance
          .collectionGroup('members')
          .snapshots();
    } else {
      // Ensure we have required IDs for subfamily query
      if (widget.familyDocId == null || widget.subFamilyDocId == null) {
        print('ERROR: Missing required IDs for subfamily query');
        print('  familyDocId: ${widget.familyDocId}');
        print('  subFamilyDocId: ${widget.subFamilyDocId}');
      }
      
      final path = 'families/${widget.familyDocId}/subfamilies/${widget.subFamilyDocId}/members';
      print('  Query path: $path');
      
      _membersStream = FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyDocId)
          .collection('subfamilies')
          .doc(widget.subFamilyDocId)
          .collection('members')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the stream when app resumes
      setState(() {
        if (widget.isGlobal) {
          _membersStream = FirebaseFirestore.instance
              .collectionGroup('members')
              .snapshots();
        } else {
          _membersStream = FirebaseFirestore.instance
              .collection('families')
              .doc(widget.familyDocId)
              .collection('subfamilies')
              .doc(widget.subFamilyDocId)
              .collection('members')
              .orderBy('createdAt', descending: true)
              .snapshots();
        }
      });
    }
  }



  Future<void> _loadRole() async {
    final role = await SessionManager.getRole();
    setState(() => _userRole = role);
  }

  // Helper function to build initials widget
  Widget _buildInitials(Map<String, dynamic> data) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          (data['fullName'] ?? '?')[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showOnlyManagers ? lang.translate('managers') : widget.familyName),
        backgroundColor: Colors.blue.shade900,
        actions: [
          if (!widget.isGlobal && _userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMemberScreen(
                      familyDocId: widget.familyDocId!,
                      familyName: widget.familyName,
                      subFamilyDocId: widget.subFamilyDocId,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.showOnlyManagers ? lang.translate('search_managers_hint') : lang.translate('search_members_hint'),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          FutureBuilder<List<String>>(
            future: MemberService().getAllTags(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final tags = snapshot.data!;
              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    final isSelected = _selectedTag == tag;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTag = selected ? tag : '';
                          });
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _membersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PulseAnimation(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade700,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.people,
                              color: Theme.of(context).cardColor,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeInAnimation(
                          child: Text(
                            'Loading members...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Center(child: Text(lang.translate('no_members_found')));
                }

                final members = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'member';
                  
                  // Role Filter
                  if (widget.showOnlyManagers && role != 'manager') return false;
                  // Allow managers in global search so they can be assigned roles
                  // if (!widget.showOnlyManagers && widget.isGlobal && role == 'manager') return false;

                  final fullName = (data['fullName'] ?? '').toLowerCase();
                  final mid = (data['mid'] ?? '').toLowerCase();
                  final rawTags = data['tags'];
                  final tagsList = (rawTags is List) ? List<String>.from(rawTags) : <String>[];
                  final searchLower = _searchQuery.toLowerCase();
                  
                  // Search by Name, MID, or Tags
                  final matchesSearch = fullName.contains(searchLower) || 
                                      mid.contains(searchLower) || 
                                      tagsList.any((tag) => tag.toString().toLowerCase().contains(searchLower));
                  
                  final matchesTagChip =
                      _selectedTag.isEmpty || tagsList.contains(_selectedTag);
                  return matchesSearch && matchesTagChip;
                }).toList()
                  ..sort((a, b) {
                    // Sort by createdAt descending in memory
                    final aCreated = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bCreated = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    if (aCreated == null && bCreated == null) return 0;
                    if (aCreated == null) return 1;
                    if (bCreated == null) return -1;
                    return bCreated.compareTo(aCreated);
                  });

                if (members.isEmpty) {
                  return const Center(
                    child: Text('No members match your search'),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72, 
                  ),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final doc = members[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isActive = data['isActive'] as bool? ?? true;

                    return SlideInAnimation(
                      delay: Duration(milliseconds: 50 * index),
                      beginOffset: const Offset(0, 0.2),
                      child: AnimatedCard(
                        borderRadius: 16,
                        onTap: () {
                          // Determine family IDs robustly from record data or path
                          String famId = data['familyDocId'] ?? '';
                          String subFamId = data['subFamilyDocId'] ?? '';
                          
                          // Fallback to parsing from path if missing (legacy records)
                          if (famId.isEmpty || subFamId.isEmpty) {
                            final pathParts = doc.reference.path.split('/');
                            // families/{famId}/subfamilies/{subfamId}/members/{memId}
                            if (pathParts.length >= 4) {
                              famId = pathParts[1];
                              subFamId = pathParts[3];
                            }
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberDetailScreen(
                                memberId: doc.id,
                                familyDocId: famId,
                                subFamilyDocId: subFamId,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                       Colors.teal.shade50,
                                      Colors.white,
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.grey.shade300,
                                      Colors.grey.shade200,
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? Colors.teal.shade200
                                  : Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // PROFILE PHOTO with enhanced design
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.teal.shade400
                                          : Colors.grey.shade400,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isActive
                                                ? Colors.teal
                                                : Colors.grey)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: (() {
                                      final photoUrl =
                                          data['photoUrl'] as String? ?? '';
                                      if (photoUrl.isNotEmpty &&
                                          photoUrl.startsWith('http')) {
                                        return CachedNetworkImage(
                                          imageUrl: photoUrl,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              (context, url, error) {
                                                return _buildInitials(data);
                                              },
                                        );
                                      } else {
                                        return _buildInitials(data);
                                      }
                                    })(),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // NAME
                                Text(
                                  data['fullName'] ?? 'Unnamed',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.black87
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                
                                const SizedBox(height: 4),

                                // MID Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.blue.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    data['mid'] ?? 'NO MID',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                
                                const SizedBox(height: 3),

                                // AGE Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cake,
                                        size: 10,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${data['age'] ?? 0}y',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // ACTIONS
                                if (_userRole == 'admin')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_userRole == 'admin' || _userRole == 'manager')
                                          Flexible(
                                            child: _buildCompactAction(
                                              icon: Icons.edit,
                                              color: Colors.blue,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => EditMemberScreen(
                                                      memberId: doc.id,
                                                      familyDocId: widget.familyDocId ??
                                                          data['familyDocId'],
                                                      subFamilyDocId: widget
                                                              .subFamilyDocId ??
                                                          data['subFamilyDocId'],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        if (_userRole == 'admin')
                                          Flexible(
                                            child: _buildCompactAction(
                                              icon: isActive
                                                  ? Icons.block
                                                  : Icons.lock_open,
                                              color: isActive
                                                  ? Colors.orange
                                                  : Colors.teal,
                                              onTap: () async {
                                                await MemberService()
                                                    .toggleMemberStatus(
                                                  mainFamilyDocId: widget.familyDocId ??
                                                      data['familyDocId'] ??
                                                      '',
                                                  subFamilyDocId: widget
                                                          .subFamilyDocId ??
                                                      data['subFamilyDocId'] ??
                                                      '',
                                                  memberId: doc.id,
                                                );
                                              },
                                            ),
                                          ),
                                        if (_userRole == 'admin')
                                          Flexible(
                                            child: _buildCompactAction(
                                              icon: data['role'] == 'manager'
                                                  ? Icons.admin_panel_settings
                                                  : Icons.admin_panel_settings_outlined,
                                              color: data['role'] == 'manager'
                                                  ? Colors.purple
                                                  : Colors.grey,
                                              onTap: () async {
                                                final isCurrentlyManager = data['role'] == 'manager';
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: Text(isCurrentlyManager 
                                                      ? lang.translate('demote_member') 
                                                      : lang.translate('promote_member')),
                                                    content: Text('${lang.translate('are_you_sure_role')} ${isCurrentlyManager 
                                                      ? lang.translate('demote').toLowerCase() 
                                                      : lang.translate('promote').toLowerCase()} ${lang.translate('member').toLowerCase()}?'),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('cancel'))),
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.pop(context, true),
                                                        child: Text(lang.translate('confirmation')),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  // More robust way to get parent IDs: Parse from document path
                                                  // Path format: families/{famId}/subfamilies/{subFamId}/members/{memberId}
                                                  final pathSegments = doc.reference.path.split('/');
                                                  String famId = '';
                                                  String subFamId = '';
                                                  
                                                  if (pathSegments.length >= 4) {
                                                    famId = pathSegments[1];
                                                    subFamId = pathSegments[3];
                                                  } else {
                                                    // Fallback to data but only if path parsing fails
                                                    famId = widget.familyDocId ?? data['familyDocId'] ?? '';
                                                    subFamId = widget.subFamilyDocId ?? data['subFamilyDocId'] ?? '';
                                                  }
                                                  
                                                  await MemberService().updateMemberRole(
                                                    mainFamilyDocId: famId,
                                                    subFamilyDocId: subFamId,
                                                    memberId: doc.id,
                                                    newRole: isCurrentlyManager ? 'member' : 'manager',
                                                  );

                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                    content: Text(isCurrentlyManager 
                                                      ? lang.translate('demoted_success') 
                                                      : lang.translate('promoted_success')),
                                                    backgroundColor: Colors.green,
                                                  ));
                                                }
                                              },
                                            ),
                                          ),
                                        if (_userRole == 'admin')
                                          Flexible(
                                            child: _buildCompactAction(
                                              icon: Icons.delete,
                                              color: Colors.red,
                                              onTap: () async {
                                                final confirm =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: Text(lang.translate('delete')),
                                                    content: Text(
                                                      lang.translate('confirm_delete_role'),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: Text(lang.translate('cancel')),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: Text(lang.translate('delete')),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await MemberService().deleteMember(
                                                    mainFamilyDocId: widget.familyDocId ??
                                                        data['familyDocId'] ??
                                                        '',
                                                    subFamilyDocId: widget
                                                            .subFamilyDocId ??
                                                        data['subFamilyDocId'] ??
                                                        '',
                                                    memberId: doc.id,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (widget.isGlobal || _userRole != 'admin')
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMemberScreen(
                      familyDocId: widget.familyDocId!,
                      familyName: widget.familyName,
                      subFamilyDocId: widget.subFamilyDocId,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
