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

  @override
  void initState() {
    super.initState();
    if (widget.initialParentMid != null) {
      _parentMidCtrl.text = widget.initialParentMid!;
    }
    _checkExistingHead();
    _loadFirmNames();
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

      await MemberService().addMember(
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
        gender: _gender, // Added
        birthDate: _birthDateCtrl.text.trim(),
        education: _educationCtrl.text.trim(), // Added
        bloodGroup: _bloodGroup,
        marriageStatus: _marriageStatus,
        nativeHome: _nativeHomeCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(), // Added
        address: _addressCtrl.text.trim(),
        googleMapLink: _googleMapLinkCtrl.text.trim(),
        surdhan: _surdhanCtrl.text.trim(), // Added
        firms: _firms,
        whatsapp: _whatsappCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim(),
        facebook: _facebookCtrl.text.trim(),
        tags: _tags,
        parentMid: _parentMidCtrl.text.trim(),
        password: _passwordCtrl.text.trim().isEmpty ? '123456' : _passwordCtrl.text.trim(), // Added
        photoUrl: photoUrl,
        relationToHead: _relationToHead,
        subFamilyHeadRelationToMainHead: _subFamilyHeadRelation,
      );

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
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickProfilePhoto,
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.blue.shade900,
                            backgroundImage:
                                _profilePhotoUrl != null &&
                                    _profilePhotoUrl!.isNotEmpty
                                ? (_profilePhotoUrl!.startsWith('http')
                                      ? CachedNetworkImageProvider(_profilePhotoUrl!) as ImageProvider
                                      : FileImage(File(_profilePhotoUrl!)))
                                : null,
                            child:
                                _profilePhotoUrl == null ||
                                    _profilePhotoUrl!.isEmpty
                                ? const Icon(
                                    Icons.camera_alt,
                                    size: 36,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.translate('tap_to_add_photo'),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personal Info
                  Text(
                    lang.translate('personal_information'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullNameCtrl,
                    decoration: InputDecoration(labelText: '${lang.translate('full_name')} *'),
                    validator: (v) =>
                        v == null || v.isEmpty ? lang.translate('required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _surnameCtrl,
                    decoration: InputDecoration(labelText: lang.translate('surname')),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fatherNameCtrl,
                    decoration: InputDecoration(labelText: lang.translate('father_name')),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _motherNameCtrl,
                    decoration: InputDecoration(labelText: lang.translate('mother_name')),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _gotraCtrl,
                    decoration: InputDecoration(labelText: lang.translate('gotra')),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: '${lang.translate('member_login_password')} *',
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.length != 8 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v)) 
                      ? lang.translate('must_be_8_chars') : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: InputDecoration(labelText: lang.translate('gender')),
                    items: ['male', 'female']
                        .map((g) => DropdownMenuItem(value: g, child: Text(lang.translate(g))))
                        .toList(),
                    onChanged: (v) => setState(() => _gender = v ?? 'male'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _educationCtrl,
                    decoration: InputDecoration(
                      labelText: lang.translate('education'),
                      hintText: 'e.g., B.Tech, MBA',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _birthDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Birth Date (dd/MM/yyyy) *',
                      hintText: '15/08/1990',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _bloodGroup.isEmpty ? null : _bloodGroup,
                    decoration: const InputDecoration(labelText: 'Blood Group'),
                    items:
                        ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                            .map(
                              (bg) => DropdownMenuItem(
                                value: bg,
                                child: Text(bg.isEmpty ? 'Select' : bg),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _bloodGroup = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _marriageStatus,
                    decoration: const InputDecoration(
                      labelText: 'Marriage Status',
                    ),
                    items: ['unmarried', 'married']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _marriageStatus = v ?? 'unmarried'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nativeHomeCtrl,
                    decoration: const InputDecoration(labelText: 'Native Home'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _surdhanCtrl,
                    decoration: const InputDecoration(labelText: 'Surdhan'),
                  ),

                  // Contact Info
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('contact_information'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(labelText: '${lang.translate('phone')} *'),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'E-mail ID'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: InputDecoration(labelText: lang.translate('address')),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _googleMapLinkCtrl,
                    decoration: InputDecoration(
                      labelText: lang.translate('google_map_link'),
                      hintText: 'https://maps.google.com/...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _whatsappCtrl,
                    decoration: InputDecoration(labelText: lang.translate('whatsapp')),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instagramCtrl,
                    decoration: InputDecoration(labelText: lang.translate('instagram')),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _facebookCtrl,
                    decoration: InputDecoration(labelText: lang.translate('facebook')),
                  ),

                  // Firms/Business Details
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('firms_business'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._firms.asMap().entries.map((entry) {
                    final index = entry.key;
                    final firm = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
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
                                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                        });
                                      },
                                      onSelected: (String selection) {
                                        setState(() {
                                          _firms[index]['name'] = selection;
                                        });
                                      },
                                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                        if (controller.text != firm['name']) {
                                          controller.text = firm['name'] ?? '';
                                        }
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                            labelText: lang.translate('firm_name'),
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (value) {
                                            _firms[index]['name'] = value;
                                          },
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
                                              color: Colors.white,
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
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _firms.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          TextFormField(
                            initialValue: firm['phone'],
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              _firms[index]['phone'] = value;
                            },
                          ),
                          TextFormField(
                            initialValue: firm['mapLink'],
                            decoration: const InputDecoration(
                              labelText: 'Map Link',
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              _firms[index]['mapLink'] = value;
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _firms.add({'name': '', 'phone': '', 'mapLink': ''});
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(lang.translate('add_firm')),
                  ),

                  // Family Information
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('family_information'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dktFamilyIdCtrl,
                    decoration: InputDecoration(
                      labelText: lang.translate('dkt_family_id'),
                      hintText: 'Enter DKT Family ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _parentMidCtrl,
                    decoration: InputDecoration(
                      labelText: lang.translate('parent_member_id'),
                      hintText: 'Enter parent MID (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Relation to Head
                  DropdownButtonFormField<String>(
                    value: _relationToHead,
                    decoration: InputDecoration(
                      labelText: lang.translate('relation_to_head'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(lang.translate('none')),
                      ),
                      DropdownMenuItem(
                        value: 'head',
                        enabled: !_hasFamilyHead,
                        child: Text(
                          lang.translate('head_of_family') + 
                          (_hasFamilyHead ? ' (Already Assigned)' : ''),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'wife',
                        child: Text(lang.translate('wife')),
                      ),
                      DropdownMenuItem(
                        value: 'daughter',
                        child: Text(lang.translate('daughter')),
                      ),
                      DropdownMenuItem(
                        value: 'son',
                        child: Text(lang.translate('son')),
                      ),
                      DropdownMenuItem(
                        value: 'daughter_in_law',
                        child: Text(lang.translate('daughter_in_law')),
                      ),
                      DropdownMenuItem(
                        value: 'grandson',
                        child: Text(lang.translate('grandson')),
                      ),
                      DropdownMenuItem(
                        value: 'grandsister',
                        child: Text(lang.translate('grandsister')),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _relationToHead = val ?? 'none';
                      });
                    },
                  ),
                  
                  if (_relationToHead == 'head' && widget.subFamilyDocId != null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: lang.translate('relation_to_main_head'),
                        hintText: 'Relationship of this head with main head (e.g. Son)',
                      ),
                      onChanged: (val) {
                        setState(() {
                          _subFamilyHeadRelation = val;
                        });
                      },
                    ),
                  ],

                  // Tags (Admin Only)
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('tags'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Visible tag input field
                  TextFormField(
                    controller: _tagsCtrl,
                    decoration: InputDecoration(
                      labelText: lang.translate('add_tag'),
                      hintText: 'Enter tag and press + button',
                    ),
                    maxLength: 15,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: const SizedBox.shrink(), // Empty space
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final v = _tagsCtrl.text.trim();
                          if (v.isNotEmpty &&
                              v.length <= 15 &&
                              !_tags.contains(v)) {
                            setState(() {
                              _tags.add(v);
                              _tagsCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: _tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: Text(lang.translate('add_member')),
                  ),
                  const SizedBox(height: 24),
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
                    style: TextStyle(
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

  final PhotoService _photoService = PhotoService();

  @override
  void initState() {
    super.initState();
    _loadMemberData();
    _checkExistingHead();
    _loadFirmNames();
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
      _alreadyHead = _relationToHead == 'head';
      if (_memberMid.isEmpty) {
        _memberMid = MemberModel.generateMid(member.familyId, member.subFamilyId);
      }
    }
    setState(() => _loading = false);
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
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.blue.shade900,
                        backgroundImage:
                            _profilePhotoUrl != null &&
                                _profilePhotoUrl!.isNotEmpty
                            ? (_profilePhotoUrl!.startsWith('http')
                                  ? CachedNetworkImageProvider(_profilePhotoUrl!) as ImageProvider
                                  : FileImage(File(_profilePhotoUrl!)))
                            : null,
                        child:
                            _profilePhotoUrl == null ||
                                _profilePhotoUrl!.isEmpty
                            ? const Icon(
                                Icons.camera_alt,
                                size: 36,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change profile photo',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _profilePhotoUrl = null;
                        _pendingPhotoPath = null;
                      });
                    },
                    child: const Text(
                      'Remove Photo',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Personal Information
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'MID: $_memberMid',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _surnameCtrl,
                decoration: const InputDecoration(labelText: 'Surname'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fatherNameCtrl,
                decoration: const InputDecoration(labelText: 'Father Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motherNameCtrl,
                decoration: const InputDecoration(labelText: 'Mother Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gotraCtrl,
                decoration: const InputDecoration(labelText: 'Gotra'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _birthDateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Birth Date (dd/MM/yyyy)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Member Login Password *',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (v) => (v == null || v.length != 8 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v)) 
                  ? 'Must be 8 alphanumeric characters' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: InputDecoration(labelText: lang.translate('gender')),
                items: ['male', 'female']
                    .map((g) => DropdownMenuItem(value: g, child: Text(lang.translate(g))))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v ?? 'male'),
              ),
              const SizedBox(height: 12),
              // Education Field
              TextFormField(
                controller: _educationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Education',
                  hintText: 'e.g., B.Tech, MBA',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _bloodGroup.isEmpty ? null : _bloodGroup,
                decoration: const InputDecoration(labelText: 'Blood Group'),
                items: ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                    .map(
                      (bg) => DropdownMenuItem(
                        value: bg,
                        child: Text(bg.isEmpty ? 'Select' : bg),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _bloodGroup = v ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _marriageStatus,
                decoration: const InputDecoration(labelText: 'Marriage Status'),
                items: ['unmarried', 'married']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _marriageStatus = v ?? 'unmarried'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nativeHomeCtrl,
                decoration: const InputDecoration(labelText: 'Native Home'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _surdhanCtrl,
                decoration: const InputDecoration(labelText: 'Surdhan'),
              ),

              // Contact Information
              const SizedBox(height: 20),
              const Text(
                'Contact Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'E-mail ID'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _googleMapLinkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Google Map Link',
                  hintText: 'https://maps.google.com/...',
                ),
              ),

              // Social Media
              const SizedBox(height: 20),
              const Text(
                'Social Media',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Changed Row to Wrap to prevent overflow
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 20,
                runSpacing: 10,
                children: [
                  // WhatsApp
                  Column(
                    children: [
                      IconButton(
                        onPressed: _whatsappCtrl.text.trim().isNotEmpty
                            ? _launchWhatsApp
                            : null,
                        icon: const Icon(Icons.message, color: Colors.teal),
                        iconSize: 40,
                      ),
                      const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  // Instagram
                  Column(
                    children: [
                      IconButton(
                        onPressed: _instagramCtrl.text.trim().isNotEmpty
                            ? _launchInstagram
                            : null,
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.purple,
                        ),
                        iconSize: 40,
                      ),
                      const Text('Instagram', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  // Facebook
                  Column(
                    children: [
                      IconButton(
                        onPressed: _facebookCtrl.text.trim().isNotEmpty
                            ? _launchFacebook
                            : null,
                        icon: const Icon(Icons.facebook, color: Colors.blue),
                        iconSize: 40,
                      ),
                      const Text('Facebook', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              // Hidden text fields for storing values
              TextFormField(
                controller: _whatsappCtrl,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() {}),
              ),
              TextFormField(
                controller: _instagramCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instagram Username',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() {}),
              ),
              TextFormField(
                controller: _facebookCtrl,
                decoration: const InputDecoration(
                  labelText: 'Facebook Username',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() {}),
              ),

              // Firms/Business Details
              const SizedBox(height: 20),
              const Text(
                'Firms / Business Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._firms.asMap().entries.map((entry) {
                final index = entry.key;
                final firm = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
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
                                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                    });
                                  },
                                  onSelected: (String selection) {
                                    setState(() {
                                      _firms[index]['name'] = selection;
                                    });
                                  },
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    if (controller.text != firm['name']) {
                                      controller.text = firm['name'] ?? '';
                                    }
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Firm Name',
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (value) {
                                        _firms[index]['name'] = value;
                                      },
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
                                          color: Colors.white,
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
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _firms.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                      TextFormField(
                        initialValue: firm['phone'],
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          _firms[index]['phone'] = value;
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: firm['mapLink'],
                              decoration: const InputDecoration(
                                labelText: 'Map Link',
                                border: InputBorder.none,
                              ),
                              onChanged: (value) {
                                _firms[index]['mapLink'] = value;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.map, color: Colors.blue),
                            onPressed: firm['mapLink']?.isNotEmpty == true
                                ? () => _launchMap(firm['mapLink']!)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _firms.add({'name': '', 'phone': '', 'mapLink': ''});
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Firm'),
              ),

              // Family Information
              const SizedBox(height: 20),
              Text(
                lang.translate('family_information'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dktFamilyIdCtrl,
                decoration: InputDecoration(
                  labelText: lang.translate('dkt_family_id'),
                  hintText: 'Enter DKT Family ID',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _parentMidCtrl,
                decoration: InputDecoration(
                  labelText: lang.translate('parent_member_id'),
                  hintText: 'Enter parent MID (optional)',
                ),
              ),
              const SizedBox(height: 12),
              
              // Relation to Head
              DropdownButtonFormField<String>(
                value: _relationToHead,
                decoration: InputDecoration(
                  labelText: lang.translate('relation_to_head'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text(lang.translate('none')),
                  ),
                  DropdownMenuItem(
                    value: 'head',
                    enabled: !_hasFamilyHead || _alreadyHead,
                    child: Text(
                      lang.translate('head_of_family') + 
                      ((_hasFamilyHead && !_alreadyHead) ? ' (Already Assigned)' : ''),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'wife',
                    child: Text(lang.translate('wife')),
                  ),
                  DropdownMenuItem(
                    value: 'daughter',
                    child: Text(lang.translate('daughter')),
                  ),
                  DropdownMenuItem(
                    value: 'son',
                    child: Text(lang.translate('son')),
                  ),
                  DropdownMenuItem(
                    value: 'daughter_in_law',
                    child: Text(lang.translate('daughter_in_law')),
                  ),
                  DropdownMenuItem(
                    value: 'grandson',
                    child: Text(lang.translate('grandson')),
                  ),
                  DropdownMenuItem(
                    value: 'grandsister',
                    child: Text(lang.translate('grandsister')),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _relationToHead = val ?? 'none';
                  });
                },
              ),
              
              if (_relationToHead == 'head' && widget.subFamilyDocId != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _subFamilyHeadRelation,
                  decoration: InputDecoration(
                    labelText: lang.translate('relation_to_main_head'),
                    hintText: 'Relationship of this head with main head (e.g. Son)',
                  ),
                  onChanged: (val) {
                    setState(() {
                      _subFamilyHeadRelation = val;
                    });
                  },
                ),
              ],

              // Tags
              const SizedBox(height: 20),
              const Text(
                'Tags',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Visible tag input field
              TextFormField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Add Tag (max 15 chars)',
                  hintText: 'Enter tag and press + button',
                ),
                maxLength: 15,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: const SizedBox.shrink(), // Empty space
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final v = _tagsCtrl.text.trim();
                      if (v.isNotEmpty &&
                          v.length <= 15 &&
                          !_tags.contains(v)) {
                        setState(() {
                          _tags.add(v);
                          _tagsCtrl.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
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
                      setState(() => _loading = false);
                      if (mounted) {
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
                        'gender': _gender, // Added
                        'birthDate': _birthDateCtrl.text.trim(),
                        'education': _educationCtrl.text.trim(), // Added
                        'bloodGroup': _bloodGroup,
                        'marriageStatus': _marriageStatus,
                        'nativeHome': _nativeHomeCtrl.text.trim(),
                        'mid': _memberMid, // Ensure MID is saved
                        'phone': _phoneCtrl.text.trim(),
                        'email': _emailCtrl.text.trim(), // Added
                        'address': _addressCtrl.text.trim(),
                        'googleMapLink': _googleMapLinkCtrl.text.trim(),
                        'surdhan': _surdhanCtrl.text.trim(), // Added
                        'whatsapp': _whatsappCtrl.text.trim(),
                        'instagram': _instagramCtrl.text.trim(),
                        'facebook': _facebookCtrl.text.trim(),
                        'firms': _firms,
                        'tags': _tags,
                        'parentMid': _parentMidCtrl.text.trim(),
                        'password': _passwordCtrl.text.trim(), // Added
                        'familyId': _dktFamilyIdCtrl.text.trim(),
                        'photoUrl': photoUrl,
                        'relationToHead': _relationToHead,
                        'subFamilyHeadRelationToMainHead': _subFamilyHeadRelation,
                      },
                    );

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    setState(() => _loading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating member: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Update Member'),
              ),
              const SizedBox(height: 24),
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
                            child: const Icon(
                              Icons.people,
                              color: Colors.white,
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
                                      color: Colors.blue.shade900,
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
