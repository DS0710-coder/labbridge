import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiService().baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showChangeUrlDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Configure Relay Server URL', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use http://10.0.2.2:8000 for Android emulator or your local PC IP address (e.g. http://192.168.1.100:8000) for real phone over Wi-Fi.',
              style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'http://10.0.2.2:8000',
                hintStyle: const TextStyle(color: Color(0xFF6B6B80)),
                filled: true,
                fillColor: const Color(0xFF0A0A0F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService().setBaseUrl(_urlController.text.trim());
              if (mounted) setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Server URL updated!'), backgroundColor: Color(0xFF6C63FF)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Save URL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final transfer = Provider.of<TransferProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Settings & Device Status',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111118),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E2E)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.phone_android_rounded, color: Color(0xFF6C63FF), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.deviceName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone: ${auth.phone ?? "Not Verified"}',
                          style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Server URL configuration card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111118),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E2E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Relay Server Endpoint',
                        style: TextStyle(color: Color(0xFFE8E8F0), fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      IconButton(
                        onPressed: _showChangeUrlDialog,
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF6C63FF), size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ApiService().baseUrl,
                    style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Files are relayed in-memory without disk storage on this server.',
                    style: TextStyle(color: Color(0xFF6B6B80), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Session Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111118),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E2E)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active PC Pairing Session',
                        style: TextStyle(color: Color(0xFFE8E8F0), fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transfer.isPaired ? 'Connected over WebSocket' : 'Not Paired',
                        style: TextStyle(
                          color: transfer.isPaired ? const Color(0xFF22C55E) : const Color(0xFF6B6B80),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (transfer.isPaired)
                    ElevatedButton(
                      onPressed: transfer.disconnectSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                      ),
                      child: const Text('Unpair'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () async {
                transfer.disconnectSession();
                await auth.logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout Device', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
