// lib/screens/admin/firm_detail_screen.dart

import 'package:flutter/material.dart';
import '../../models/firm_model.dart';
import '../../models/sub_firm_model.dart';
import '../../models/member_model.dart';
import '../../services/firm_service.dart';
import '../../services/member_service.dart';

class FirmDetailScreen extends StatefulWidget {
  final FirmModel firm;

  const FirmDetailScreen({super.key, required this.firm});

  @override
  State<FirmDetailScreen> createState() => _FirmDetailScreenState();
}

class _FirmDetailScreenState extends State<FirmDetailScreen> {
  final FirmService _firmService = FirmService();
  final MemberService _memberService = MemberService();

  void _showAddSubFirmDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final contactNumberCtrl = TextEditingController();
    final contactNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Sub-Firm'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Sub-Firm Name'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: contactNameCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Person Name'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: contactNumberCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Number'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                try {
                  await _firmService.createSubFirm(
                    firmId: widget.firm.id,
                    name: nameCtrl.text.trim(),
                    location: locationCtrl.text.trim(),
                    contactName: contactNameCtrl.text.trim(),
                    contactNumber: contactNumberCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sub-Firm added successfully'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteSubFirm(SubFirmModel subFirm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sub-Firm?'),
        content: Text('Are you sure you want to delete ${subFirm.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete')
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firmService.deleteSubFirm(widget.firm.id, subFirm.id);
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.firm.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubFirmDialog,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Sub-Firm'),
      ),
      body: StreamBuilder<List<SubFirmModel>>(
        stream: _firmService.getSubFirmsStream(widget.firm.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final subFirms = snapshot.data ?? [];

          return StreamBuilder<List<MemberModel>>(
            stream: _memberService.streamAllMembers(),
            builder: (context, memberSnapshot) {
              final members = memberSnapshot.data ?? [];
              
              int memberCount = 0;
              for (final member in members) {
                for (final memberFirm in member.firms) {
                  if ((memberFirm['name'] ?? '').toString().toLowerCase() == widget.firm.name.toLowerCase()) {
                    memberCount++;
                    break;
                  }
                }
              }

              return Column(
                children: [
                  // Stats Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade900,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatCard('Sub-Firms', subFirms.length.toString(), Icons.apartment, Colors.orange),
                        const SizedBox(width: 16),
                        _buildStatCard('Total Members', memberCount.toString(), Icons.groups, Colors.blue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sub-Firms List
                  Expanded(
                    child: subFirms.isEmpty
                      ? const Center(
                          child: Text(
                            'No sub-firms found. Add one!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: subFirms.length,
                          itemBuilder: (context, index) {
                            final subFirm = subFirms[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subFirm.name,
                                            style: const TextStyle(
                                              fontSize: 18, 
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _deleteSubFirm(subFirm),
                                        )
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Divider(),
                                    ),
                                    // Location
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 18, color: Colors.grey.shade400),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(subFirm.location, style: TextStyle(color: Colors.grey.shade700, fontSize: 15))),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Contact Person
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 18, color: Colors.grey.shade400),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(subFirm.contactName, style: TextStyle(color: Colors.grey.shade700, fontSize: 15))),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Contact Number
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 18, color: Colors.grey.shade400),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(subFirm.contactNumber, style: TextStyle(color: Colors.grey.shade700, fontSize: 15))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
