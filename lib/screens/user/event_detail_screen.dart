// lib/screens/user/event_detail_screen.dart

import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../models/attendance_model.dart';
import '../../models/member_model.dart';
import '../../services/attendance_service.dart';
import '../../services/member_service.dart';
import '../../services/subfamily_service.dart';
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
  final SubFamilyService _subFamilyService = SubFamilyService();

  String? _currentMemberId;
  String? _currentMemberName;
  String? _familyDocId;
  String? _subFamilyDocId;
  String? _familyName;
  String? _subFamilyName;
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
    final memberDocId = await SessionManager.getMemberDocId();
    final role = await SessionManager.getRole();
    final familyDocId = await SessionManager.getFamilyDocId();
    final subFamilyDocId = await SessionManager.getSubFamilyDocId();
    final familyName = await SessionManager.getFamilyName();

    _familyDocId = familyDocId;
    _subFamilyDocId = subFamilyDocId;
    _familyName = familyName;
    _userRole = role;

    try {
      final allMembers = await _memberService.getAllMembers();
      final targetId = memberDocId ?? memberId;
      MemberModel? member;
      if (targetId != null) {
        try {
          member = allMembers.firstWhere(
            (m) => m.id == targetId || m.mid == targetId,
          );
        } catch (_) {}
      }

      if (member != null) {
        _currentMemberId = member.id;
        _currentMemberName = member.fullName;
        if (_familyDocId == null || _familyDocId!.isEmpty) {
          _familyDocId = member.familyDocId;
        }
        if (_subFamilyDocId == null || _subFamilyDocId!.isEmpty) {
          _subFamilyDocId = member.subFamilyDocId;
        }
      } else if (memberId != null) {
        _currentMemberId = memberId;
        _currentMemberName = 'Member';
      }

      if (_familyDocId != null &&
          _subFamilyDocId != null &&
          _subFamilyDocId!.isNotEmpty) {
        try {
          final sf = await _subFamilyService.getSubFamily(
            mainFamilyDocId: _familyDocId!,
            subFamilyDocId: _subFamilyDocId!,
          );
          if (sf != null) {
            _subFamilyName = sf.subFamilyName;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }

    if (mounted) setState(() {});
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

  bool _canEdit(AttendanceModel attendance) {
    if (_userRole == 'admin') return true;
    final isOwner = attendance.markedBy == _currentMemberId ||
        (_familyDocId != null &&
            _familyDocId!.isNotEmpty &&
            attendance.familyDocId == _familyDocId &&
            (attendance.attendanceType == 'whole_family' ||
                (_subFamilyDocId != null &&
                    attendance.subFamilyDocId == _subFamilyDocId)));
    if (!isOwner) return false;
    final now = DateTime.now();
    final difference = now.difference(attendance.markedAt);
    return difference.inMinutes < widget.event.attendanceTimeLimit;
  }

  Future<void> _showMarkAttendanceDialog() async {
    if (_currentMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to mark attendance')),
      );
      return;
    }

    if (_familyDocId == null || _familyDocId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family details not found for your account.')),
      );
      return;
    }

    final hasSubFamily = _subFamilyDocId != null && _subFamilyDocId!.isNotEmpty;
    String selectedType = 'whole_family';
    int memberCount = 1;
    final countController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateCount(int newCount) {
              if (newCount >= 1 && newCount <= 30) {
                setDialogState(() {
                  memberCount = newCount;
                  countController.text = newCount.toString();
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.how_to_reg, color: Colors.blue.shade900),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mark Attendance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Scope',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setDialogState(() => selectedType = 'whole_family');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selectedType == 'whole_family'
                                    ? Colors.indigo.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedType == 'whole_family'
                                      ? Colors.indigo
                                      : Colors.grey.shade300,
                                  width: selectedType == 'whole_family' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.family_restroom,
                                    color: selectedType == 'whole_family'
                                        ? Colors.indigo
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Whole Family',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'whole_family'
                                          ? Colors.indigo
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: hasSubFamily
                                ? () {
                                    setDialogState(() => selectedType = 'sub_family');
                                  }
                                : null,
                            child: Opacity(
                              opacity: hasSubFamily ? 1.0 : 0.4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: selectedType == 'sub_family'
                                      ? Colors.purple.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedType == 'sub_family'
                                        ? Colors.purple
                                        : Colors.grey.shade300,
                                    width: selectedType == 'sub_family' ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.home_work,
                                      color: selectedType == 'sub_family'
                                          ? Colors.purple
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sub-Family',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: selectedType == 'sub_family'
                                            ? Colors.purple
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hasSubFamily)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '* Sub-Family option available when registered with a sub-family.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selectedType == 'whole_family'
                            ? Colors.indigo.shade50.withOpacity(0.6)
                            : Colors.purple.shade50.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: selectedType == 'whole_family'
                                ? Colors.indigo
                                : Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedType == 'whole_family'
                                  ? 'Attendance will be marked for the whole family. Other family members will not be able to mark again.'
                                  : 'Attendance will be marked for "${_subFamilyName ?? 'Sub-Family'}". Other sub-families can mark their attendance separately.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Enter Number of Members',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Minimum: 1, Maximum: 30 members',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),
                    // Stepper row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          onPressed: memberCount > 1
                              ? () => updateCount(memberCount - 1)
                              : null,
                          icon: const Icon(Icons.remove),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: countController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 1 && parsed <= 30) {
                                setDialogState(() => memberCount = parsed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton.filled(
                          onPressed: memberCount < 30
                              ? () => updateCount(memberCount + 1)
                              : null,
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Quick chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [1, 2, 3, 4, 5, 8, 10, 15, 20, 30].map((c) {
                        final isSel = memberCount == c;
                        return ChoiceChip(
                          label: Text('$c'),
                          selected: isSel,
                          onSelected: (_) => updateCount(c),
                          selectedColor: Colors.blue.shade700,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final finalCount =
                        int.tryParse(countController.text) ?? memberCount;
                    if (finalCount < 1 || finalCount > 30) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Member count must be between 1 and 30'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext);
                    _submitAttendance(selectedType, finalCount);
                  },
                  child: const Text('Submit Attendance'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitAttendance(String attendanceType, int memberCount) async {
    try {
      setState(() => _loading = true);

      String entityName = '';
      if (attendanceType == 'whole_family') {
        entityName = _familyName?.isNotEmpty == true
            ? '$_familyName Family'
            : 'Whole Family';
      } else {
        entityName = _subFamilyName?.isNotEmpty == true
            ? _subFamilyName!
            : 'Sub-Family';
      }

      await _attendanceService.markAttendance(
        eventId: widget.event.id,
        markedBy: _currentMemberId!,
        markedByName: _currentMemberName ?? 'Member',
        attendanceType: attendanceType,
        familyDocId: _familyDocId!,
        subFamilyDocId: attendanceType == 'sub_family' ? (_subFamilyDocId ?? '') : '',
        entityName: entityName,
        memberCount: memberCount,
      );

      await _loadAttendanceData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance marked successfully for $entityName ($memberCount members)',
            ),
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
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateCount(AttendanceModel attendance) async {
    int currentCount = attendance.memberCount;
    final controller = TextEditingController(text: currentCount.toString());

    final newCount = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateCount(int c) {
              if (c >= 1 && c <= 30) {
                setDialogState(() {
                  currentCount = c;
                  controller.text = c.toString();
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Edit Member Count',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Update attendance count for ${attendance.entityName}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Min: 1, Max: 30 members',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        onPressed: currentCount > 1
                            ? () => updateCount(currentCount - 1)
                            : null,
                        icon: const Icon(Icons.remove),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= 30) {
                              setDialogState(() => currentCount = parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filled(
                        onPressed: currentCount < 30
                            ? () => updateCount(currentCount + 1)
                            : null,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [1, 2, 3, 4, 5, 8, 10, 15, 20, 30].map((c) {
                      final isSel = currentCount == c;
                      return ChoiceChip(
                        label: Text('$c'),
                        selected: isSel,
                        onSelected: (_) => updateCount(c),
                        selectedColor: Colors.blue.shade700,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final val = int.tryParse(controller.text) ?? currentCount;
                    if (val >= 1 && val <= 30) {
                      Navigator.pop(dialogContext, val);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Count must be between 1 and 30'),
                        ),
                      );
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance count updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteAttendance(AttendanceModel attendance) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Attendance'),
        content: Text(
          'Are you sure you want to delete attendance for "${attendance.entityName}"? You can mark it again before the event.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPast = widget.event.date.isBefore(DateTime.now());

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<AttendanceModel>>(
              stream: _attendanceService.getEventAttendance(widget.event.id),
              builder: (context, snapshot) {
                final records = snapshot.data ?? [];

                return CustomScrollView(
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
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
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
                                  _buildDetailRow(
                                    Icons.calendar_today,
                                    'Date',
                                    _formatDate(widget.event.date),
                                  ),
                                  if (widget.event.time.isNotEmpty)
                                    _buildDetailRow(
                                      Icons.access_time,
                                      'Time',
                                      widget.event.time,
                                    ),
                                  if (widget.event.location.isNotEmpty)
                                    _buildDetailRow(
                                      Icons.location_on,
                                      'Location',
                                      widget.event.location,
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Stats Grid: Total, Whole Family, Sub-Family
                            Row(
                              children: [
                                _buildStatCard(
                                  'Total Members',
                                  _totalAttendance.toString(),
                                  Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  'Whole Family',
                                  (_countsByType['whole_family'] ?? 0).toString(),
                                  Colors.indigo,
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  'Sub-Family',
                                  (_countsByType['sub_family'] ?? 0).toString(),
                                  Colors.purple,
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            if (widget.event.description.isNotEmpty) ...[
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.event.description,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Mark Attendance Section
                            if (!isPast)
                              _buildAttendanceSection(records),

                            const SizedBox(height: 24),

                            const Text(
                              'Attendance Records',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildAttendanceList(records),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildAttendanceSection(List<AttendanceModel> records) {
    // Check if Whole Family is marked for this family
    final wholeFamilyRec = records.cast<AttendanceModel?>().firstWhere(
      (r) =>
          r != null &&
          _familyDocId != null &&
          _familyDocId!.isNotEmpty &&
          r.familyDocId == _familyDocId &&
          r.attendanceType == 'whole_family',
      orElse: () => null,
    );

    // Check if Sub-Family is marked for this sub-family
    final subFamilyRec = records.cast<AttendanceModel?>().firstWhere(
      (r) =>
          r != null &&
          _familyDocId != null &&
          _familyDocId!.isNotEmpty &&
          _subFamilyDocId != null &&
          _subFamilyDocId!.isNotEmpty &&
          r.familyDocId == _familyDocId &&
          (r.subFamilyDocId == _subFamilyDocId || r.entityId == _subFamilyDocId) &&
          r.attendanceType == 'sub_family',
      orElse: () => null,
    );

    final activeRec = wholeFamilyRec ?? subFamilyRec;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mark Attendance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (activeRec != null)
          _buildAlreadyMarkedCard(activeRec)
        else
          _buildMarkAttendanceButton(),
      ],
    );
  }

  Widget _buildAlreadyMarkedCard(AttendanceModel rec) {
    final canEdit = _canEdit(rec);
    final limitMins = widget.event.attendanceTimeLimit;
    final now = DateTime.now();
    final elapsedMins = now.difference(rec.markedAt).inMinutes;
    final remainingMins = limitMins - elapsedMins;

    final hoursLimit = limitMins ~/ 60;
    final minsLimit = limitMins % 60;
    final limitStr = hoursLimit > 0
        ? (minsLimit > 0 ? '${hoursLimit}h ${minsLimit}m' : '${hoursLimit}h')
        : '${minsLimit}m';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade800, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.attendanceType == 'whole_family'
                          ? 'Whole Family Attendance Recorded'
                          : 'Sub-Family Attendance Recorded',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green.shade900,
                      ),
                    ),
                    Text(
                      '${rec.memberCount} members attending (${rec.entityName})',
                      style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Marked by: ${rec.markedByName}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          if (canEdit) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _userRole == 'admin'
                          ? 'Admin: You can edit or delete this attendance anytime.'
                          : 'Edit window active: ~$remainingMins mins left (Limit: $limitStr).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateCount(rec),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Count'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteAttendance(rec),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Attendance edit limit has expired (Window was $limitStr).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkAttendanceButton() {
    return InkWell(
      onTap: _showMarkAttendanceDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.indigo.shade800],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade300.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_reg, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'Enter Number of Members (1 to 30)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList(List<AttendanceModel> records) {
    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No attendance records yet.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final rec = records[index];
        final canEdit = _canEdit(rec);
        final isWholeFamily = rec.attendanceType == 'whole_family';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: (isWholeFamily ? Colors.indigo : Colors.purple)
                    .withOpacity(0.1),
                child: Icon(
                  isWholeFamily ? Icons.family_restroom : Icons.home_work,
                  color: isWholeFamily ? Colors.indigo : Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            rec.entityName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isWholeFamily ? Colors.indigo : Colors.purple)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isWholeFamily ? 'Family' : 'Sub-Family',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isWholeFamily ? Colors.indigo : Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'By ${rec.markedByName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (canEdit) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          onPressed: () => _updateCount(rec),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit Count',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteAttendance(rec),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Delete Attendance',
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '${rec.memberCount}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.memberCount == 1 ? 'member' : 'members',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.08), Colors.white],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
