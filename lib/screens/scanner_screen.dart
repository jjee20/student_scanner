import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'display_screen.dart';

enum ScanState { idle, success, late, error }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _db = FirebaseFirestore.instance;
  final _controller = MobileScannerController();
  final _last = <String, DateTime>{};

  bool _busy = false;
  bool _torchOn = false;
  bool _isTimeIn = true; // Toggle state: true = Time In, false = Time Out

  ScanState _state = ScanState.idle;
  String _title = 'Ready to scan';
  String _subtitle = 'Point the camera at a student ID barcode';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------- Scan logic ----------
  void _setResult(ScanState s, String title, String subtitle) {
    if (!mounted) return;
    setState(() {
      _state = s;
      _title = title;
      _subtitle = subtitle;
    });
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy || cap.barcodes.isEmpty) return;
    final id = cap.barcodes.first.rawValue?.trim();
    if (id == null || id.isEmpty) return;

    final now = DateTime.now();
    final prev = _last[id];
    if (prev != null && now.difference(prev).inSeconds < 10)
      return; // 10s cooldown

    _busy = true;
    try {
      final doc = await _db.collection('students').doc(id).get();
      if (!doc.exists) {
        _setResult(ScanState.error, 'ID Not Found', 'Scanned code: $id');
      } else {
        final d = doc.data()!;
        _last[id] = now;

        final scanType = _isTimeIn ? 'Time In' : 'Time Out';

        // Time-In: Late if after 7:30 AM
        // Time-Out: Early if before 4:00 PM (16:00)
        String status = 'On Time';
        bool isStatusLateOrEarly = false;

        if (_isTimeIn) {
          final isLate = now.hour > 7 || (now.hour == 7 && now.minute > 30);
          status = isLate ? 'Late' : 'On Time';
          isStatusLateOrEarly = isLate;
        } else {
          final isEarly = now.hour < 16;
          status = isEarly ? 'Early' : 'On Time';
          isStatusLateOrEarly = isEarly;
        }

        // Save complete scan record to Firestore
        await _db.collection('scans').add({
          'studentId': id,
          'lrn': d['lrn'] ?? id,
          'name': d['name'] ?? 'Unknown Student',
          'grade': d['grade'] ?? '',
          'section': d['section'] ?? '',
          'strand': d['strand'] ?? '',
          'guardianName': d['guardianName'] ?? '',
          'guardianContact': d['guardianContact'] ?? '',
          'photoUrl': d['photoUrl'] ?? '',
          'type': scanType,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _setResult(
          isStatusLateOrEarly ? ScanState.late : ScanState.success,
          '${d['name']}',
          '$scanType • Grade ${d['grade']} ${d['section']} • $status',
        );
      }
    } catch (e) {
      _setResult(ScanState.error, 'Something went wrong', '$e');
    } finally {
      _busy = false;
    }
  }

  // ---------- Actions ----------
  void _openDisplay() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DisplayScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to scan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ID Scanner',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (wide)
            TextButton.icon(
              onPressed: _openDisplay,
              icon: const Icon(Icons.tv_rounded),
              label: const Text('TV Display Mode'),
            )
          else
            IconButton(
              tooltip: 'TV Display Mode',
              onPressed: _openDisplay,
              icon: const Icon(Icons.tv_rounded),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: scheme.primary),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Time In / Time Out Mode Selector
                  _modeSelector(scheme),
                  const SizedBox(height: 16),
                  Expanded(child: _cameraView(scheme)),
                  const SizedBox(height: 16),
                  _resultCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Segmented Mode Selector Button Widget
  Widget _modeSelector(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: true,
            label: Text(
              'TIME IN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: Icon(Icons.login_rounded),
          ),
          ButtonSegment<bool>(
            value: false,
            label: Text(
              'TIME OUT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: Icon(Icons.logout_rounded),
          ),
        ],
        selected: {_isTimeIn},
        onSelectionChanged: (Set<bool> newSelection) {
          setState(() {
            _isTimeIn = newSelection.first;
          });
        },
        style: ButtonStyle(
          side: WidgetStateProperty.all(
            BorderSide(
              color: _isTimeIn
                  ? Colors.green.shade700
                  : Colors.blueGrey.shade700,
              width: 1.5,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return _isTimeIn
                  ? Colors.green.shade700
                  : Colors.blueGrey.shade800;
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.grey.shade800;
          }),
        ),
      ),
    );
  }

  Widget _cameraView(ColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(color: Colors.black.withOpacity(0.15)),
          Center(
            child: Container(
              width: 240,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isTimeIn
                      ? Colors.greenAccent
                      : Colors.lightBlueAccent,
                  width: 3,
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                _roundButton(
                  icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                  onTap: () async {
                    await _controller.toggleTorch();
                    setState(() => _torchOn = !_torchOn);
                  },
                ),
                const SizedBox(width: 8),
                _roundButton(
                  icon: Icons.cameraswitch_rounded,
                  onTap: () => _controller.switchCamera(),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Mode: ${_isTimeIn ? "TIME IN" : "TIME OUT"} — Align barcode inside frame',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _resultCard() {
    late final Color color;
    late final IconData icon;
    switch (_state) {
      case ScanState.success:
        color = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        break;
      case ScanState.late:
        color = const Color(0xFFEF6C00);
        icon = Icons.schedule_rounded;
        break;
      case ScanState.error:
        color = const Color(0xFFC62828);
        icon = Icons.error_rounded;
        break;
      case ScanState.idle:
        color = Colors.grey.shade600;
        icon = Icons.center_focus_strong_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
