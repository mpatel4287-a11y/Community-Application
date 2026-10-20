// lib/screens/user/member_update_request_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/member_model.dart';
import '../../models/member_update_request_model.dart';
import '../../services/update_request_service.dart';
import '../../services/photo_service.dart';
import '../../services/member_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/circular_image_cropper_dialog.dart';

class MemberUpdateRequestScreen extends StatefulWidget {
  final MemberModel? targetMember;

  const MemberUpdateRequestScreen({super.key, this.targetMember});

  @override
  State<MemberUpdateRequestScreen> createState() => _MemberUpdateRequestScreenState();
}

class _MemberUpdateRequestScreenState extends State<MemberUpdateRequestScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _updateRequestService = UpdateRequestService();
  final _photoService = PhotoService();
  final _memberService = MemberService();

  late TabController _tabController;

  MemberModel? _selectedMember;
  List<MemberModel> _familyMembers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Selected request category
  String _selectedCategory = 'all'; // 'all', 'personal_details', 'contact_info', 'social_media', 'business_info', 'lineage_info', 'photo_update', 'general'

  // Photo Update State
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  Uint8List? _rawOriginalImageBytes;

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _googleMapLinkController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _nativeHomeController = TextEditingController();
  final _gotraController = TextEditingController();
  final _educationController = TextEditingController();
  final _surdhanController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _snapchatController = TextEditingController();
  final _parentMidController = TextEditingController();
  final _spouseMidController = TextEditingController();
  final _todController = TextEditingController();

  String _gender = 'male';
  String _relationToHead = 'none';
  bool _isDeceased = false;
  bool _isPublic = true;
  String _selectedBloodGroup = '';
  String _selectedMarriageStatus = '';

  List<Map<String, String>> _firms = [];

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _marriageStatuses = ['unmarried', 'married', 'widowed', 'divorced'];
  final List<Map<String, String>> _relationOptions = [
    {'value': 'none', 'label': 'None'},
    {'value': 'head', 'label': 'Head of Family'},
    {'value': 'wife', 'label': 'Wife'},
    {'value': 'husband', 'label': 'Husband'},
    {'value': 'son', 'label': 'Son'},
    {'value': 'daughter', 'label': 'Daughter'},
    {'value': 'son_in_law', 'label': 'Son in Law'},
    {'value': 'daughter_in_law', 'label': 'Daughter in Law'},
    {'value': 'grandson', 'label': 'Grandson'},
    {'value': 'granddaughter', 'label': 'Granddaughter'},
    {'value': 'father', 'label': 'Father'},
    {'value': 'mother', 'label': 'Mother'},
    {'value': 'brother', 'label': 'Brother'},
    {'value': 'sister', 'label': 'Sister'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _googleMapLinkController.dispose();
    _fullNameController.dispose();
    _surnameController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _nativeHomeController.dispose();
    _gotraController.dispose();
    _educationController.dispose();
    _surdhanController.dispose();
    _birthDateController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _snapchatController.dispose();
    _parentMidController.dispose();
    _spouseMidController.dispose();
    _todController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      MemberModel? activeMember = widget.targetMember;

      if (activeMember == null) {
        final memberId = await SessionManager.getMemberId();
        final memberDocId = await SessionManager.getMemberDocId();
        final familyDocId = await SessionManager.getFamilyDocId();

        if (familyDocId != null && memberDocId != null) {
          final members = await _memberService.getFamilyMembers(familyDocId);
          activeMember = members.where((m) => m.id == memberDocId || m.id == memberId).firstOrNull;
          if (activeMember == null && members.isNotEmpty) {
            activeMember = members.first;
          }
        }

        if (activeMember == null && memberId != null && memberId.isNotEmpty) {
          activeMember = await _memberService.getMemberByMid(memberId);
        }
      }

      if (activeMember != null) {
        _selectedMember = activeMember;
        _populateFieldsFromMember(activeMember);

        // Fetch family members if user manages a family
        if (activeMember.familyDocId.isNotEmpty) {
          final famMembers = await _memberService.getFamilyMembers(activeMember.familyDocId);
          if (mounted) {
            setState(() {
              _familyMembers = famMembers;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing update request screen: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateFieldsFromMember(MemberModel m) {
    _fullNameController.text = m.fullName;
    _surnameController.text = m.surname;
    _phoneController.text = m.phone;
    _whatsappController.text = m.whatsapp;
    _emailController.text = m.email;
    _addressController.text = m.address;
    _googleMapLinkController.text = m.googleMapLink;
    _fatherNameController.text = m.fatherName;
    _motherNameController.text = m.motherName;
    _nativeHomeController.text = m.nativeHome;
    _gotraController.text = m.gotra;
    _educationController.text = m.education;
    _surdhanController.text = m.surdhan;
    _birthDateController.text = m.birthDate;
    _gender = m.gender.toLowerCase() == 'female' ? 'female' : 'male';
    _instagramController.text = m.instagram;
    _facebookController.text = m.facebook;
    _snapchatController.text = m.snapchat;
    _parentMidController.text = m.parentMid;
    _spouseMidController.text = m.spouseMid;
    _relationToHead = m.relationToHead.isNotEmpty ? m.relationToHead.toLowerCase() : 'none';
    _isDeceased = m.isDeceased;
    _isPublic = m.isPublic;
    _todController.text = m.tod;

    final bg = m.bloodGroup.trim().toUpperCase();
    _selectedBloodGroup = _bloodGroups.contains(bg) ? bg : 'B+';
    final ms = m.marriageStatus.trim().toLowerCase();
    _selectedMarriageStatus = _marriageStatuses.contains(ms) ? ms : 'unmarried';

    _firms = m.firms
        .map((f) => {
              'name': f['name'] ?? '',
              'phone': f['phone'] ?? '',
              'mapLink': f['mapLink'] ?? '',
            })
        .toList();
    if (_firms.isEmpty) {
      _firms.add({'name': '', 'phone': '', 'mapLink': ''});
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = source == ImageSource.camera
          ? await _photoService.pickFromCamera()
          : await _photoService.pickImage();

      if (image != null && mounted) {
        final rawBytes = await image.readAsBytes();
        _rawOriginalImageBytes = rawBytes;

        // Open the circular image cropper dialog
        final croppedBytes = await CircularImageCropperDialog.show(
          context,
          imageBytes: rawBytes,
          title: 'Crop Profile Photo',
        );

        if (croppedBytes != null && mounted) {
          setState(() {
            _pickedImageBytes = croppedBytes;
            _pickedImage = XFile.fromData(
              croppedBytes,
              name: 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.png',
              mimeType: 'image/png',
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recropImage() async {
    if (_rawOriginalImageBytes == null) return;
    try {
      final croppedBytes = await CircularImageCropperDialog.show(
        context,
        imageBytes: _rawOriginalImageBytes!,
        title: 'Crop Profile Photo',
      );

      if (croppedBytes != null && mounted) {
        setState(() {
          _pickedImageBytes = croppedBytes;
          _pickedImage = XFile.fromData(
            croppedBytes,
            name: 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.png',
            mimeType: 'image/png',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a member first.')),
      );
      return;
    }

    if (_selectedCategory == 'photo_update' && _pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach the new profile photo to replace the current one.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userPhone = _selectedMember!.phone;

      // Compile field updates based on category
      final Map<String, dynamic> updates = {};
      String defaultTitle = 'Profile Update Request';

      final cleanedFirms = _firms
          .where((f) =>
              (f['name'] ?? '').trim().isNotEmpty ||
              (f['phone'] ?? '').trim().isNotEmpty ||
              (f['mapLink'] ?? '').trim().isNotEmpty)
          .map((f) => {
                'name': (f['name'] ?? '').trim(),
                'phone': (f['phone'] ?? '').trim(),
                'mapLink': (f['mapLink'] ?? '').trim(),
              })
          .toList();

      if (_selectedCategory == 'all') {
        defaultTitle = 'Full Profile Update Request';

        // Personal
        if (_fullNameController.text.trim().isNotEmpty) updates['fullName'] = _fullNameController.text.trim();
        if (_surnameController.text.trim().isNotEmpty) updates['surname'] = _surnameController.text.trim();
        if (_fatherNameController.text.trim().isNotEmpty) updates['fatherName'] = _fatherNameController.text.trim();
        if (_motherNameController.text.trim().isNotEmpty) updates['motherName'] = _motherNameController.text.trim();
        updates['gender'] = _gender;
        if (_birthDateController.text.trim().isNotEmpty) updates['birthDate'] = _birthDateController.text.trim();
        if (_selectedBloodGroup.isNotEmpty) updates['bloodGroup'] = _selectedBloodGroup;
        if (_selectedMarriageStatus.isNotEmpty) updates['marriageStatus'] = _selectedMarriageStatus;
        if (_nativeHomeController.text.trim().isNotEmpty) updates['nativeHome'] = _nativeHomeController.text.trim();
        if (_gotraController.text.trim().isNotEmpty) updates['gotra'] = _gotraController.text.trim();
        if (_educationController.text.trim().isNotEmpty) updates['education'] = _educationController.text.trim();
        if (_surdhanController.text.trim().isNotEmpty) updates['surdhan'] = _surdhanController.text.trim();

        // Contact
        if (_phoneController.text.trim().isNotEmpty) updates['phone'] = _phoneController.text.trim();
        if (_whatsappController.text.trim().isNotEmpty) updates['whatsapp'] = _whatsappController.text.trim();
        if (_emailController.text.trim().isNotEmpty) updates['email'] = _emailController.text.trim();
        if (_addressController.text.trim().isNotEmpty) updates['address'] = _addressController.text.trim();
        if (_googleMapLinkController.text.trim().isNotEmpty) updates['googleMapLink'] = _googleMapLinkController.text.trim();
        updates['isPublic'] = _isPublic;

        // Social
        if (_instagramController.text.trim().isNotEmpty) updates['instagram'] = _instagramController.text.trim();
        if (_facebookController.text.trim().isNotEmpty) updates['facebook'] = _facebookController.text.trim();
        if (_snapchatController.text.trim().isNotEmpty) updates['snapchat'] = _snapchatController.text.trim();

        // Business
        updates['firms'] = cleanedFirms;

        // Lineage
        updates['relationToHead'] = _relationToHead;
        if (_parentMidController.text.trim().isNotEmpty) updates['parentMid'] = _parentMidController.text.trim();
        if (_spouseMidController.text.trim().isNotEmpty) updates['spouseMid'] = _spouseMidController.text.trim();
        updates['isDeceased'] = _isDeceased;
        if (_isDeceased && _todController.text.trim().isNotEmpty) {
          updates['tod'] = _todController.text.trim();
        } else if (!_isDeceased) {
          updates['tod'] = '';
        }

        if (_pickedImage != null) {
          updates['photo_update_requested'] = true;
        }
      } else if (_selectedCategory == 'photo_update') {
        defaultTitle = 'Profile Photo Replacement Request';
        updates['photo_update_requested'] = true;
      } else if (_selectedCategory == 'contact_info') {
        defaultTitle = 'Contact Information Update';
        if (_phoneController.text.trim().isNotEmpty) updates['phone'] = _phoneController.text.trim();
        if (_whatsappController.text.trim().isNotEmpty) updates['whatsapp'] = _whatsappController.text.trim();
        if (_emailController.text.trim().isNotEmpty) updates['email'] = _emailController.text.trim();
        if (_addressController.text.trim().isNotEmpty) updates['address'] = _addressController.text.trim();
        if (_googleMapLinkController.text.trim().isNotEmpty) updates['googleMapLink'] = _googleMapLinkController.text.trim();
        updates['isPublic'] = _isPublic;
      } else if (_selectedCategory == 'social_media') {
        defaultTitle = 'Social Media Handles Update';
        if (_whatsappController.text.trim().isNotEmpty) updates['whatsapp'] = _whatsappController.text.trim();
        if (_instagramController.text.trim().isNotEmpty) updates['instagram'] = _instagramController.text.trim();
        if (_facebookController.text.trim().isNotEmpty) updates['facebook'] = _facebookController.text.trim();
        if (_snapchatController.text.trim().isNotEmpty) updates['snapchat'] = _snapchatController.text.trim();
      } else if (_selectedCategory == 'personal_details') {
        defaultTitle = 'Personal Details Correction';
        if (_fullNameController.text.trim().isNotEmpty) updates['fullName'] = _fullNameController.text.trim();
        if (_surnameController.text.trim().isNotEmpty) updates['surname'] = _surnameController.text.trim();
        if (_fatherNameController.text.trim().isNotEmpty) updates['fatherName'] = _fatherNameController.text.trim();
        if (_motherNameController.text.trim().isNotEmpty) updates['motherName'] = _motherNameController.text.trim();
        updates['gender'] = _gender;
        if (_birthDateController.text.trim().isNotEmpty) updates['birthDate'] = _birthDateController.text.trim();
        if (_selectedBloodGroup.isNotEmpty) updates['bloodGroup'] = _selectedBloodGroup;
        if (_selectedMarriageStatus.isNotEmpty) updates['marriageStatus'] = _selectedMarriageStatus;
        if (_nativeHomeController.text.trim().isNotEmpty) updates['nativeHome'] = _nativeHomeController.text.trim();
        if (_gotraController.text.trim().isNotEmpty) updates['gotra'] = _gotraController.text.trim();
        if (_educationController.text.trim().isNotEmpty) updates['education'] = _educationController.text.trim();
        if (_surdhanController.text.trim().isNotEmpty) updates['surdhan'] = _surdhanController.text.trim();
      } else if (_selectedCategory == 'business_info') {
        defaultTitle = 'Business & Firm Details Update';
        updates['firms'] = cleanedFirms;
      } else if (_selectedCategory == 'lineage_info') {
        defaultTitle = 'Family Lineage & Relations Update';
        updates['relationToHead'] = _relationToHead;
        if (_parentMidController.text.trim().isNotEmpty) updates['parentMid'] = _parentMidController.text.trim();
        if (_spouseMidController.text.trim().isNotEmpty) updates['spouseMid'] = _spouseMidController.text.trim();
        updates['isDeceased'] = _isDeceased;
        if (_isDeceased && _todController.text.trim().isNotEmpty) {
          updates['tod'] = _todController.text.trim();
        } else if (!_isDeceased) {
          updates['tod'] = '';
        }
      } else {
        defaultTitle = _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'General Member Update Request';
      }

      final request = MemberUpdateRequestModel(
        id: '',
        memberId: _selectedMember!.id,
        memberMid: _selectedMember!.mid,
        memberName: _selectedMember!.fullName,
        familyDocId: _selectedMember!.familyDocId,
        subFamilyDocId: _selectedMember!.subFamilyDocId,
        familyName: _selectedMember!.familyName,
        requestedByPhone: userPhone,
        requestType: _selectedCategory,
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : defaultTitle,
        description: _descriptionController.text.trim(),
        fieldUpdates: updates,
        currentPhotoUrl: _selectedMember!.photoUrl,
        createdAt: DateTime.now(),
      );

      await _updateRequestService.submitRequest(
        request: request,
        newPhotoFile: _pickedImage,
        newPhotoBytes: _pickedImageBytes,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Request Submitted'),
          ],
        ),
        content: const Text(
          'Your update request has been successfully sent to the Samaj administration committee. It will be reviewed and updated shortly.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _pickedImage = null;
                _pickedImageBytes = null;
                _rawOriginalImageBytes = null;
                _descriptionController.clear();
                _titleController.clear();
                _tabController.animateTo(1); // Switch to History tab
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Request Status', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Update Request'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.edit_document), text: 'New Request'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Request History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNewRequestForm(theme, isDark),
                _buildRequestHistoryTab(theme, isDark),
              ],
            ),
    );
  }

  Widget _buildNewRequestForm(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Selector Header
            _buildMemberSelectorCard(theme, isDark),
            const SizedBox(height: 20),

            // Category Selection
            Text(
              'Select What You Want to Update',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoryChips(theme),
            const SizedBox(height: 20),

            // Dynamic Form based on selected category
            if (_selectedCategory == 'all') ...[
              _buildPhotoUpdateSection(theme, isDark),
              const SizedBox(height: 18),
              _buildPersonalDetailsSection(theme, isDark),
              const SizedBox(height: 18),
              _buildContactInfoSection(theme, isDark),
              const SizedBox(height: 18),
              _buildSocialMediaSection(theme, isDark),
              const SizedBox(height: 18),
              _buildBusinessSection(theme, isDark),
              const SizedBox(height: 18),
              _buildFamilyLineageSection(theme, isDark),
            ] else if (_selectedCategory == 'photo_update')
              _buildPhotoUpdateSection(theme, isDark)
            else if (_selectedCategory == 'contact_info')
              _buildContactInfoSection(theme, isDark)
            else if (_selectedCategory == 'social_media')
              _buildSocialMediaSection(theme, isDark)
            else if (_selectedCategory == 'personal_details')
              _buildPersonalDetailsSection(theme, isDark)
            else if (_selectedCategory == 'business_info')
              _buildBusinessSection(theme, isDark)
            else if (_selectedCategory == 'lineage_info')
              _buildFamilyLineageSection(theme, isDark)
            else
              _buildGeneralRequestSection(theme, isDark),

            const SizedBox(height: 20),

            // Description / Admin Notes Card
            _buildDescriptionCard(theme, isDark),
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitRequest,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Uploading & Submitting...' : 'Submit Update Request',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E), // Teal
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSelectorCard(ThemeData theme, bool isDark) {
    if (_selectedMember == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                backgroundImage: _selectedMember!.photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(_selectedMember!.photoUrl)
                    : null,
                child: _selectedMember!.photoUrl.isEmpty
                    ? Text(
                        _selectedMember!.fullName.isNotEmpty ? _selectedMember!.fullName[0].toUpperCase() : '?',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 20),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedMember!.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'MID: ${_selectedMember!.mid} • ${_selectedMember!.familyName}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_familyMembers.length > 1) ...[
            const SizedBox(height: 12),
            const Divider(),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _familyMembers.any((m) => m.id == _selectedMember?.id)
                    ? _selectedMember?.id
                    : (_familyMembers.isNotEmpty ? _familyMembers.first.id : null),
                hint: const Text('Change family member'),
                items: _familyMembers.map((m) {
                  return DropdownMenuItem<String>(
                    value: m.id,
                    child: Text('Update for: ${m.fullName} (${m.mid})'),
                  );
                }).toList(),
                onChanged: (newId) {
                  if (newId != null) {
                    final found = _familyMembers.where((m) => m.id == newId).firstOrNull;
                    if (found != null) {
                      setState(() {
                        _selectedMember = found;
                        _pickedImage = null;
                        _pickedImageBytes = null;
                        _rawOriginalImageBytes = null;
                        _populateFieldsFromMember(found);
                      });
                    }
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChips(ThemeData theme) {
    final categories = [
      {'id': 'all', 'label': '⭐ All Fields (Full Profile)', 'icon': Icons.tune_rounded},
      {'id': 'personal_details', 'label': '👤 Personal Details', 'icon': Icons.badge_outlined},
      {'id': 'contact_info', 'label': '📞 Contact & Address', 'icon': Icons.phone_outlined},
      {'id': 'social_media', 'label': '🌐 Social Handles', 'icon': Icons.share_rounded},
      {'id': 'business_info', 'label': '💼 Business & Firms', 'icon': Icons.business_outlined},
      {'id': 'lineage_info', 'label': '🌳 Family & Lineage', 'icon': Icons.account_tree_outlined},
      {'id': 'photo_update', 'label': '📸 Profile Photo', 'icon': Icons.camera_alt_outlined},
      {'id': 'general', 'label': '📝 Other / Notes', 'icon': Icons.description_outlined},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat['label'] as String),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedCategory = cat['id'] as String);
                }
              },
              selectedColor: const Color(0xFF0F766E),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 1. PHOTO UPDATE SECTION (Allows side-by-side or comparison preview)
  Widget _buildPhotoUpdateSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Replace Profile Photo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Attach the new high-resolution photo you want to replace your current photo with.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // Comparison / Upload Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Current Photo
              Flexible(
                child: Column(
                  children: [
                    const Text(
                      'Current Photo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                        image: _selectedMember != null && _selectedMember!.photoUrl.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(_selectedMember!.photoUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedMember == null || _selectedMember!.photoUrl.isEmpty
                          ? const Icon(Icons.person, size: 45, color: Colors.grey)
                          : null,
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F766E), size: 24),
              ),

              // New Attached Photo
              Flexible(
                child: Column(
                  children: [
                    const Text(
                      'New Replacement',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showImageSourceSheet(),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          border: Border.all(
                            color: _pickedImage != null ? const Color(0xFF10B981) : Colors.teal.shade300,
                            width: 2.5,
                          ),
                          image: _pickedImageBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(_pickedImageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _pickedImageBytes == null && _pickedImage == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: Color(0xFF0F766E), size: 28),
                                  SizedBox(height: 4),
                                  Text('Attach', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Attachment Action Buttons (Responsive to prevent pixel overlap)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Gallery'),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Take Photo'),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          if (_pickedImage != null || _pickedImageBytes != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_rawOriginalImageBytes != null) ...[
                  TextButton.icon(
                    onPressed: _recropImage,
                    icon: const Icon(Icons.crop_rotate_rounded, color: Color(0xFF0F766E), size: 18),
                    label: const Text(
                      'Adjust Circular Crop',
                      style: TextStyle(color: Color(0xFF0F766E), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                TextButton.icon(
                  onPressed: () => setState(() {
                    _pickedImage = null;
                    _pickedImageBytes = null;
                    _rawOriginalImageBytes = null;
                  }),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('Remove photo', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
              title: const Text('Select from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.teal),
              title: const Text('Take a New Photo (Camera)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 2. CONTACT INFO FORM
  Widget _buildContactInfoSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact & Address Updates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile Phone Number',
              prefixIcon: Icon(Icons.phone_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Number',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addressController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Residential Address',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _googleMapLinkController,
            decoration: const InputDecoration(
              labelText: 'Google Maps Link (Optional)',
              prefixIcon: Icon(Icons.map_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _isPublic ? Colors.teal.shade50 : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isPublic ? Colors.teal.shade300 : (isDark ? Colors.white12 : Colors.grey.shade200)),
            ),
            child: SwitchListTile(
              value: _isPublic,
              onChanged: (val) => setState(() => _isPublic = val),
              title: const Text('Public Profile Visibility / સાર્વજનિક પ્રોફાઇલ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Show phone number and basic details to Explore Mode visitors', style: TextStyle(fontSize: 11)),
              secondary: Icon(Icons.public_rounded, color: _isPublic ? Colors.teal.shade700 : Colors.grey),
              activeColor: Colors.teal.shade700,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  // 3. PERSONAL DETAILS FORM
  Widget _buildPersonalDetailsSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: Color(0xFF0F766E), size: 20),
              const SizedBox(width: 8),
              const Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'First & Middle Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _surnameController,
                  decoration: const InputDecoration(
                    labelText: 'Surname',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fatherNameController,
                  decoration: const InputDecoration(
                    labelText: 'Father Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _motherNameController,
                  decoration: const InputDecoration(
                    labelText: 'Mother Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gender == 'female' ? 'female' : 'male',
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _bloodGroups.contains(_selectedBloodGroup) ? _selectedBloodGroup : 'B+',
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: Icon(Icons.bloodtype_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                  onChanged: (v) => setState(() => _selectedBloodGroup = v ?? 'B+'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _marriageStatuses.contains(_selectedMarriageStatus) ? _selectedMarriageStatus : 'unmarried',
                  decoration: const InputDecoration(
                    labelText: 'Marital Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  items: _marriageStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _selectedMarriageStatus = v ?? 'unmarried'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Birth Date (DD/MM/YYYY)',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nativeHomeController,
                  decoration: const InputDecoration(
                    labelText: 'Native Home / Village',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _gotraController,
                  decoration: const InputDecoration(
                    labelText: 'Gotra',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _educationController,
                  decoration: const InputDecoration(
                    labelText: 'Education',
                    prefixIcon: Icon(Icons.school_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _surdhanController,
                  decoration: const InputDecoration(
                    labelText: 'Surdhan (સૂરધન)',
                    prefixIcon: Icon(Icons.temple_hindu_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. SOCIAL MEDIA FORM
  Widget _buildSocialMediaSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share_rounded, color: Color(0xFF0F766E), size: 20),
              const SizedBox(width: 8),
              const Text('Social Media Handles & Links', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep your social profiles updated for Samaj member connectivity.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Number',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
              hintText: 'e.g., 9876543210',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _instagramController,
            decoration: const InputDecoration(
              labelText: 'Instagram Profile / Username',
              prefixIcon: Icon(Icons.camera_alt_outlined, color: Colors.purple),
              hintText: 'e.g., your_username or https://instagram.com/username',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _facebookController,
            decoration: const InputDecoration(
              labelText: 'Facebook Profile / Username',
              prefixIcon: Icon(Icons.facebook, color: Colors.blue),
              hintText: 'e.g., profile name or facebook profile link',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _snapchatController,
            decoration: const InputDecoration(
              labelText: 'Snapchat ID / Username',
              prefixIcon: Icon(Icons.chat_outlined, color: Colors.amber),
              hintText: 'e.g., snapchat_username or snapchat.com/add/username',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  // 5. BUSINESS & FIRMS FORM (MULTI-FIRMS)
  Widget _buildBusinessSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.business_outlined, color: Color(0xFF0F766E), size: 20),
                  SizedBox(width: 8),
                  Text('Business & Firm Profiles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _firms.add({'name': '', 'phone': '', 'mapLink': ''});
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Firm'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F766E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'List one or more community businesses or professional offices.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_firms.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Text('No business firms added yet.'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _firms.add({'name': '', 'phone': '', 'mapLink': ''});
                    }),
                    icon: const Icon(Icons.add_business_rounded, size: 18),
                    label: const Text('Add Business Firm'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._firms.asMap().entries.map((entry) {
              final index = entry.key;
              final firm = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Business Firm #${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                        ),
                        if (_firms.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => setState(() => _firms.removeAt(index)),
                            tooltip: 'Remove this firm',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: firm['name'],
                      decoration: const InputDecoration(
                        labelText: 'Business / Firm Name',
                        prefixIcon: Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) => _firms[index]['name'] = val,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: firm['phone'],
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact Phone',
                              prefixIcon: Icon(Icons.phone_in_talk_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) => _firms[index]['phone'] = val,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: firm['mapLink'],
                            decoration: const InputDecoration(
                              labelText: 'Map Link (Optional)',
                              prefixIcon: Icon(Icons.map_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) => _firms[index]['mapLink'] = val,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _firms.add({'name': '', 'phone': '', 'mapLink': ''});
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Another Business Firm'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 6. FAMILY LINEAGE & RELATIONS FORM
  Widget _buildFamilyLineageSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: Color(0xFF0F766E), size: 20),
              const SizedBox(width: 8),
              const Text('Family Tree & Lineage Relations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Link this member to parents, spouse, and their relationship hierarchy in the family tree.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Relation to Head
          DropdownButtonFormField<String>(
            value: _relationOptions.any((r) => r['value'] == _relationToHead) ? _relationToHead : 'none',
            decoration: const InputDecoration(
              labelText: 'Relationship to Family Head',
              prefixIcon: Icon(Icons.group_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            items: _relationOptions.map((r) {
              return DropdownMenuItem<String>(
                value: r['value'],
                child: Text(r['label']!),
              );
            }).toList(),
            onChanged: (v) => setState(() => _relationToHead = v ?? 'none'),
          ),
          const SizedBox(height: 14),

          // Spouse MID Selection / Input
          TextFormField(
            controller: _spouseMidController,
            decoration: const InputDecoration(
              labelText: 'Spouse Member ID (MID) (Optional)',
              prefixIcon: Icon(Icons.favorite_outline),
              hintText: 'e.g., F01-S01-002',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 16),

          // Late / Deceased Toggle
          Container(
            decoration: BoxDecoration(
              color: _isDeceased ? Colors.red.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isDeceased ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
            ),
            child: SwitchListTile(
              title: const Text(
                'Mark as Late / Deceased Member (સ્વર્ગસ્થ)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'For deceased family members, contact numbers & login access are disabled.',
                style: TextStyle(fontSize: 12),
              ),
              value: _isDeceased,
              activeColor: Colors.red,
              onChanged: (val) => setState(() => _isDeceased = val),
            ),
          ),

          if (_isDeceased) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _todController,
              decoration: const InputDecoration(
                labelText: 'Date / Time of Death (TOD) (DD/MM/YYYY)',
                prefixIcon: Icon(Icons.event_busy_outlined, color: Colors.red),
                hintText: 'e.g., 15/08/2020',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 7. GENERAL REQUEST FORM
  Widget _buildGeneralRequestSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('General Correction / Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Request Title',
              hintText: 'e.g., Update family tree link or correct spellings',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Additional Notes for Committee (Optional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Explain the reason or any extra instructions for the admin...',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: REQUEST HISTORY
  Widget _buildRequestHistoryTab(ThemeData theme, bool isDark) {
    if (_selectedMember == null) {
      return const Center(child: Text('No active member selected.'));
    }

    return StreamBuilder<List<MemberUpdateRequestModel>>(
      stream: _updateRequestService.streamUserRequests(_selectedMember!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No Requests Submitted Yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Any change requests you submit will appear here.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = requests[index];
            return _buildRequestStatusCard(req, theme, isDark);
          },
        );
      },
    );
  }

  Widget _buildRequestStatusCard(MemberUpdateRequestModel req, ThemeData theme, bool isDark) {
    Color statusColor = Colors.orange;
    String statusText = 'PENDING REVIEW';
    IconData statusIcon = Icons.hourglass_top_rounded;

    if (req.status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusText = 'APPROVED';
      statusIcon = Icons.check_circle_rounded;
    } else if (req.status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'REJECTED';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  req.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Member: ${req.memberName} (${req.memberMid})',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (req.newPhotoUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: req.newPhotoUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('New Photo Attached', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (req.fieldUpdates.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildFieldUpdatesPreview(req.fieldUpdates, isDark),
          ],
          if (req.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              req.description,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
          if (req.adminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Admin Note: ${req.adminNote}',
                style: const TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Submitted on ${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldUpdatesPreview(Map<String, dynamic> fieldUpdates, bool isDark) {
    final entries = fieldUpdates.entries.where((e) => e.key != 'photo_update_requested').toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Requested Changes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...entries.map((entry) {
            if (entry.key == 'firms') {
              final list = entry.value is List ? (entry.value as List) : [];
              if (list.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• Business Firms (${list.length}): ${list.map((f) => (f is Map ? f['name'] : '')).where((n) => n.toString().isNotEmpty).join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }

            String label = entry.key;
            if (label == 'fullName') label = 'Full Name';
            if (label == 'surname') label = 'Surname';
            if (label == 'fatherName') label = 'Father Name';
            if (label == 'motherName') label = 'Mother Name';
            if (label == 'gender') label = 'Gender';
            if (label == 'birthDate') label = 'Birth Date';
            if (label == 'bloodGroup') label = 'Blood Group';
            if (label == 'marriageStatus') label = 'Marital Status';
            if (label == 'nativeHome') label = 'Native Village';
            if (label == 'gotra') label = 'Gotra';
            if (label == 'education') label = 'Education';
            if (label == 'surdhan') label = 'Surdhan';
            if (label == 'phone') label = 'Phone Number';
            if (label == 'whatsapp') label = 'WhatsApp';
            if (label == 'email') label = 'Email';
            if (label == 'address') label = 'Address';
            if (label == 'googleMapLink') label = 'Map Link';
            if (label == 'instagram') label = 'Instagram';
            if (label == 'facebook') label = 'Facebook';
            if (label == 'snapchat') label = 'Snapchat';
            if (label == 'relationToHead') label = 'Relation to Head';
            if (label == 'parentMid') label = 'Parent MID';
            if (label == 'spouseMid') label = 'Spouse MID';
            if (label == 'isDeceased') label = 'Late / Deceased';
            if (label == 'tod') label = 'Date of Death';

            String val = entry.value.toString();
            if (entry.key == 'isDeceased') {
              val = (entry.value == true || entry.value.toString() == 'true') ? 'Yes (Deceased)' : 'No (Living)';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• $label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  Expanded(child: Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
