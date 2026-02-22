// lib/screens/user/digital_id_screen.dart

import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/member_model.dart';
import '../../services/language_service.dart';

class DigitalIdScreen extends StatefulWidget {
  final MemberModel member;

  const DigitalIdScreen({super.key, required this.member});

  @override
  State<DigitalIdScreen> createState() => _DigitalIdScreenState();
}

class _DigitalIdScreenState extends State<DigitalIdScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;


  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('digital_id')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isSharing) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _saveToGallery(lang),
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () => _shareCardAsImage(lang),
            ),
          ],
        ],
      ),


      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.secondary.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // THE ID CARD
                RepaintBoundary(
                  key: _boundaryKey,
                  child: _buildIdCard(context, lang, theme),
                ),
                
                const SizedBox(height: 40),

                
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    lang.translate('community_pride'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdCard(BuildContext context, LanguageService lang, ThemeData theme) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF122C4F), // Forced dark background (Midnight)
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D1E36),
                  Color(0xFF122C4F),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.member.familyName.toUpperCase(),

                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        lang.translate('digital_id'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Photo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF5B88B2), width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5B88B2).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: widget.member.photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(widget.member.photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.member.photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 60, color: Color(0xFF5B88B2))
                      : null,
                ),
                
                const SizedBox(height: 16),
                
                // Name and MID
                Text(
                  widget.member.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFBF9E4), // Pearl Perfect text
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.member.surname.isNotEmpty)
                  Text(
                    widget.member.surname,

                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5B88B2), // Ocean secondary
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B88B2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'MID: ${widget.member.mid}',

                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5B88B2),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                // Watermark moved here
                Opacity(
                  opacity: 0.6, // Increased opacity for better visibility
                  child: Text(
                    "Ramanagara Patidar Samaj".toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFBF9E4), // Pearl Perfect color
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 16),
                
                // Details Grid
                _buildDetailsSection(lang),


                
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 16),
                
                // QR Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: jsonEncode({
                          'type': 'member',
                          'mid': widget.member.mid,
                          'memberId': widget.member.id,
                          'familyDocId': widget.member.familyDocId,
                          'subFamilyDocId': widget.member.subFamilyDocId,
                          'fullName': widget.member.fullName,
                          'phone': widget.member.phone,
                        }),

                        version: QrVersions.auto,
                        size: 140.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFFFBF9E4),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFFFBF9E4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lang.translate('scan_to_save_contact'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(LanguageService lang) {
    return Column(
      children: [
        // Row 1: Blood Group & Birth Date
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                lang.translate('blood_group'),
                widget.member.bloodGroup.isNotEmpty ? widget.member.bloodGroup : '-',
                Icons.bloodtype,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailItem(
                lang.translate('birth_date'),
                widget.member.birthDate.isNotEmpty ? widget.member.birthDate : '-',
                Icons.cake,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Row 2: Father & Mother
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                lang.translate('father_name'),
                widget.member.fatherName.isNotEmpty ? widget.member.fatherName : '-',
                Icons.person,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailItem(
                lang.translate('mother_name'),
                widget.member.motherName.isNotEmpty ? widget.member.motherName : '-',
                Icons.person_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Row 3: Age & Education
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                lang.translate('age'),
                '${widget.member.age} ${lang.translate('years')}',
                Icons.cake,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailItem(
                lang.translate('education'),
                widget.member.education.isNotEmpty ? widget.member.education : '-',
                Icons.school,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        
        // Row 4: Native Home & Marriage Status
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                lang.translate('native_home'),
                widget.member.nativeHome.isNotEmpty ? widget.member.nativeHome : '-',
                Icons.home,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailItem(
                lang.translate('marriage_status'),
                lang.translate(widget.member.marriageStatus),
                Icons.favorite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Row 5: Phone & Address
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                lang.translate('phone'),
                widget.member.phone.isNotEmpty ? widget.member.phone : '-',
                Icons.phone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailItem(
                lang.translate('address'),
                widget.member.address.isNotEmpty
                    ? (widget.member.address.length > 20
                        ? '${widget.member.address.substring(0, 20)}...'
                        : widget.member.address)
                    : '-',
                Icons.location_on,
              ),
            ),
          ],
        ),

      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFFFBF9E4).withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFBF9E4),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<String?> _captureImage() async {
    try {
      final RenderRepaintBoundary boundary = _boundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/digital_id_${widget.member.mid}.png';
      final file = await File(path).create();
      await file.writeAsBytes(pngBytes);
      return path;
    } catch (e) {
      debugPrint('Error capturing image: $e');
      return null;
    }
  }

  Future<void> _saveToGallery(LanguageService lang) async {
    setState(() => _isSharing = true);
    await Future.delayed(const Duration(milliseconds: 100));

    final path = await _captureImage();
    if (path != null) {
      try {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Gallery!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    
    if (mounted) {
      setState(() => _isSharing = false);
    }
  }

  Future<void> _shareCardAsImage(LanguageService lang) async {
    setState(() => _isSharing = true);
    await Future.delayed(const Duration(milliseconds: 100));

    final path = await _captureImage();
    if (path != null) {
      await Share.shareXFiles(
        [XFile(path)],
        text: '${lang.translate('digital_id')} - ${widget.member.fullName}',
      );
    }
    
    if (mounted) {
      setState(() => _isSharing = false);
    }
  }
}


