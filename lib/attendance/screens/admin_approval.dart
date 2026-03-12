// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// const String baseUrl = 'http://192.168.29.104:3000';
// //  PENDING REQUESTS LIST PAGE

// class AdminApprovalPage extends StatefulWidget {
//   const AdminApprovalPage({super.key});

//   @override
//   State<AdminApprovalPage> createState() => _AdminApprovalPageState();
// }

// class _AdminApprovalPageState extends State<AdminApprovalPage> {
//   // ─── Theme ────────────────────────────────────────────────────────────────
//   static const Color _primary = Color(0xFF0F766E);
//   static const Color _primaryDk = Color(0xFF0D9488);
//   static const Color _surface = Color(0xFFF8FAFC);
//   static const Color _card = Colors.white;
//   static const Color _border = Color(0xFFE5E7EB);
//   static const Color _textDark = Color(0xFF111827);
//   static const Color _textMid = Color(0xFF6B7280);

//   List _requests = [];
//   bool _loading = true;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _fetchRequests();
//   }

//   Future<void> _fetchRequests() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final res = await http.get(Uri.parse('$baseUrl/admin/pending-requests'));
//       if (res.statusCode == 200) {
//         setState(() => _requests = jsonDecode(res.body));
//       } else {
//         setState(() => _error = 'Server error (${res.statusCode})');
//       }
//     } catch (e) {
//       setState(() => _error = 'Error: $e');
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _surface,
//       appBar: AppBar(
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [_primary, _primaryDk],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: const Text(
//           'Pending Requests',
//           style: TextStyle(
//             fontWeight: FontWeight.w700,
//             fontSize: 18,
//             color: Colors.white,
//           ),
//         ),
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator(color: _primary))
//           : _error != null
//           ? _buildErrorState()
//           : _requests.isEmpty
//           ? _buildEmptyState()
//           : RefreshIndicator(
//               onRefresh: _fetchRequests,
//               color: _primary,
//               child: ListView.builder(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 16,
//                 ),
//                 itemCount: _requests.length,
//                 itemBuilder: (context, index) =>
//                     _buildRequestCard(_requests[index]),
//               ),
//             ),
//     );
//   }

//   Widget _buildRequestCard(Map r) {
//     final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
//     final isNew = r['request_type'] == 'NEW';
//     final badgeColor = isNew
//         ? const Color(0xFF0F766E)
//         : const Color(0xFF2563EB);
//     final badgeBg = isNew ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: _card,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _border),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(14),
//         onTap: () async {
//           final result = await Navigator.push(
//             context,
//             MaterialPageRoute(builder: (_) => ApprovalDetailPage(request: r)),
//           );
//           if (result == true) _fetchRequests();
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Row(
//             children: [
//               // Avatar
//               Container(
//                 width: 52,
//                 height: 52,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFECFDF5),
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: _primary.withOpacity(0.3),
//                     width: 1.5,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     name.isNotEmpty ? name[0].toUpperCase() : '?',
//                     style: const TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                       color: _primary,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               // Info
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       name.isEmpty ? 'Unknown' : name,
//                       style: const TextStyle(
//                         fontSize: 15,
//                         fontWeight: FontWeight.w700,
//                         color: _textDark,
//                       ),
//                     ),
//                     const SizedBox(height: 3),
//                     Text(
//                       '${r['department_name'] ?? 'N/A'}  ·  ${r['role_name'] ?? 'N/A'}',
//                       style: const TextStyle(fontSize: 12, color: _textMid),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       r['email_id'] ?? '',
//                       style: const TextStyle(fontSize: 12, color: _textMid),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 10),
//               // Badge + chevron
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: badgeBg,
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(color: badgeColor.withOpacity(0.35)),
//                     ),
//                     child: Text(
//                       r['request_type']?.toString() ?? '',
//                       style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                         color: badgeColor,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   const Icon(
//                     Icons.chevron_right_rounded,
//                     color: _textMid,
//                     size: 20,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     return RefreshIndicator(
//       onRefresh: _fetchRequests,
//       color: _primary,
//       child: CustomScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         slivers: [
//           SliverFillRemaining(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(
//                   Icons.error_outline_rounded,
//                   color: Color(0xFFDC2626),
//                   size: 48,
//                 ),
//                 const SizedBox(height: 12),
//                 Text(_error!, style: const TextStyle(color: _textMid)),
//                 const SizedBox(height: 8),
//                 TextButton.icon(
//                   onPressed: _fetchRequests,
//                   icon: const Icon(Icons.refresh_rounded),
//                   label: const Text('Pull down or tap to retry'),
//                   style: TextButton.styleFrom(foregroundColor: _primary),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return RefreshIndicator(
//       onRefresh: _fetchRequests,
//       color: _primary,
//       child: CustomScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         slivers: [
//           SliverFillRemaining(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   Icons.inbox_outlined,
//                   size: 64,
//                   color: Colors.grey.shade300,
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'No pending requests',
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: _textMid,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 const Text(
//                   'Pull down to refresh',
//                   style: TextStyle(fontSize: 13, color: _textMid),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// //  DETAIL / APPROVAL PAGE
// // ─────────────────────────────────────────────────────────────────────────────

// class ApprovalDetailPage extends StatelessWidget {
//   final Map request;
//   const ApprovalDetailPage({super.key, required this.request});

//   // ─── Theme ────────────────────────────────────────────────────────────────
//   static const Color _primary = Color(0xFF0F766E);
//   static const Color _primaryDk = Color(0xFF0D9488);
//   static const Color _surface = Color(0xFFF8FAFC);
//   static const Color _card = Colors.white;
//   static const Color _border = Color(0xFFE5E7EB);
//   static const Color _textDark = Color(0xFF111827);
//   static const Color _textMid = Color(0xFF6B7280);

//   // ─── Helpers ──────────────────────────────────────────────────────────────
//   String _fmt(dynamic date) {
//     if (date == null || date.toString().isEmpty) return '-';
//     try {
//       final d = DateTime.parse(date.toString());
//       return '${d.day.toString().padLeft(2, '0')}-'
//           '${d.month.toString().padLeft(2, '0')}-'
//           '${d.year}';
//     } catch (_) {
//       return date.toString();
//     }
//   }

//   // ─── Info field (label + value stacked) ───────────────────────────────────
//   Widget _infoTile({
//     required IconData icon,
//     required String label,
//     required String value,
//     int maxLines = 4,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 14),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(7),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF1F5F9),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, size: 16, color: _textMid),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     fontSize: 11,
//                     color: _textMid,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 3),
//                 Text(
//                   value.isEmpty ? '-' : value,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     color: _textDark,
//                     fontWeight: FontWeight.w600,
//                   ),
//                   maxLines: maxLines,
//                   overflow: TextOverflow.visible,
//                   softWrap: true,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Section header ────────────────────────────────────────────────────────
//   Widget _sectionHeader(IconData icon, String title, Color color) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, color: color, size: 18),
//           ),
//           const SizedBox(width: 10),
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w700,
//               color: _textDark,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Card wrapper ──────────────────────────────────────────────────────────
//   Widget _sectionCard({required Widget child}) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _card,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _border),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }

//   // ─── Profile header ────────────────────────────────────────────────────────
//   Widget _profileHeader(BuildContext context) {
//     final name =
//         '${request['first_name'] ?? ''} ${request['mid_name'] ?? ''} ${request['last_name'] ?? ''}'
//             .trim();
//     final isNew = request['request_type'] == 'NEW';

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [_primary, _primaryDk],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: _primary.withOpacity(0.3),
//             blurRadius: 16,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 64,
//                 height: 64,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: Colors.white.withOpacity(0.5),
//                     width: 2,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     name.isNotEmpty ? name[0].toUpperCase() : '?',
//                     style: const TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       name.isEmpty ? 'Unknown' : name,
//                       style: const TextStyle(
//                         fontSize: 19,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '${request['department_name'] ?? 'N/A'}  ·  ${request['role_name'] ?? 'N/A'}',
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.white.withOpacity(0.85),
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       request['email_id'] ?? '',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.white.withOpacity(0.7),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 14),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: Colors.white.withOpacity(0.3)),
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   isNew ? Icons.person_add_rounded : Icons.edit_rounded,
//                   size: 14,
//                   color: Colors.white,
//                 ),
//                 const SizedBox(width: 6),
//                 Text(
//                   isNew ? 'New Employee Request' : 'Update Request',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Education section ────────────────────────────────────────────────────
//   Widget _educationSection(List educations) {
//     return _sectionCard(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _sectionHeader(
//             Icons.school_rounded,
//             'Education Details',
//             const Color(0xFF0E9F6E),
//           ),
//           if (educations.isEmpty)
//             const Text('-', style: TextStyle(color: _textMid))
//           else
//             ...educations.map((e) {
//               const levelColors = {
//                 '10': Color(0xFF6366F1),
//                 '12': Color(0xFF8B5CF6),
//                 'Diploma': Color(0xFFF59E0B),
//                 'UG': Color(0xFF0E9F6E),
//                 'PG': Color(0xFF1A56DB),
//                 'PhD': Color(0xFFEF4444),
//               };
//               final level = e['education_level']?.toString() ?? '';
//               final badgeColor = levelColors[level] ?? _textMid;

//               return Container(
//                 width: double.infinity,
//                 margin: const EdgeInsets.only(bottom: 10),
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: badgeColor.withOpacity(0.04),
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(color: badgeColor.withOpacity(0.2)),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 10,
//                             vertical: 3,
//                           ),
//                           decoration: BoxDecoration(
//                             color: badgeColor.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(20),
//                             border: Border.all(
//                               color: badgeColor.withOpacity(0.3),
//                             ),
//                           ),
//                           child: Text(
//                             level,
//                             style: TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w700,
//                               color: badgeColor,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         if (e['stream'] != null &&
//                             e['stream'].toString().isNotEmpty)
//                           Text(
//                             e['stream'].toString(),
//                             style: const TextStyle(
//                               fontSize: 13,
//                               fontWeight: FontWeight.w600,
//                               color: _textDark,
//                             ),
//                           ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Wrap(
//                       spacing: 16,
//                       runSpacing: 4,
//                       children: [
//                         _eduChip(
//                           Icons.percent_rounded,
//                           'Score: ${e['score']?.toString() ?? '-'}',
//                         ),
//                         _eduChip(
//                           Icons.calendar_today_rounded,
//                           'Year: ${e['year_of_passout']?.toString() ?? '-'}',
//                         ),
//                         if (e['university'] != null &&
//                             e['university'].toString().isNotEmpty)
//                           _eduChip(
//                             Icons.school_outlined,
//                             e['university'].toString(),
//                           ),
//                         if (e['college_name'] != null &&
//                             e['college_name'].toString().isNotEmpty)
//                           _eduChip(
//                             Icons.account_balance_rounded,
//                             e['college_name'].toString(),
//                           ),
//                       ],
//                     ),
//                   ],
//                 ),
//               );
//             }).toList(),
//         ],
//       ),
//     );
//   }

//   Widget _eduChip(IconData icon, String label) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 12, color: _textMid),
//         const SizedBox(width: 4),
//         Text(label, style: const TextStyle(fontSize: 12, color: _textMid)),
//       ],
//     );
//   }

//   // ─── Auto-rejected dialog ──────────────────────────────────────────────────
//   Future<void> _showAutoRejectedDialog(BuildContext context, String reason) {
//     return showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         title: Row(
//           children: [
//             Icon(Icons.block_rounded, color: Colors.orange[800], size: 24),
//             const SizedBox(width: 10),
//             const Expanded(
//               child: Text(
//                 'Auto-Rejected',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFFEA580C),
//                   fontSize: 17,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'This request was automatically rejected due to duplicate data:',
//               style: TextStyle(fontSize: 13, color: Colors.grey[600]),
//             ),
//             const SizedBox(height: 10),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFFFF7ED),
//                 border: Border.all(color: Colors.orange),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 reason,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                   color: Color(0xFF9A3412),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               'The requester must fix the duplicate data and resubmit.',
//               style: TextStyle(fontSize: 12, color: Colors.grey[500]),
//             ),
//           ],
//         ),
//         actions: [
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF0F766E),
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: () {
//               Navigator.of(context).pop();
//               Navigator.of(context).pop(true);
//             },
//             child: const Text('OK, Go Back'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Approve ───────────────────────────────────────────────────────────────
//   Future<void> _approve(BuildContext context) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) =>
//           const Center(child: CircularProgressIndicator(color: _primary)),
//     );

//     final res = await http.post(
//       Uri.parse('$baseUrl/admin/approve-request'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'request_id': request['request_id']}),
//     );

//     if (context.mounted) Navigator.of(context).pop();
//     if (!context.mounted) return;

//     final data = jsonDecode(res.body);

//     if (res.statusCode == 409) {
//       await _showAutoRejectedDialog(
//         context,
//         data['error'] ?? 'Duplicate data found. Request was auto-rejected.',
//       );
//       return;
//     }

//     if (res.statusCode == 200 || res.statusCode == 201) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(data['message'] ?? 'Approved successfully'),
//           backgroundColor: const Color(0xFF059669),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//       Navigator.pop(context, true);
//       return;
//     }

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         title: const Text('Approval Failed'),
//         content: Text(
//           data['error'] ?? 'Something went wrong. Please try again.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Reject ────────────────────────────────────────────────────────────────
//   void _reject(BuildContext context) {
//     final ctrl = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         title: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(7),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFFEF2F2),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const Icon(
//                 Icons.cancel_outlined,
//                 color: Color(0xFFDC2626),
//                 size: 18,
//               ),
//             ),
//             const SizedBox(width: 10),
//             const Text(
//               'Reject Request',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Please provide a reason for rejection:',
//               style: TextStyle(fontSize: 13, color: Colors.grey[600]),
//             ),
//             const SizedBox(height: 10),
//             TextField(
//               controller: ctrl,
//               maxLines: 3,
//               decoration: InputDecoration(
//                 hintText: 'Enter reject reason...',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                   borderSide: const BorderSide(color: _primary, width: 2),
//                 ),
//                 contentPadding: const EdgeInsets.all(12),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel', style: TextStyle(color: _textMid)),
//           ),
//           ElevatedButton.icon(
//             icon: const Icon(Icons.cancel_rounded, size: 16),
//             label: const Text('Reject'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFFDC2626),
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: () async {
//               if (ctrl.text.trim().isEmpty) return;
//               await http.post(
//                 Uri.parse('$baseUrl/admin/reject-request'),
//                 headers: {'Content-Type': 'application/json'},
//                 body: jsonEncode({
//                   'request_id': request['request_id'],
//                   'reject_reason': ctrl.text,
//                 }),
//               );
//               Navigator.pop(context);
//               Navigator.pop(context, true);
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isMobile = MediaQuery.of(context).size.width < 600;
//     final hasRejectReason =
//         request['reject_reason'] != null &&
//         request['reject_reason'].toString().isNotEmpty;

//     return Scaffold(
//       backgroundColor: _surface,
//       appBar: AppBar(
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [_primary, _primaryDk],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         foregroundColor: Colors.white,
//         title: const Text(
//           'Request Details',
//           style: TextStyle(
//             fontWeight: FontWeight.w700,
//             fontSize: 18,
//             color: Colors.white,
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(isMobile ? 16 : 20),
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 900),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // ── Profile header ────────────────────────────────────
//                 _profileHeader(context),
//                 const SizedBox(height: 14),

//                 // ── Previous rejection banner ─────────────────────────
//                 if (hasRejectReason)
//                   Container(
//                     margin: const EdgeInsets.only(bottom: 12),
//                     padding: const EdgeInsets.all(14),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFFEF2F2),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: const Color(0xFFFCA5A5)),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Icon(
//                           Icons.warning_amber_rounded,
//                           color: Color(0xFFDC2626),
//                           size: 20,
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'Previous Rejection Reason',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   color: Color(0xFFDC2626),
//                                   fontSize: 13,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 request['reject_reason'].toString(),
//                                 style: const TextStyle(
//                                   color: Color(0xFFB91C1C),
//                                   fontSize: 13,
//                                   height: 1.4,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                 // ── Personal Info ──────────────────────────────────────
//                 _sectionCard(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _sectionHeader(
//                         Icons.person_outline_rounded,
//                         'Personal Information',
//                         const Color(0xFF1A56DB),
//                       ),
//                       _infoTile(
//                         icon: Icons.badge_outlined,
//                         label: 'Employee ID',
//                         value: request['emp_id']?.toString() ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.wc_rounded,
//                         label: 'Gender',
//                         value: request['gender'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.cake_outlined,
//                         label: 'Date of Birth',
//                         value: _fmt(request['date_of_birth']),
//                       ),
//                       _infoTile(
//                         icon: Icons.person_outline_rounded,
//                         label: 'Father Name',
//                         value: request['father_name'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.phone_android_rounded,
//                         label: 'Emergency Contact',
//                         value: request['emergency_contact'] ?? '-',
//                       ),
//                     ],
//                   ),
//                 ),

//                 // ── Contact ────────────────────────────────────────────
//                 _sectionCard(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _sectionHeader(
//                         Icons.contact_mail_outlined,
//                         'Contact Information',
//                         const Color(0xFF7C3AED),
//                       ),
//                       _infoTile(
//                         icon: Icons.email_outlined,
//                         label: 'Email',
//                         value: request['email_id'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.phone_outlined,
//                         label: 'Phone',
//                         value: request['phone_number'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.home_outlined,
//                         label: 'Permanent Address',
//                         value: request['permanent_address'] ?? '-',
//                         maxLines: 4,
//                       ),
//                       _infoTile(
//                         icon: Icons.location_on_outlined,
//                         label: 'Communication Address',
//                         value: request['communication_address'] ?? '-',
//                         maxLines: 4,
//                       ),
//                     ],
//                   ),
//                 ),

//                 // ── Employment ─────────────────────────────────────────
//                 _sectionCard(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _sectionHeader(
//                         Icons.work_outline_rounded,
//                         'Employment Information',
//                         const Color(0xFFF59E0B),
//                       ),
//                       _infoTile(
//                         icon: Icons.business_outlined,
//                         label: 'Department',
//                         value: request['department_name'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.badge_outlined,
//                         label: 'Role',
//                         value: request['role_name'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.calendar_today_outlined,
//                         label: 'Date of Joining',
//                         value: _fmt(request['date_of_joining']),
//                       ),
//                       if (request['date_of_relieving'] != null &&
//                           request['date_of_relieving'].toString().isNotEmpty)
//                         _infoTile(
//                           icon: Icons.event_busy_outlined,
//                           label: 'Date of Relieving',
//                           value: _fmt(request['date_of_relieving']),
//                         ),
//                       _infoTile(
//                         icon: Icons.category_outlined,
//                         label: 'Employment Type',
//                         value: request['employment_type'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.access_time_outlined,
//                         label: 'Work Type',
//                         value: request['work_type'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.timeline_rounded,
//                         label: 'Years of Experience',
//                         value: request['years_experience']?.toString() ?? '-',
//                       ),
//                     ],
//                   ),
//                 ),

//                 // ── Education ──────────────────────────────────────────
//                 _educationSection((request['education_list'] as List?) ?? []),

//                 // ── Documents ──────────────────────────────────────────
//                 _sectionCard(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _sectionHeader(
//                         Icons.description_outlined,
//                         'Documents & Statutory',
//                         const Color(0xFFEF4444),
//                       ),
//                       _infoTile(
//                         icon: Icons.credit_card_outlined,
//                         label: 'Aadhar Number',
//                         value: request['aadhar_number'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.assignment_outlined,
//                         label: 'PAN Number',
//                         value: request['pan_number'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.airplanemode_active_outlined,
//                         label: 'Passport Number',
//                         value: request['passport_number'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.account_balance_rounded,
//                         label: 'PF Number',
//                         value: request['pf_number'] ?? '-',
//                       ),
//                       _infoTile(
//                         icon: Icons.health_and_safety_outlined,
//                         label: 'ESIC Number',
//                         value: request['esic_number'] ?? '-',
//                       ),
//                     ],
//                   ),
//                 ),

//                 // ── Edit reason (UPDATE only) ──────────────────────────
//                 if (request['edit_reason'] != null &&
//                     request['edit_reason'].toString().isNotEmpty)
//                   _sectionCard(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _sectionHeader(
//                           Icons.edit_note_rounded,
//                           'Edit Reason',
//                           const Color(0xFF2563EB),
//                         ),
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFEFF6FF),
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: const Color(0xFFBFDBFE)),
//                           ),
//                           child: Text(
//                             request['edit_reason'].toString(),
//                             style: const TextStyle(
//                               fontSize: 13,
//                               color: _textDark,
//                               height: 1.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                 const SizedBox(height: 8),

//                 // ── Action buttons ─────────────────────────────────────
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         icon: const Icon(
//                           Icons.check_circle_outline_rounded,
//                           size: 18,
//                         ),
//                         label: const Text(
//                           'APPROVE',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 0.5,
//                           ),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: _primary,
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           elevation: 0,
//                         ),
//                         onPressed: () => _approve(context),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         icon: const Icon(Icons.cancel_outlined, size: 18),
//                         label: const Text(
//                           'REJECT',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 0.5,
//                           ),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFFDC2626),
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           elevation: 0,
//                         ),
//                         onPressed: () => _reject(context),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 24),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://192.168.29.216:3000';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens — identical to EmployeeProfileScreen & LeaveApprovalScreen
// ─────────────────────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _purple = Color(0xFF7C3AED);
const Color _amber = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
//  LIST PAGE
// ─────────────────────────────────────────────────────────────────────────────
class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});

  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  List _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('$baseUrl/admin/pending-requests'));
      if (res.statusCode == 200) {
        setState(() => _requests = jsonDecode(res.body));
      } else {
        setState(() => _error = 'Server error (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _primary,
                strokeWidth: 2.5,
              ),
            )
          : _error != null
          ? _buildError()
          : _requests.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              color: _primary,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    itemCount: _requests.length,
                    itemBuilder: (_, i) => _RequestCard(
                      request: _requests[i],
                      onRefresh: _fetchRequests,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x401A56DB),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pending Requests',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Review & approve employee requests',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() => RefreshIndicator(
    onRefresh: _fetchRequests,
    color: _primary,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: _red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _textMid),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _fetchRequests,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => RefreshIndicator(
    onRefresh: _fetchRequests,
    color: _primary,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 36,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'All clear!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'No pending requests right now.',
                style: TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _fetchRequests,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Request Card (list item)
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map request;
  final VoidCallback onRefresh;
  const _RequestCard({required this.request, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final name = '${request['first_name'] ?? ''} ${request['last_name'] ?? ''}'
        .trim();
    final isNew = request['request_type'] == 'NEW';
    final typeColor = isNew ? _accent : _primary;
    final typeBg = isNew ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalDetailPage(request: request),
            ),
          );
          if (result == true) onRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar — blue gradient initials square
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unknown' : name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [request['department_name'], request['role_name']]
                          .where((e) => e != null && e.toString().isNotEmpty)
                          .join('  ·  '),
                      style: const TextStyle(fontSize: 12, color: _textMid),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request['email_id'] ?? '',
                      style: const TextStyle(fontSize: 12, color: _textLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Type badge + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: typeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          request['request_type']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _textLight,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETAIL / APPROVAL PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ApprovalDetailPage extends StatelessWidget {
  final Map request;
  const ApprovalDetailPage({super.key, required this.request});

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _fmt(dynamic date) {
    if (date == null || date.toString().isEmpty) return '-';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day.toString().padLeft(2, '0')} '
          '${_mon(d.month)} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _mon(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  // ── Section card (same style as EmployeeProfile) ──────────────────────────
  Widget _sectionCard({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(
    IconData icon,
    String title,
    Color color,
    Color bgColor,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _border),
      ],
    );
  }

  // ── Info row — label + value tiles matching EmployeeProfile style ──────────
  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 4,
    Color? valueColor,
  }) {
    final isEmpty = value.isEmpty || value == '-';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Icon(icon, size: 14, color: _textMid),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? '-' : value,
              maxLines: maxLines,
              overflow: TextOverflow.visible,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                color: isEmpty ? _textLight : (valueColor ?? _textDark),
                fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerRow() =>
      const Divider(height: 1, thickness: 1, color: _border);

  // ── Hero card ─────────────────────────────────────────────────────────────
  Widget _profileHero() {
    final name = [
      request['first_name'],
      request['mid_name'],
      request['last_name'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    final isNew = request['request_type'] == 'NEW';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Unknown' : name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            request['role_name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            request['department_name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isNew
                                      ? Icons.person_add_rounded
                                      : Icons.edit_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isNew
                                      ? 'New Employee Request'
                                      : 'Update Request',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Stats strip
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _heroStat(
                      request['request_type'] == 'NEW'
                          ? 'NEW'
                          : (request['emp_id']?.toString() ?? '-'),
                      request['request_type'] == 'NEW' ? 'REQUEST' : 'EMP ID',
                    ),
                    _heroVDiv(),
                    _heroStat(
                      _shorten(request['employment_type']?.toString()),
                      'TYPE',
                    ),
                    _heroVDiv(),
                    _heroStat(
                      _shorten(request['work_type']?.toString()),
                      'WORK',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shorten(String? v) {
    if (v == null || v.isEmpty) return '-';
    // "Full Time" → "Full Time", "Permanent" → "Perm", "Contract" → "Contract"
    const map = {
      'Full Time': 'Full Time',
      'Part Time': 'Part Time',
      'Permanent': 'Permanent',
      'Contract': 'Contract',
      'Intern': 'Intern',
    };
    return map[v] ?? v;
  }

  Widget _heroStat(String v, String l) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _heroVDiv() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.12));

  // ── Education ─────────────────────────────────────────────────────────────
  Widget _educationSection(List educations) {
    const levelColors = {
      '10': Color(0xFF6366F1),
      '12': Color(0xFF8B5CF6),
      'Diploma': Color(0xFFF59E0B),
      'UG': Color(0xFF0E9F6E),
      'PG': Color(0xFF1A56DB),
      'PhD': Color(0xFFEF4444),
    };
    const levelLabels = {
      '10': 'Class 10 (SSLC)',
      '12': 'Class 12 (HSC)',
      'Diploma': 'Diploma',
      'UG': 'Under Graduate',
      'PG': 'Post Graduate',
      'PhD': 'Doctorate (PhD)',
    };

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.school_rounded,
            'Education Details',
            _accent,
            const Color(0xFFECFDF5),
          ),
          if (educations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No education records',
                style: TextStyle(color: _textMid, fontSize: 13),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: educations.map<Widget>((e) {
                  final level = e['education_level']?.toString() ?? '';
                  final color = levelColors[level] ?? _textMid;
                  final label = levelLabels[level] ?? level;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                level,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e['stream']?.toString().trim().isNotEmpty ==
                                        true
                                    ? e['stream'].toString()
                                    : label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (e['score'] != null)
                              _eduChip(
                                Icons.percent_rounded,
                                '${e['score']}%',
                                color,
                              ),
                            if (e['year_of_passout'] != null)
                              _eduChip(
                                Icons.calendar_today_rounded,
                                e['year_of_passout'].toString(),
                                _purple,
                              ),
                            if (e['college_name']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true)
                              _eduChip(
                                Icons.account_balance_rounded,
                                e['college_name'].toString(),
                                _primary,
                              ),
                            if (e['university']?.toString().trim().isNotEmpty ==
                                true)
                              _eduChip(
                                Icons.school_outlined,
                                e['university'].toString(),
                                _amber,
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eduChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ── Auto-reject dialog ────────────────────────────────────────────────────
  Future<void> _showAutoRejectedDialog(BuildContext context, String reason) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.block_rounded,
                color: Colors.orange[800],
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Auto-Rejected',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEA580C),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This request was automatically rejected due to duplicate data:',
              style: TextStyle(fontSize: 13, color: _textMid),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A3412),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The requester must fix the duplicate data and resubmit.',
              style: TextStyle(fontSize: 12, color: _textLight),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text(
              'OK, Go Back',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Approve ───────────────────────────────────────────────────────────────
  Future<void> _approve(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
      ),
    );
    final res = await http.post(
      Uri.parse('$baseUrl/admin/approve-request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'request_id': request['request_id']}),
    );
    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;

    final data = jsonDecode(res.body);

    if (res.statusCode == 409) {
      await _showAutoRejectedDialog(
        context,
        data['error'] ?? 'Duplicate data. Request auto-rejected.',
      );
      return;
    }
    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                data['message'] ?? 'Approved successfully',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context, true);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Approval Failed',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Text(
          data['error'] ?? 'Something went wrong. Please try again.',
          style: const TextStyle(fontSize: 13, color: _textMid),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Reject ────────────────────────────────────────────────────────────────
  void _reject(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.do_not_disturb_on_rounded,
                color: _red,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reject Request',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for rejection',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textMid,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: _textDark),
              decoration: InputDecoration(
                hintText: 'Briefly describe the reason…',
                hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMid,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await http.post(
                Uri.parse('$baseUrl/admin/reject-request'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'request_id': request['request_id'],
                  'reject_reason': ctrl.text,
                }),
              );
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text(
              'Reject',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRejectReason =
        request['reject_reason'] != null &&
        request['reject_reason'].toString().isNotEmpty;
    final hasEditReason =
        request['edit_reason'] != null &&
        request['edit_reason'].toString().isNotEmpty;

    return Scaffold(
      backgroundColor: _surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x401A56DB),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Request Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Review employee information',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero ────────────────────────────────────────────
                _profileHero(),
                const SizedBox(height: 14),

                // ── Previous rejection banner ────────────────────────
                if (hasRejectReason) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: _red,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Previous Rejection Reason',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _red,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                request['reject_reason'].toString(),
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Personal Info ────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.person_outline_rounded,
                        'Personal Information',
                        _primary,
                        const Color(0xFFEEF2FF),
                      ),
                      _infoTile(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: request['emp_id']?.toString() ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.wc_rounded,
                        label: 'Gender',
                        value: request['gender'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.cake_outlined,
                        label: 'Date of Birth',
                        value: _fmt(request['date_of_birth']),
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Father Name',
                        value: request['father_name'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.phone_android_rounded,
                        label: 'Emergency Contact',
                        value: request['emergency_contact'] ?? '-',
                      ),
                    ],
                  ),
                ),

                // ── Contact ──────────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.contact_mail_outlined,
                        'Contact Information',
                        _purple,
                        const Color(0xFFF5F3FF),
                      ),
                      _infoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: request['email_id'] ?? '-',
                        valueColor: _primary,
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: request['phone_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.home_outlined,
                        label: 'Permanent Address',
                        value: request['permanent_address'] ?? '-',
                        maxLines: 4,
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Communication Address',
                        value: request['communication_address'] ?? '-',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),

                // ── Employment ───────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.work_outline_rounded,
                        'Employment Information',
                        _amber,
                        const Color(0xFFFFFBEB),
                      ),
                      _infoTile(
                        icon: Icons.business_outlined,
                        label: 'Department',
                        value: request['department_name'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: request['role_name'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date of Joining',
                        value: _fmt(request['date_of_joining']),
                      ),
                      if (request['date_of_relieving'] != null &&
                          request['date_of_relieving']
                              .toString()
                              .isNotEmpty) ...[
                        _dividerRow(),
                        _infoTile(
                          icon: Icons.event_busy_outlined,
                          label: 'Date of Relieving',
                          value: _fmt(request['date_of_relieving']),
                        ),
                      ],
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.category_outlined,
                        label: 'Employment Type',
                        value: request['employment_type'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.access_time_outlined,
                        label: 'Work Type',
                        value: request['work_type'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.timeline_rounded,
                        label: 'Experience',
                        value: '${request['years_experience'] ?? '-'} yrs',
                      ),
                    ],
                  ),
                ),

                // ── Education ────────────────────────────────────────
                _educationSection((request['education_list'] as List?) ?? []),

                // ── Documents ────────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.description_outlined,
                        'Documents & Statutory',
                        _red,
                        const Color(0xFFFFF1F2),
                      ),
                      _infoTile(
                        icon: Icons.credit_card_outlined,
                        label: 'Aadhar Number',
                        value: request['aadhar_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.assignment_outlined,
                        label: 'PAN Number',
                        value: request['pan_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.airplanemode_active_outlined,
                        label: 'Passport Number',
                        value: request['passport_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.account_balance_rounded,
                        label: 'PF Number',
                        value: request['pf_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.health_and_safety_outlined,
                        label: 'ESIC Number',
                        value: request['esic_number'] ?? '-',
                      ),
                    ],
                  ),
                ),

                // ── Edit Reason (UPDATE only) ────────────────────────
                if (hasEditReason)
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(
                          Icons.edit_note_rounded,
                          'Edit Reason',
                          _primary,
                          const Color(0xFFEEF2FF),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFBFD0FF),
                              ),
                            ),
                            child: Text(
                              request['edit_reason'].toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textDark,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Action buttons ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'APPROVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () => _approve(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text(
                          'REJECT',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () => _reject(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
