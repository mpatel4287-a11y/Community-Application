// lib/screens/user/help_faq_screen.dart

import 'package:flutter/material.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFaqItem(
            'How do I mark my attendance?',
            'Navigate to the events page and select an upcoming event. Click on the "Mark Attendance" button and choose your firm or custom count.',
          ),
          _buildFaqItem(
            'How are Sub-Firms managed?',
            'Admins can create new firms and add sub-firms under them in the Admin Dashboard. Members can view them in the settings or event attendance flow.',
          ),
          _buildFaqItem(
            'How do I view my Digital ID?',
            'Go to Settings > Family > Digital ID to view your customized digital identity card.',
          ),
          const SizedBox(height: 32),
          const Text(
            'Need More Help?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Contact Support'),
              subtitle: const Text('support@communityapp.com'),
              onTap: () {
                // To be implemented: launch email client
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
