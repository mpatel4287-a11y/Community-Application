// lib/screens/admin/admin_update_requests_screen.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/member_update_request_model.dart';
import '../../services/update_request_service.dart';
import '../../services/language_service.dart';
import '../../widgets/animation_utils.dart';

class AdminUpdateRequestsScreen extends StatefulWidget {
  const AdminUpdateRequestsScreen({super.key});

  @override
  State<AdminUpdateRequestsScreen> createState() => _AdminUpdateRequestsScreenState();
}

class _AdminUpdateRequestsScreenState extends State<AdminUpdateRequestsScreen> with SingleTickerProviderStateMixin {
  final UpdateRequestService _updateService = UpdateRequestService();
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'photo_update', 'contact_info', 'personal_details', 'business_info', 'general'
  final TextEditingController _searchController = TextEditingController();

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _marriageStatuses = ['unmarried', 'married', 'engaged'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('member_update_requests')),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.hourglass_top_rounded, size: 20), text: 'Pending'),
            Tab(icon: Icon(Icons.check_circle_outline, size: 20), text: 'Approved'),
            Tab(icon: Icon(Icons.highlight_off_rounded, size: 20), text: 'Rejected'),
            Tab(icon: Icon(Icons.list_alt_rounded, size: 20), text: 'All'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Category Filter Bar
          _buildFilterBar(theme, isDark),

          // Main Tab Views
          Expanded(
            child: StreamBuilder<List<MemberUpdateRequestModel>>(
              stream: _updateService.streamAllRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error loading requests: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }

                final allRequests = snapshot.data ?? [];

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(
                      _filterRequests(allRequests, status: 'pending'),
                      theme,
                      isDark,
                      emptyMessage: 'No pending update requests.',
                    ),
                    _buildRequestsList(
                      _filterRequests(allRequests, status: 'approved'),
                      theme,
                      isDark,
                      emptyMessage: 'No approved requests found.',
                    ),
                    _buildRequestsList(
                      _filterRequests(allRequests, status: 'rejected'),
                      theme,
                      isDark,
                      emptyMessage: 'No rejected requests found.',
                    ),
                    _buildRequestsList(
                      _filterRequests(allRequests),
                      theme,
                      isDark,
                      emptyMessage: 'No member update requests found.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by member name, MID, or phone...',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryChip('all', 'All Types', Icons.dashboard_outlined),
                _buildCategoryChip('account_deletion', 'Deletion Requests', Icons.person_remove_outlined),
                _buildCategoryChip('photo_update', 'Photo', Icons.camera_alt_outlined),
                _buildCategoryChip('contact_info', 'Contact', Icons.phone_outlined),
                _buildCategoryChip('personal_details', 'Personal', Icons.badge_outlined),
                _buildCategoryChip('business_info', 'Business', Icons.business_outlined),
                _buildCategoryChip('general', 'Other', Icons.description_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, IconData icon) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _selectedCategory = id);
        },
        selectedColor: const Color(0xFF0F766E),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : null,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }

  List<MemberUpdateRequestModel> _filterRequests(List<MemberUpdateRequestModel> list, {String? status}) {
    return list.where((req) {
      if (status != null && req.status.toLowerCase() != status.toLowerCase()) {
        return false;
      }
      if (_selectedCategory != 'all' && req.requestType != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final matchesName = req.memberName.toLowerCase().contains(_searchQuery);
        final matchesMid = req.memberMid.toLowerCase().contains(_searchQuery);
        final matchesPhone = req.requestedByPhone.contains(_searchQuery);
        final matchesFamily = req.familyName.toLowerCase().contains(_searchQuery);
        final matchesTitle = req.title.toLowerCase().contains(_searchQuery);
        return matchesName || matchesMid || matchesPhone || matchesFamily || matchesTitle;
      }
      return true;
    }).toList();
  }

  Widget _buildRequestsList(
    List<MemberUpdateRequestModel> requests,
    ThemeData theme,
    bool isDark, {
    required String emptyMessage,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final req = requests[index];
        return SlideInAnimation(
          delay: Duration(milliseconds: 50 * index),
          beginOffset: const Offset(0, 0.1),
          child: _buildRequestCard(req, theme, isDark),
        );
      },
    );
  }

  Widget _buildRequestCard(MemberUpdateRequestModel req, ThemeData theme, bool isDark) {
    Color statusColor = Colors.orange;
    String statusText = 'PENDING';
    IconData statusIcon = Icons.hourglass_top_rounded;

    if (req.status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusText = 'APPROVED';
      statusIcon = Icons.check_circle_rounded;
    } else if (req.status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'REJECTED';
      statusIcon = Icons.cancel_rounded;
    }

    return AnimatedCard(
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Member Name + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF0F766E).withOpacity(0.12),
                  backgroundImage: req.currentPhotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(req.currentPhotoUrl)
                      : null,
                  child: req.currentPhotoUrl.isEmpty
                      ? const Icon(Icons.person, color: Color(0xFF0F766E), size: 24)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.memberName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.memberMid,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                          ),
                          Text(
                            req.familyName,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Request Type & Title
            Row(
              children: [
                _buildCategoryBadge(req.requestType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    req.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Account Deletion Warning Banner
            if (req.requestType == 'account_deletion') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Permanent Account Deletion Request',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Under Google Play Data Safety policies, this member has requested permanent deletion of their account.\n• When approved: The member record will be permanently deleted from the database.\n• When rejected: The request is dismissed and the member account remains active and normal as usual.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // Visual Difference / Preview Section
            if (req.requestType == 'photo_update' || req.newPhotoUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildPhotoComparisonCard(req, isDark),
            ],

            if (req.fieldUpdates.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildFieldUpdatesPreview(req.fieldUpdates, isDark),
            ],

            if (req.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Note:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.description,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
              ),
            ],

            if (req.adminNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Admin Note: ${req.adminNote}',
                  style: const TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
                ),
              ),
            ],

            const SizedBox(height: 10),
            // Footer: Date + Phone
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Submitted: ${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                if (req.requestedByPhone.isNotEmpty)
                  Text(
                    'Phone: ${req.requestedByPhone}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Action Buttons Row (Responsive)
            _buildActionButtons(req, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String type) {
    IconData icon = Icons.info_outline;
    String label = 'General';
    Color color = Colors.grey;

    switch (type) {
      case 'account_deletion':
        icon = Icons.person_remove_rounded;
        label = 'Account Deletion';
        color = Colors.red;
        break;
      case 'photo_update':
        icon = Icons.camera_alt;
        label = 'Photo';
        color = const Color(0xFF0F766E);
        break;
      case 'contact_info':
        icon = Icons.phone;
        label = 'Contact';
        color = Colors.blue;
        break;
      case 'personal_details':
        icon = Icons.badge;
        label = 'Personal';
        color = Colors.purple;
        break;
      case 'business_info':
        icon = Icons.business;
        label = 'Business';
        color = Colors.orange;
        break;
      default:
        icon = Icons.edit_note;
        label = 'Update';
        color = Colors.teal;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPhotoComparisonCard(MemberUpdateRequestModel req, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photo Replacement Preview:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Old Photo
              Column(
                children: [
                  const Text('Current Photo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: req.currentPhotoUrl.isNotEmpty ? () => _showFullImageDialog(req.currentPhotoUrl) : null,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400, width: 1.5),
                        image: req.currentPhotoUrl.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(req.currentPhotoUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: req.currentPhotoUrl.isEmpty
                          ? const Icon(Icons.person, size: 36, color: Colors.grey)
                          : null,
                    ),
                  ),
                ],
              ),

              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F766E), size: 24),

              // New Photo
              Column(
                children: [
                  const Text('New Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: req.newPhotoUrl.isNotEmpty ? () => _showFullImageDialog(req.newPhotoUrl) : null,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981), width: 2.5),
                        image: req.newPhotoUrl.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(req.newPhotoUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: req.newPhotoUrl.isEmpty
                          ? const Icon(Icons.image_not_supported_outlined, size: 36, color: Colors.grey)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Tap on image to view full size',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldUpdatesPreview(Map<String, dynamic> fieldUpdates, bool isDark) {
    final entries = fieldUpdates.entries.where((e) => e.key != 'photo_update_requested').toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Requested Field Changes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.map((entry) {
            String label = entry.key;
            String val = entry.value.toString();

            // Beautify field label
            if (label == 'fullName') label = 'Full Name';
            if (label == 'surname') label = 'Surname';
            if (label == 'fatherName') label = 'Father Name';
            if (label == 'motherName') label = 'Mother Name';
            if (label == 'birthDate') label = 'Birth Date';
            if (label == 'bloodGroup') label = 'Blood Group';
            if (label == 'marriageStatus') label = 'Marriage Status';
            if (label == 'nativeHome') label = 'Native Home';
            if (label == 'gotra') label = 'Gotra';
            if (label == 'phone') label = 'Phone Number';
            if (label == 'whatsapp') label = 'WhatsApp';
            if (label == 'email') label = 'Email';
            if (label == 'address') label = 'Address';
            if (label == 'googleMapLink') label = 'Map Link';
            if (label == 'education') label = 'Education';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      '$label:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      val,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons(MemberUpdateRequestModel req, ThemeData theme) {
    final isPending = req.status == 'pending';
    final isDeletion = req.requestType == 'account_deletion';

    return Row(
      children: [
        // Review & Edit & Approve Button
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: () => _openReviewAndEditDialog(req),
            icon: Icon(
              isDeletion
                  ? (isPending ? Icons.gavel_rounded : Icons.visibility_outlined)
                  : (isPending ? Icons.edit_attributes_rounded : Icons.visibility_outlined),
              size: 17,
            ),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isDeletion
                    ? (isPending ? 'Review Deletion' : 'View Details')
                    : (isPending ? 'Review & Edit' : 'View Details'),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDeletion ? Colors.blueGrey.shade800 : const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

        if (isPending) ...[
          const SizedBox(width: 8),
          // Quick Approve / Delete Button
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () => _quickApprove(req),
              icon: Icon(
                isDeletion ? Icons.delete_forever : Icons.check_circle_outline,
                color: isDeletion ? Colors.red : const Color(0xFF10B981),
                size: 17,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isDeletion ? 'Delete' : 'Approve',
                  style: TextStyle(
                    color: isDeletion ? Colors.red : const Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDeletion ? Colors.red : const Color(0xFF10B981)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Quick Reject Button
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () => _promptRejectDialog(req),
              icon: const Icon(Icons.cancel_outlined, color: Colors.orange, size: 17),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Reject', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],

        if (!isPending) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            tooltip: 'Delete Request Record',
            onPressed: () => _confirmDelete(req),
          ),
        ],
      ],
    );
  }

  // ---------------- ACTION DIALOGS ----------------

  void _showFullImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (c, u, e) => const Icon(Icons.error, color: Colors.white, size: 48),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickApprove(MemberUpdateRequestModel req) async {
    final isDeletion = req.requestType == 'account_deletion';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isDeletion ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: isDeletion ? Colors.red : const Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(isDeletion ? 'Approve Account Deletion' : 'Approve Request'),
            ),
          ],
        ),
        content: Text(
          isDeletion
              ? 'Are you sure you want to approve account deletion for ${req.memberName} (${req.memberMid})?\n\nThis will permanently delete their account and member record from the database. This action cannot be undone.'
              : 'Are you sure you want to approve this request for ${req.memberName}? The requested changes will be directly applied to the Samaj database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDeletion ? Colors.red : const Color(0xFF10B981)),
            child: Text(isDeletion ? 'Delete Permanently' : 'Approve & Apply', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _updateService.applyAndApproveRequest(
          request: req,
          approvedUpdates: req.fieldUpdates,
          approvedPhotoUrl: req.newPhotoUrl.isNotEmpty ? req.newPhotoUrl : null,
          adminNote: isDeletion ? 'Account permanently deleted by Admin' : 'Approved by Committee',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDeletion
                ? 'Account of ${req.memberName} (${req.memberMid}) has been permanently deleted.'
                : 'Successfully applied changes for ${req.memberName}!'),
            backgroundColor: isDeletion ? Colors.red.shade700 : const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _promptRejectDialog(MemberUpdateRequestModel req) async {
    final isDeletion = req.requestType == 'account_deletion';
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reject Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isDeletion
                ? 'Provide a reason for rejecting the account deletion request for ${req.memberName}. Their account will remain active and normal as usual:'
                : 'Provide a reason for rejecting this update request for ${req.memberName}:'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isDeletion
                    ? 'e.g. Identity could not be verified, requested accidentally...'
                    : 'e.g. Photo not clear, invalid contact number...',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _updateService.rejectRequest(
          requestId: req.id,
          adminNote: noteController.text.trim().isNotEmpty
              ? noteController.text.trim()
              : (isDeletion ? 'Account deletion rejected by admin. Account stays normal.' : 'Rejected by admin committee'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDeletion
                ? 'Account deletion request rejected. Member account remains normal as usual.'
                : 'Request marked as rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete(MemberUpdateRequestModel req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request Record?'),
        content: const Text('This will permanently remove the request history record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _updateService.deleteRequest(req.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request record deleted.')),
      );
    }
  }

  // ---------------- DETAILED REVIEW & EDIT MODAL ----------------
  void _openReviewAndEditDialog(MemberUpdateRequestModel req) {
    if (req.requestType == 'account_deletion') {
      _showAccountDeletionReviewDialog(req);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminReviewSheet(
        request: req,
        bloodGroups: _bloodGroups,
        marriageStatuses: _marriageStatuses,
        onApprove: (approvedUpdates, approvedPhotoUrl, adminNote) async {
          Navigator.pop(ctx);
          try {
            await _updateService.applyAndApproveRequest(
              request: req,
              approvedUpdates: approvedUpdates,
              approvedPhotoUrl: approvedPhotoUrl,
              adminNote: adminNote,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully applied changes for ${req.memberName}!'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to apply update: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  void _showAccountDeletionReviewDialog(MemberUpdateRequestModel req) {
    final isPending = req.status == 'pending';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Account Deletion Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Member: ${req.memberName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('MID: ${req.memberMid}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F766E))),
                    Text('Family: ${req.familyName}', style: TextStyle(color: Colors.grey.shade700)),
                    if (req.requestedByPhone.isNotEmpty)
                      Text('Phone: ${req.requestedByPhone}', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Text('Submitted: ${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Reason provided by member:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  req.description.isNotEmpty ? req.description : 'No reason provided.',
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
              if (req.adminNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Admin Note: ${req.adminNote}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
              ],
              const SizedBox(height: 14),
              const Text(
                '• Approve: Permanently deletes the member record and login access from the Samaj database.\n• Reject: Dismisses the request and the user account stays active and normal as usual.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (isPending) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                _promptRejectDialog(req);
              },
              child: const Text('Reject Request', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _quickApprove(req);
              },
              child: const Text('Approve & Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------- ADMIN REVIEW & EDIT SHEET ----------------
class _AdminReviewSheet extends StatefulWidget {
  final MemberUpdateRequestModel request;
  final List<String> bloodGroups;
  final List<String> marriageStatuses;
  final Function(Map<String, dynamic> updates, String? photoUrl, String adminNote) onApprove;

  const _AdminReviewSheet({
    required this.request,
    required this.bloodGroups,
    required this.marriageStatuses,
    required this.onApprove,
  });

  @override
  State<_AdminReviewSheet> createState() => _AdminReviewSheetState();
}

class _AdminReviewSheetState extends State<_AdminReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  late TextEditingController _adminNoteController;
  String _selectedBloodGroup = '';
  String _selectedMarriageStatus = '';
  bool _includePhoto = true;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _adminNoteController = TextEditingController(text: widget.request.adminNote);

    widget.request.fieldUpdates.forEach((key, value) {
      if (key == 'bloodGroup') {
        _selectedBloodGroup = value.toString();
      } else if (key == 'marriageStatus') {
        _selectedMarriageStatus = value.toString();
      } else if (key != 'photo_update_requested') {
        _controllers[key] = TextEditingController(text: value.toString());
      }
    });

    _includePhoto = widget.request.newPhotoUrl.isNotEmpty;
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _adminNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Review & Edit Request',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Member: ${widget.request.memberName} (${widget.request.memberMid})',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo Section if requested
                        if (widget.request.newPhotoUrl.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Profile Photo Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Switch(
                                      value: _includePhoto,
                                      activeColor: const Color(0xFF10B981),
                                      onChanged: (val) => setState(() => _includePhoto = val),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        const Text('Current', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        CircleAvatar(
                                          radius: 35,
                                          backgroundImage: widget.request.currentPhotoUrl.isNotEmpty
                                              ? CachedNetworkImageProvider(widget.request.currentPhotoUrl)
                                              : null,
                                          child: widget.request.currentPhotoUrl.isEmpty
                                              ? const Icon(Icons.person, size: 35)
                                              : null,
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.arrow_forward, color: Color(0xFF0F766E)),
                                    Column(
                                      children: [
                                        const Text('New Replacement', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                        const SizedBox(height: 4),
                                        CircleAvatar(
                                          radius: 35,
                                          backgroundImage: CachedNetworkImageProvider(widget.request.newPhotoUrl),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Field Controllers (Admin can edit any field before applying!)
                        if (_controllers.isNotEmpty || _selectedBloodGroup.isNotEmpty || _selectedMarriageStatus.isNotEmpty) ...[
                          const Text('Review & Adjust Field Values:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          ..._controllers.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: entry.value,
                                decoration: InputDecoration(
                                  labelText: _formatKeyLabel(entry.key),
                                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            );
                          }),

                          // Blood Group Dropdown
                          if (_selectedBloodGroup.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              value: widget.bloodGroups.contains(_selectedBloodGroup) ? _selectedBloodGroup : 'B+',
                              decoration: const InputDecoration(
                                labelText: 'Blood Group',
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                              items: widget.bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                              onChanged: (v) => setState(() => _selectedBloodGroup = v ?? 'B+'),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Marriage Status Dropdown
                          if (_selectedMarriageStatus.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              value: widget.marriageStatuses.contains(_selectedMarriageStatus) ? _selectedMarriageStatus : 'unmarried',
                              decoration: const InputDecoration(
                                labelText: 'Marriage Status',
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                              items: widget.marriageStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                              onChanged: (v) => setState(() => _selectedMarriageStatus = v ?? 'unmarried'),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],

                        // Admin Note input
                        const Text('Admin Note / Feedback to Member (Optional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _adminNoteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Approved and profile updated by Samaj committee',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final Map<String, dynamic> finalUpdates = {};
                              _controllers.forEach((k, c) {
                                finalUpdates[k] = c.text.trim();
                              });
                              if (_selectedBloodGroup.isNotEmpty) finalUpdates['bloodGroup'] = _selectedBloodGroup;
                              if (_selectedMarriageStatus.isNotEmpty) finalUpdates['marriageStatus'] = _selectedMarriageStatus;

                              widget.onApprove(
                                finalUpdates,
                                _includePhoto && widget.request.newPhotoUrl.isNotEmpty ? widget.request.newPhotoUrl : null,
                                _adminNoteController.text.trim().isNotEmpty
                                    ? _adminNoteController.text.trim()
                                    : 'Approved by Committee',
                              );
                            },
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Approve & Apply to Member Profile',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatKeyLabel(String key) {
    if (key == 'fullName') return 'Full Name';
    if (key == 'surname') return 'Surname';
    if (key == 'fatherName') return 'Father Name';
    if (key == 'motherName') return 'Mother Name';
    if (key == 'birthDate') return 'Birth Date';
    if (key == 'nativeHome') return 'Native Home';
    if (key == 'gotra') return 'Gotra';
    if (key == 'phone') return 'Phone Number';
    if (key == 'whatsapp') return 'WhatsApp';
    if (key == 'email') return 'Email';
    if (key == 'address') return 'Residential Address';
    if (key == 'googleMapLink') return 'Google Maps Link';
    if (key == 'education') return 'Education';
    return key;
  }
}
