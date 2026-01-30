// lib/screens/admin/add_edit_event_screen.dart

import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../models/member_model.dart';
import '../../models/group_model.dart';
import '../../services/event_service.dart';
import '../../services/member_service.dart';
import '../../services/group_service.dart';
import '../../services/session_manager.dart';

class AddEditEventScreen extends StatefulWidget {
  final EventModel? event;

  const AddEditEventScreen({super.key, this.event});

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventService = EventService();
  final _memberService = MemberService();
  final _groupService = GroupService();

  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _searchCtrl;
  late TextEditingController _attendanceLimitCtrl;

  String _selectedType = 'general';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  
  String _visibilityType = 'all';
  List<String> _selectedMemberIds = [];
  List<String> _selectedGroupIds = [];

  List<MemberModel> _allMembers = [];
  List<GroupModel> _allGroups = [];
  List<MemberModel> _filteredMembers = [];
  
  bool _loading = false;
  String? _familyDocId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event?.title ?? '');
    _descriptionCtrl = TextEditingController(text: widget.event?.description ?? '');
    _descriptionCtrl = TextEditingController(text: widget.event?.description ?? '');
    _locationCtrl = TextEditingController(text: widget.event?.location ?? '');
    _attendanceLimitCtrl = TextEditingController(text: widget.event?.attendanceTimeLimit.toString() ?? '60');
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_filterMembers);

    if (widget.event != null) {
      _selectedType = widget.event!.type;
      _selectedDate = widget.event!.date;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.date);
      _visibilityType = widget.event!.visibilityType;
      _selectedMemberIds = List.from(widget.event!.visibleToMemberIds);
      _selectedGroupIds = List.from(widget.event!.visibleToGroupIds);
      
      // If time string exists, try to parse. Supports "10:30" (24h) or "10:30 AM" (12h)
      if (widget.event!.time.isNotEmpty) {
        try {
          final t = widget.event!.time.trim();
          if (t.contains('M')) { // AM/PM case
             // Simple parse attempt for "10:30 AM"
             final spaceParts = t.split(' ');
             final timeParts = spaceParts[0].split(':');
             int h = int.parse(timeParts[0]);
             int m = int.parse(timeParts[1]);
             if (spaceParts[1] == 'PM' && h != 12) h += 12;
             if (spaceParts[1] == 'AM' && h == 12) h = 0;
             _selectedTime = TimeOfDay(hour: h, minute: m);
          } else {
            final parts = t.split(':');
            if (parts.length == 2) {
              _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
          }
        } catch (e) {
          debugPrint('Error parsing time: $e');
        }
      }
    }

    _loadInitialData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _attendanceLimitCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    _familyDocId = await SessionManager.getFamilyDocId();
    _currentUserRole = await SessionManager.getRole();
    
    if (_familyDocId != null) {
      final members = await _memberService.getAllMembers();
      final groups = await _groupService.streamGroups(_familyDocId!).first;
      
      setState(() {
        _allMembers = members;
        _filteredMembers = members;
        _allGroups = groups;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _filterMembers() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredMembers = _allMembers.where((m) {
        return m.fullName.toLowerCase().contains(query) || m.mid.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    // 12-hour format with AM/PM
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    
    // Combine date and time
    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final timeStr = _formatTime(_selectedTime);

    try {
      if (widget.event == null) {
        await _eventService.createEvent(
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          date: finalDateTime,
          time: timeStr,
          type: _selectedType,
          createdBy: _currentUserRole ?? 'admin',
          familyDocId: _familyDocId ?? '',
          visibilityType: _visibilityType,
          visibleToMemberIds: _visibilityType == 'selected' ? _selectedMemberIds : [],
          visibleToGroupIds: _visibilityType == 'selected' ? _selectedGroupIds : [],
          attendanceTimeLimit: int.tryParse(_attendanceLimitCtrl.text.trim()) ?? 60,
        );
      } else {
        await _eventService.updateEvent(
          eventId: widget.event!.id,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          date: finalDateTime,
          time: timeStr,
          type: _selectedType,
          visibilityType: _visibilityType,
          visibleToMemberIds: _visibilityType == 'selected' ? _selectedMemberIds : [],
          visibleToGroupIds: _visibilityType == 'selected' ? _selectedGroupIds : [],
          attendanceTimeLimit: int.tryParse(_attendanceLimitCtrl.text.trim()) ?? 60,
        );
      }
      if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Add New Event' : 'Edit Event'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveEvent,
          ),
        ],
      ),
      body: _loading && _allMembers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Basic Information'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Event Title',
                                prefixIcon: Icon(Icons.title),
                              ),
                              validator: (v) => v!.isEmpty ? 'Field required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _locationCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Location',
                                prefixIcon: Icon(Icons.location_on),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _attendanceLimitCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Attendance Edit Limit (Minutes)',
                                prefixIcon: Icon(Icons.timer_off),
                                helperText: 'Time window to edit/delete attendance',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = int.tryParse(v);
                                if (n == null || n < 1) return 'Must be > 0';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: ['general', 'puja', 'function', 'meeting', 'yar']
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedType = v!),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Schedule'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _selectDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: _selectTime,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Time',
                                    prefixIcon: Icon(Icons.access_time),
                                  ),
                                  child: Text(_selectedTime.format(context)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Visibility Settings'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: const Text('Everyone'),
                              subtitle: const Text('Visible to all community members'),
                              value: 'all',
                              groupValue: _visibilityType,
                              onChanged: (v) => setState(() => _visibilityType = v!),
                            ),
                            RadioListTile<String>(
                              title: const Text('Selected Members/Groups'),
                              subtitle: const Text('Only visible to specific people or groups'),
                              value: 'selected',
                              groupValue: _visibilityType,
                              onChanged: (v) => setState(() => _visibilityType = v!),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (_visibilityType == 'selected') ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Target Members'),
                      Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Search members by name or ID...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 300,
                              child: ListView.builder(
                                itemCount: _filteredMembers.length,
                                itemBuilder: (context, index) {
                                  final m = _filteredMembers[index];
                                  final isSelected = _selectedMemberIds.contains(m.id);
                                  return CheckboxListTile(
                                    title: Text(m.fullName),
                                    subtitle: Text(m.mid),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedMemberIds.add(m.id);
                                        } else {
                                          _selectedMemberIds.remove(m.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Target Groups'),
                      Card(
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _allGroups.length,
                          itemBuilder: (context, index) {
                            final g = _allGroups[index];
                            final isSelected = _selectedGroupIds.contains(g.id);
                            return CheckboxListTile(
                              title: Text(g.name),
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedGroupIds.add(g.id);
                                  } else {
                                    _selectedGroupIds.remove(g.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    if (_loading) const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }
}
