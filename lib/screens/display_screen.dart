import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DisplayScreen extends StatefulWidget {
  const DisplayScreen({super.key});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  static const int _showSeconds = 6;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade900,
              Colors.green.shade700,
              Colors.green.shade500,
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snap) {
                  String key = 'idle';
                  Widget child = _idle();

                  if (snap.hasData && snap.data!.docs.isNotEmpty) {
                    final doc = snap.data!.docs.first;
                    final d = doc.data();
                    final ts =
                        (d['timestamp'] as Timestamp?) ?? Timestamp.now();
                    final time = ts.toDate();
                    if (DateTime.now().difference(time).inSeconds <
                        _showSeconds) {
                      key = doc.id;
                      child = _studentCard(d, time);
                    }
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (w, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1).animate(a),
                        child: w,
                      ),
                    ),
                    child: KeyedSubtree(key: ValueKey(key), child: child),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Back to scanner',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white54,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            const Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Mobile-Based Student ID Barcode Scanning System',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Idle Screen ----------
  Widget _idle() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 96,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Calinan National High School',
              style: TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              DateFormat('hh:mm:ss a').format(now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              DateFormat('EEEE, MMMM d, y').format(now),
              style: const TextStyle(color: Colors.white70, fontSize: 28),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Text(
                'Please scan your ID',
                style: TextStyle(color: Colors.white, fontSize: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Scanned Student Card ----------
  Widget _studentCard(Map<String, dynamic> s, DateTime time) {
    // Extracted Fields with Fallbacks
    final name = (s['name'] as String?)?.trim().isNotEmpty == true
        ? s['name'] as String
        : 'Unknown Student';
    final lrn = s['lrn']?.toString() ?? 'N/A';
    final grade = s['grade']?.toString() ?? 'N/A';
    final section = s['section']?.toString() ?? 'N/A';
    final strand = s['strand']?.toString() ?? 'N/A';
    final scanType = s['type']?.toString() ?? 'Time In';
    final status = s['status']?.toString() ?? 'On Time';
    final photoUrl = s['photoUrl'] as String?;
    final guardianName = s['guardianName']?.toString() ?? 'N/A';
    final guardianContact = s['guardianContact']?.toString() ?? 'N/A';

    final isLate = status.toLowerCase() == 'late';
    final statusColor = isLate
        ? const Color(0xFFEF6C00)
        : const Color(0xFF2E7D32);

    final isTimeOut = scanType.toLowerCase() == 'time out';
    final typeBgColor = isTimeOut
        ? Colors.blueGrey.shade800
        : Colors.green.shade800;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 950,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Status Badges & Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Scan Type Badge (Time In / Time Out)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: typeBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          scanType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Attendance Status Badge (On Time / Late)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor, width: 2),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Scan Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 26,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('hh:mm:ss a').format(time),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 40, thickness: 1.5),

              // Student Information Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo or Initials Fallback
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.shade600,
                        width: 4,
                      ),
                      image: photoUrl != null && photoUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Center(
                            child: Text(
                              _initials(name),
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade800,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 36),

                  // Student Details Grid
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'LRN: $lrn',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Academic Info Cards
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            _infoChip(Icons.school_rounded, 'Grade $grade'),
                            _infoChip(Icons.class_rounded, 'Sec: $section'),
                            if (strand != 'N/A')
                              _infoChip(
                                Icons.architecture_rounded,
                                'Strand: $strand',
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Guardian Emergency Info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.family_restroom_rounded,
                                    size: 20,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Guardian Contact Details',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$guardianName • $guardianContact',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
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
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Helper Info Chip Widget ----------
  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.green.shade800),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
