import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/person.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/animation_utils.dart';

class PersonDetailDialog extends StatelessWidget {
  final Person person;

  const PersonDetailDialog({
    super.key,
    required this.person,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 24),
                  Expanded(child: Container()),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ScaleAnimation(
                delay: const Duration(milliseconds: 100),
                child: _buildPhoto(),
              ),
              const SizedBox(height: 16),
              FadeInAnimation(
                delay: const Duration(milliseconds: 200),
                child: _buildName(),
              ),
              const SizedBox(height: 8),
              FadeInAnimation(
                delay: const Duration(milliseconds: 300),
                child: _buildDetails(),
              ),
              if (person.mid != null && person.mid!.isNotEmpty) ...[
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: const Duration(milliseconds: 400),
                  child: _buildQRCode(context),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    final Color backgroundColor = person.gender == Gender.male
        ? const Color(0xFF4A90E2)
        : const Color(0xFFE24A90);

    return CircleAvatar(
      radius: 40,
      backgroundColor: backgroundColor,
      backgroundImage: person.photoUrl != null
          ? CachedNetworkImageProvider(person.photoUrl!)
          : null,
      child: person.photoUrl == null
          ? Text(
              person.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            )
          : null,
    );
  }

  Widget _buildName() {
    return Text(
      person.fullName,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDetails() {
    return Column(
      children: [
        if (person.age != null || person.calculatedAge > 0)
          Text(
            'Age: ${person.calculatedAge} years',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
        Text(
          'Born: ${person.birthYear}',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
        if (person.mid != null && person.mid!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'MID: ${person.mid}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4A90E2),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        if (person.relationToHead != null && 
            person.relationToHead!.isNotEmpty &&
            person.relationToHead != 'none') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE24A90).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Relation: ${person.relationToHead!.replaceAll('_', ' ').split(' ').map((word) {
                if (word.isEmpty) return '';
                return word[0].toUpperCase() + word.substring(1);
              }).join(' ')}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFE24A90),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (person.details != null) ...[
          const SizedBox(height: 12),
          Text(
            person.details!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildQRCode(BuildContext context) {
    final qrData = jsonEncode({
      'type': 'person',
      'id': person.id,
      'mid': person.mid ?? '',
      'fullName': person.fullName,
      'birthYear': person.birthYear,
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Text(
            'Digital ID',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 180.0,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF4A90E2),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scan to view details',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
