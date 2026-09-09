// lib/widgets/custom_export_dialog.dart

import 'package:flutter/material.dart';
import '../models/member_model.dart';
import '../models/subfamily_model.dart';
import '../services/export_service.dart';
import '../services/member_service.dart';
import '../services/subfamily_service.dart';

enum ExportScope { fullFamily, subFamily }
enum ExportFormat { pdf, excel }

class CustomExportDialog extends StatefulWidget {
  final String mainFamilyDocId;
  final String familyName;
  final String familyId;
  final String? initialSubFamilyDocId;
  final String? initialSubFamilyName;
  final bool restrictToSingleFamily;

  const CustomExportDialog({
    super.key,
    required this.mainFamilyDocId,
    required this.familyName,
    this.familyId = '',
    this.initialSubFamilyDocId,
    this.initialSubFamilyName,
    this.restrictToSingleFamily = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String mainFamilyDocId,
    required String familyName,
    String familyId = '',
    String? initialSubFamilyDocId,
    String? initialSubFamilyName,
    bool restrictToSingleFamily = true,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => CustomExportDialog(
        mainFamilyDocId: mainFamilyDocId,
        familyName: familyName,
        familyId: familyId,
        initialSubFamilyDocId: initialSubFamilyDocId,
        initialSubFamilyName: initialSubFamilyName,
        restrictToSingleFamily: restrictToSingleFamily,
      ),
    );
  }

  @override
  State<CustomExportDialog> createState() => _CustomExportDialogState();
}

class _CustomExportDialogState extends State<CustomExportDialog> {
  final MemberService _memberService = MemberService();
  final SubFamilyService _subFamilyService = SubFamilyService();

  ExportScope _scope = ExportScope.fullFamily;
  ExportFormat _format = ExportFormat.pdf;
  bool _isExporting = false;

  List<SubFamilyModel> _subFamilies = [];
  SubFamilyModel? _selectedSubFamily;
  bool _loadingSubFamilies = false;

  // Selected fields for export
  final Map<ExportField, bool> _selectedFields = {
    ExportField.familyId: true,
    ExportField.familyName: true,
    ExportField.mid: true,
    ExportField.fullName: true,
    ExportField.phone: true,
    ExportField.bloodGroup: true,
    ExportField.age: true,
    ExportField.gender: true,
    ExportField.fatherName: true,
    ExportField.marriageStatus: true,
    // Optional fields
    ExportField.motherName: false,
    ExportField.nativeHome: false,
    ExportField.education: false,
    ExportField.address: false,
    ExportField.email: false,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSubFamilyDocId != null && widget.initialSubFamilyDocId!.isNotEmpty) {
      _scope = ExportScope.subFamily;
    }
    _loadSubFamilies();
  }

  Future<void> _loadSubFamilies() async {
    setState(() => _loadingSubFamilies = true);
    try {
      final list = await _subFamilyService.getSubFamilies(widget.mainFamilyDocId);
      if (mounted) {
        setState(() {
          _subFamilies = list;
          if (list.isNotEmpty) {
            if (widget.initialSubFamilyDocId != null) {
              final found = list.where((sf) => sf.id == widget.initialSubFamilyDocId).toList();
              _selectedSubFamily = found.isNotEmpty ? found.first : list.first;
            } else {
              _selectedSubFamily = list.first;
            }
          }
          _loadingSubFamilies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubFamilies = false);
    }
  }

  void _selectAllFields(bool select) {
    setState(() {
      for (final key in _selectedFields.keys) {
        _selectedFields[key] = select;
      }
    });
  }

  void _selectStandard10() {
    setState(() {
      final standard = {
        ExportField.familyId,
        ExportField.familyName,
        ExportField.mid,
        ExportField.fullName,
        ExportField.phone,
        ExportField.bloodGroup,
        ExportField.age,
        ExportField.gender,
        ExportField.fatherName,
        ExportField.marriageStatus,
      };
      for (final key in _selectedFields.keys) {
        _selectedFields[key] = standard.contains(key);
      }
    });
  }

  Future<void> _performExport() async {
    final activeFields = _selectedFields.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (activeFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one field to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      List<MemberModel> members = [];
      String exportTitle = widget.familyName;

      if (_scope == ExportScope.subFamily && _selectedSubFamily != null) {
        members = await _memberService.getSubFamilyMembers(
          widget.mainFamilyDocId,
          _selectedSubFamily!.id,
        );
        exportTitle = '${widget.familyName} - ${_selectedSubFamily!.subFamilyName}';
      } else {
        members = await _memberService.getFamilyMembers(widget.mainFamilyDocId);
        exportTitle = '${widget.familyName} (Full Family)';
      }

      final List<Map<String, dynamic>> exportData = [
        {
          'familyDocId': widget.mainFamilyDocId,
          'familyId': widget.familyId.isNotEmpty ? widget.familyId : '12345',
          'familyName': widget.familyName,
          'members': members,
        }
      ];

      if (_format == ExportFormat.excel) {
        await ExportService.exportToExcel(
          title: exportTitle,
          familiesData: exportData,
          selectedFields: activeFields,
        );
      } else {
        await ExportService.exportToPdf(
          title: exportTitle,
          familiesData: exportData,
          selectedFields: activeFields,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported successfully to ${_format == ExportFormat.pdf ? 'PDF' : 'Excel'}!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.file_download_rounded, color: Color(0xFF0F766E), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export Family Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.familyName,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scope Selection (Full Family vs Sub-Family)
                    const Text(
                      '1. Export Scope',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ExportScope>(
                      segments: const [
                        ButtonSegment(
                          value: ExportScope.fullFamily,
                          label: Text('Full Family'),
                          icon: Icon(Icons.family_restroom_rounded, size: 18),
                        ),
                        ButtonSegment(
                          value: ExportScope.subFamily,
                          label: Text('Sub-Family Only'),
                          icon: Icon(Icons.account_tree_rounded, size: 18),
                        ),
                      ],
                      selected: {_scope},
                      onSelectionChanged: (val) {
                        setState(() => _scope = val.first);
                      },
                    ),
                    const SizedBox(height: 12),

                    if (_scope == ExportScope.subFamily) ...[
                      if (_loadingSubFamilies)
                        const LinearProgressIndicator()
                      else if (_subFamilies.isEmpty)
                        Text('No sub-families found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
                      else
                        DropdownButtonFormField<SubFamilyModel>(
                          value: _selectedSubFamily,
                          decoration: InputDecoration(
                            labelText: 'Select Sub-Family',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _subFamilies.map((sf) {
                            return DropdownMenuItem(
                              value: sf,
                              child: Text(
                                sf.subFamilyName.isEmpty ? 'Main Branch' : sf.subFamilyName,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSubFamily = val);
                          },
                        ),
                      const SizedBox(height: 16),
                    ],

                    // Format Selection
                    const Text(
                      '2. Export Format',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _format = ExportFormat.pdf),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _format == ExportFormat.pdf
                                    ? const Color(0xFFE11D48).withOpacity(0.12)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _format == ExportFormat.pdf ? const Color(0xFFE11D48) : Colors.grey.shade300,
                                  width: _format == ExportFormat.pdf ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded,
                                      color: _format == ExportFormat.pdf ? const Color(0xFFE11D48) : Colors.grey.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PDF Document',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _format == ExportFormat.pdf ? const Color(0xFFE11D48) : Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _format = ExportFormat.excel),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _format == ExportFormat.excel
                                    ? const Color(0xFF10B981).withOpacity(0.12)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _format == ExportFormat.excel ? const Color(0xFF10B981) : Colors.grey.shade300,
                                  width: _format == ExportFormat.excel ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.table_chart_rounded,
                                      color: _format == ExportFormat.excel ? const Color(0xFF10B981) : Colors.grey.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Excel (.xlsx)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _format == ExportFormat.excel ? const Color(0xFF10B981) : Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Custom Field Selection (Tick options)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '3. Select Fields to Include',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: _selectStandard10,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
                              child: const Text('Top 10', style: TextStyle(fontSize: 11)),
                            ),
                            TextButton(
                              onPressed: () => _selectAllFields(true),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                              child: const Text('All', style: TextStyle(fontSize: 11)),
                            ),
                            TextButton(
                              onPressed: () => _selectAllFields(false),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                              child: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: ExportField.values.map((field) {
                          final isChecked = _selectedFields[field] ?? false;
                          final isStandard = field.index <= 9;
                          return FilterChip(
                            selected: isChecked,
                            label: Text(
                              field.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: isChecked
                                    ? (isStandard ? const Color(0xFF0F766E) : Colors.blue.shade900)
                                    : Colors.grey.shade700,
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selectedColor: isStandard
                                ? const Color(0xFF0F766E).withOpacity(0.18)
                                : Colors.blue.withOpacity(0.18),
                            checkmarkColor: isStandard ? const Color(0xFF0F766E) : Colors.blue.shade900,
                            onSelected: (val) {
                              setState(() => _selectedFields[field] = val);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isExporting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _performExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(_format == ExportFormat.pdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded),
                    label: Text(_isExporting ? 'Exporting...' : 'Export Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
