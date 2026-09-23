// lib/screens/user/digital_id_screen.dart

import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/full_screen_image_viewer.dart';
import '../../models/member_model.dart';
import '../../services/language_service.dart';
import '../../config/app_config.dart';

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
              icon: const Icon(Icons.download_rounded, size: 26),
              tooltip: 'Download ID Card',
              onPressed: () => _downloadIdCard(lang),
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, size: 22),
              tooltip: 'Share ID Card',
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
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // THE ID CARD
                RepaintBoundary(
                  key: _boundaryKey,
                  child: _buildIdCard(context, lang, theme),
                ),
                
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                const SizedBox(height: 32),
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
        color: const Color(0xFF122C4F), // Midnight blue card background
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0D1E36),
                  Color(0xFF122C4F),
                ],
              ),
              borderRadius: BorderRadius.only(
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
                GestureDetector(
                  onLongPress: () {
                    if (widget.member.photoUrl.isNotEmpty) {
                      FullScreenImageViewer.show(context, widget.member.photoUrl, tag: 'digital_id_${widget.member.id}');
                    }
                  },
                  child: Container(
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
                ),
                
                const SizedBox(height: 16),
                
                // Name and MID
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.member.fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFBF9E4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (widget.member.isBirthdayToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B6B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cake_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ],
                ),
                if (widget.member.surname.isNotEmpty)
                  Text(
                    widget.member.surname,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5B88B2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 8),
                if (widget.member.isBirthdayToday) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFFF7A00)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5252).withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cake_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Birthday Today! 🎂',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
                Opacity(
                  opacity: 0.6,
                  child: Text(
                    "Ramanagara Patidar Samaj".toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFBF9E4),
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
                
                // QR Code with Full Embedded Payload
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
                        data: AppConfig.getMemberUrl(
                          widget.member.id,
                          familyDocId: widget.member.familyDocId,
                          mid: widget.member.mid,
                          fullName: widget.member.fullName,
                          surname: widget.member.surname,
                          familyName: widget.member.familyName,
                          phone: widget.member.phone,
                          bloodGroup: widget.member.bloodGroup,
                          birthDate: widget.member.birthDate,
                          age: widget.member.age,
                          photoUrl: widget.member.photoUrl,
                          nativeHome: widget.member.nativeHome,
                          education: widget.member.education,
                          marriageStatus: widget.member.marriageStatus,
                          address: widget.member.address,
                          fatherName: widget.member.fatherName,
                          motherName: widget.member.motherName,
                        ),
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
                      const Text(
                        'Scan with any phone camera to view Digital ID Card',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFBF9E4),
                          fontWeight: FontWeight.w600,
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
                'Age',
                widget.member.age > 0 ? '${widget.member.age} years' : '-',
                Icons.calendar_today,
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
                Icons.home_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailItem(
                lang.translate('marital_status'),
                widget.member.marriageStatus.isNotEmpty ? widget.member.marriageStatus : '-',
                Icons.favorite_outline,
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
                widget.member.address.isNotEmpty ? widget.member.address : '-',
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
        color: const Color(0xFF5B88B2).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B88B2).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF5B88B2)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF5B88B2),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
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

  Future<void> _downloadIdCard(LanguageService lang) async {
    setState(() => _isSharing = true);
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final RenderRepaintBoundary? boundary = _boundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final fileName =
          'Digital_ID_Card_${widget.member.mid.replaceAll('-', '_')}.png';

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: pngBytes,
          filename: fileName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Digital ID Card downloaded! 🎉'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/$fileName';
        final file = await File(path).create();
        await file.writeAsBytes(pngBytes);

        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(file.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('High-Resolution ID Card Saved to Gallery! 🎉'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error downloading ID Card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download status: $e'), backgroundColor: Colors.orange.shade800),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _shareCardAsImage(LanguageService lang) async {
    setState(() => _isSharing = true);
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final RenderRepaintBoundary? boundary = _boundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final fileName =
          'Digital_ID_Card_${widget.member.mid.replaceAll('-', '_')}.png';
      final shareText = '${lang.translate('digital_id')} - ${widget.member.fullName} (${widget.member.mid})';

      if (kIsWeb) {
        bool shared = false;
        try {
          final res = await Share.shareXFiles(
            [XFile.fromData(pngBytes, name: fileName, mimeType: 'image/png')],
            text: shareText,
          );
          if (res.status == ShareResultStatus.success) {
            shared = true;
          }
        } catch (_) {
          shared = false;
        }

        // Web fallback: download file and copy share text
        if (!shared) {
          await Printing.sharePdf(
            bytes: pngBytes,
            filename: fileName,
          );
          await Clipboard.setData(ClipboardData(text: shareText));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ID Card downloaded & details copied to clipboard! 🎉'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        }
      } else {
        final box = context.findRenderObject() as RenderBox?;
        final Rect? origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

        await Share.shareXFiles(
          [XFile.fromData(pngBytes, name: fileName, mimeType: 'image/png')],
          text: shareText,
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      debugPrint('Error sharing card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}
