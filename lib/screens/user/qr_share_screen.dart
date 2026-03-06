// lib/screens/user/qr_share_screen.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr_flutter;
import '../../services/session_manager.dart';
import '../../config/app_config.dart';

class QRShareScreen extends StatefulWidget {
  final String? memberId;
  final String? memberName;
  final String? memberMid;

  const QRShareScreen({
    super.key,
    this.memberId,
    this.memberName,
    this.memberMid,
  });

  @override
  State<QRShareScreen> createState() => _QRShareScreenState();
}

class _QRShareScreenState extends State<QRShareScreen> {
  String _familyId = '';
  String _familyName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final familyId = await SessionManager.getFamilyId() ?? 0;
    final familyName = await SessionManager.getFamilyName() ?? '';

    setState(() {
      _familyId = familyId.toString();
      _familyName = familyName;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Check if sharing member or family
    final isMemberShare =
        widget.memberId != null && widget.memberId!.isNotEmpty;

    // Create share data
    final qrData = isMemberShare
        ? AppConfig.getMemberUrl(
            widget.memberId!,
            familyDocId: _familyId,
          )
        : '${AppConfig.webBaseUrl}/family?id=$_familyId';

    return Scaffold(
      appBar: AppBar(
        title: Text(isMemberShare ? 'Share Member' : 'Share Family'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // QR Code
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  qr_flutter.QrImageView(
                    data: qrData,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isMemberShare
                        ? (widget.memberName ?? 'Member')
                        : _familyName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isMemberShare && widget.memberMid != null)
                    Text(
                      widget.memberMid!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMemberShare ? 'Share this member:' : 'How to use:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (isMemberShare) ...[
                    _buildStep('1', 'Show this QR code to others'),
                    _buildStep('2', 'They can scan it using the app camera'),
                    _buildStep('3', 'Member details will be displayed'),
                  ] else ...[
                    _buildStep(
                      '1',
                      'Show this QR code to other family members',
                    ),
                    _buildStep('2', 'They can scan it using the app camera'),
                    _buildStep(
                      '3',
                      'Your family will be added to their contacts',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade900,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
