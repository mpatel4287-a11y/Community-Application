// lib/screens/user/event_detail_screen.dart

import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/member_service.dart';
import '../../services/session_manager.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MemberService _memberService = MemberService();
  String? _currentMemberId;
  String? _currentMemberName;
  String? _familyDocId;
  String? _subFamilyDocId;
  String? _familyName;
  String? _userRole;
  int _totalAttendance = 0;
  bool _loading = false;
  Map<String, int> _countsByType = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAttendanceData();
  }

  Future<void> _loadUserData() async {
    final memberId = await SessionManager.getMemberId();
    final familyDocId = await SessionManager.getFamilyDocId();
    final subFamilyDocId = await SessionManager.getSubFamilyDocId();
    final familyName = await SessionManager.getFamilyName();
    final role = await SessionManager.getRole();
    
    if (memberId != null) {
      try {
        final allMembers = await _memberService.getAllMembers();
        final member = allMembers.firstWhere(
          (m) => m.id == memberId,
          orElse: () => allMembers.firstWhere(
            (m) => m.mid == memberId,
          ),
        );
        
        setState(() {
          _currentMemberId = memberId;
          _currentMemberName = member.fullName;
          _familyDocId = familyDocId ?? member.familyDocId;
          _subFamilyDocId = subFamilyDocId ?? member.subFamilyDocId;
          _familyName = familyName ?? member.familyName;
          _userRole = role;
        });
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadAttendanceData() async {
    final count = await _attendanceService.getAttendanceCount(widget.event.id);
    final counts = await _attendanceService.getAttendanceByType(widget.event.id);
    if (mounted) {
      setState(() {
        _totalAttendance = count;
        _countsByType = counts;
      });
    }
  }

  Future<void> _handleAttendanceClick(String type) async {
    if (_currentMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to mark attendance')),
      );
      return;
    }

    if (type == 'custom') {
      _showCustomCountDialog();
      return;
    }

    _confirmAndMarkAttendance(type);
  }

  Future<void> _confirmAndMarkAttendance(String type, {int? customCount}) async {
    try {
      setState(() => _loading = true);
      
      String entityId = '';
      String entityName = '';

      if (type == 'family') {
        entityId = _familyDocId ?? '';
        entityName = _familyName ?? 'Family';
      } else if (type == 'subfamily') {
        entityId = '$_familyDocId/$_subFamilyDocId';
        entityName = 'Sub-Family';
      } else if (type == 'firm') {
        final firm = await _showFirmSelectionDialog();
        if (firm == null) {
          setState(() => _loading = false);
          return;
        }
        entityId = firm;
        entityName = firm;
      }

      await _attendanceService.markAttendance(
        eventId: widget.event.id,
        markedBy: _currentMemberId!,
        markedByName: _currentMemberName!,
        attendanceType: type,
        entityId: entityId,
        entityName: entityName,
        customMemberCount: customCount,
      );

      await _loadAttendanceData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance marked successfully for $entityName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().contains('Exception: ') 
            ? e.toString().split('Exception: ')[1] 
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCustomCountDialog() async {
    final controller = TextEditingController();
    final type = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Custom Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose group type for custom count:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.family_restroom, color: Colors.blue),
              title: const Text('For Family'),
              onTap: () => Navigator.pop(context, 'family'),
            ),
            ListTile(
              leading: const Icon(Icons.home_work, color: Colors.purple),
              title: const Text('For Sub-Family'),
              onTap: () => Navigator.pop(context, 'subfamily'),
            ),
            ListTile(
              leading: const Icon(Icons.business, color: Colors.orange),
              title: const Text('For Firm'),
              onTap: () => Navigator.pop(context, 'firm'),
            ),
          ],
        ),
      ),
    );

    if (type == null) return;

    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom Count for ${type.toUpperCase()}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of members',
            hintText: 'Should be >= registered members',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              }
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (count != null) {
      _confirmAndMarkAttendance(type, customCount: count);
    }
  }

  Future<String?> _showFirmSelectionDialog() async {
    final allMembers = await _memberService.getAllMembers();
    final currentMember = allMembers.firstWhere(
      (m) => m.id == _currentMemberId,
      orElse: () => throw Exception('Member not found'),
    );

    if (currentMember.firms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No firms found for your account')),
      );
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Firm'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currentMember.firms.length,
            itemBuilder: (context, index) {
              final firm = currentMember.firms[index];
              return ListTile(
                leading: const Icon(Icons.business),
                title: Text(firm['name'] ?? ''),
                onTap: () => Navigator.pop(context, firm['name']),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _canEdit(AttendanceModel attendance) {
    if (_userRole == 'admin') return true;
    final now = DateTime.now();
    final difference = now.difference(attendance.markedAt);
    return difference.inMinutes < widget.event.attendanceTimeLimit;
  }

  Future<void> _updateCount(AttendanceModel attendance) async {
    final controller = TextEditingController(text: attendance.memberCount.toString());
    final newCount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Member Count'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New Count'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) Navigator.pop(context, val);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newCount != null && newCount != attendance.memberCount) {
      try {
        setState(() => _loading = true);
        await _attendanceService.updateAttendanceCount(
          eventId: widget.event.id,
          attendanceId: attendance.id,
          newCount: newCount,
        );
        await _loadAttendanceData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Count updated successfully'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteAttendance(AttendanceModel attendance) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attendance'),
        content: const Text('Are you sure you want to delete this attendance record? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _loading = true);
        await _attendanceService.deleteAttendance(widget.event.id, attendance.id);
        await _loadAttendanceData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance deleted successfully'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPast = widget.event.date.isBefore(DateTime.now());

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Premium Sliver App Bar
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade900,
                            Colors.blue.shade600,
                            Colors.blue.shade400,
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Icon(
                              Icons.event,
                              size: 180,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.celebration,
                                    color: Colors.white,
                                    size: 48,
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

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Details Card
                        _buildGlassCard(
                          child: Column(
                            children: [
                              _buildDetailRow(Icons.calendar_today, 'Date', _formatDate(widget.event.date)),
                              if (widget.event.time.isNotEmpty)
                                _buildDetailRow(Icons.access_time, 'Time', widget.event.time),
                              if (widget.event.location.isNotEmpty)
                                _buildDetailRow(Icons.location_on, 'Location', widget.event.location),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats Grid
                        Row(
                          children: [
                            _buildStatCard('Total', _totalAttendance.toString(), Colors.blue),
                            const SizedBox(width: 12),
                            _buildStatCard('Family', (_countsByType['family'] ?? 0).toString(), Colors.indigo),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatCard('Sub-Fam', (_countsByType['subfamily'] ?? 0).toString(), Colors.purple),
                            const SizedBox(width: 12),
                            _buildStatCard('Firm', (_countsByType['firm'] ?? 0).toString(), Colors.orange),
                          ],
                        ),

                        const SizedBox(height: 24),

                        if (widget.event.description.isNotEmpty) ...[
                          const Text(
                            'Description',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.event.description,
                            style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (!isPast) ...[
                          const Text(
                            'Mark Attendance',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.5,
                            children: [
                              _buildAttendanceAction('Family', Icons.family_restroom, Colors.blue, 'family'),
                              _buildAttendanceAction('Sub-Fam', Icons.home_work, Colors.purple, 'subfamily'),
                              _buildAttendanceAction('Firm', Icons.business, Colors.orange, 'firm'),
                              _buildAttendanceAction('Custom', Icons.edit_note, Colors.teal, 'custom'),
                            ],
                          ),
                        ],

                        const SizedBox(height: 32),

                        const Text(
                          'Attendance Records',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildAttendanceList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade900),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), Colors.white],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceAction(String label, IconData icon, Color color, String type) {
    return InkWell(
      onTap: () => _handleAttendanceClick(type),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    return StreamBuilder<List<AttendanceModel>>(
      stream: _attendanceService.getEventAttendance(widget.event.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Text('No records found', style: TextStyle(color: Colors.grey.shade500)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final rec = records[index];
            final canEdit = _canEdit(rec);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getTypeColor(rec.attendanceType).withOpacity(0.1),
                    child: Icon(_getTypeIcon(rec.attendanceType), color: _getTypeColor(rec.attendanceType)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rec.entityName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('By ${rec.markedByName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                              onPressed: () => _updateCount(rec),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          const SizedBox(width: 4),
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _deleteAttendance(rec),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '${rec.memberCount}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        rec.isCustomCount ? 'Custom' : 'Registered',
                        style: TextStyle(fontSize: 10, color: rec.isCustomCount ? Colors.teal : Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'family': return Colors.indigo;
      case 'subfamily': return Colors.purple;
      case 'firm': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'family': return Icons.family_restroom;
      case 'subfamily': return Icons.home_work;
      case 'firm': return Icons.business;
      default: return Icons.people;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
