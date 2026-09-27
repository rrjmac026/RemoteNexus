import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/system_service.dart';
import 'terminal_screen.dart';
import 'files_screen.dart';
import 'processes_screen.dart';
import 'services_screen.dart';
import 'logs_screen.dart';
import 'remote_desktop_screen.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  Map<String, dynamic>? _info;
  bool _initialLoading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final result = await SystemService.getSystemInfo();
    if (!mounted) return;
    setState(() {
      _initialLoading = false;
      if (result != null) {
        _info = result;
        _error = null;
      } else {
        _error = 'Connection lost.';
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withOpacity(0.72)),
          ),
          SafeArea(
            child: _initialLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader(theme)),
                        SliverToBoxAdapter(child: _buildStatsCard(theme)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          sliver: SliverToBoxAdapter(child: _buildActionsGrid(theme)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final online = _error == null && _info != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/images/logo.png', width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _info?['computer_name']?.toString() ?? 'RemoteNexus',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: online ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? 'Online' : (_error ?? 'Connecting...'),
                      style: TextStyle(
                        color: online ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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

  Widget _buildStatsCard(ThemeData theme) {
    if (_info == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(_error ?? 'No data', style: const TextStyle(color: Colors.white70)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _metricRing('CPU', _asDouble(_info!['cpu_percent']), const Color(0xFF9B8CFF)),
                    const SizedBox(width: 16),
                    _metricRing('RAM', _asDouble(_info!['ram_percent']), const Color(0xFF2ECC71)),
                    const SizedBox(width: 16),
                    _metricRing('Disk', _asDouble(_info!['storage_percent']), const Color(0xFFFF8A65)),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(height: 1, color: Colors.white.withOpacity(0.12)),
                const SizedBox(height: 14),
                _infoLine(Icons.memory_rounded, 'OS', _info!['os'].toString()),
                const SizedBox(height: 10),
                _infoLine(Icons.schedule_rounded, 'Uptime', _info!['uptime'].toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return 0;
  }

  Widget _metricRing(String label, double percent, Color color) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: (percent / 100).clamp(0, 1)),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 5,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('${percent.round()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white60),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildActionsGrid(ThemeData theme) {
    final actions = <_ActionTile>[
      _ActionTile(
        icon: Icons.desktop_windows_rounded,
        label: 'Remote Desktop',
        subtitle: 'View & control screen',
        color: const Color(0xFF6C5CE7),
        onTap: () => _open(const RemoteDesktopScreen()),
      ),
      _ActionTile(
        icon: Icons.terminal_rounded,
        label: 'Terminal',
        subtitle: 'Run commands',
        color: const Color(0xFF00B894),
        onTap: () => _open(const TerminalScreen()),
      ),
      _ActionTile(
        icon: Icons.folder_rounded,
        label: 'Files',
        subtitle: 'Browse & transfer',
        color: const Color(0xFFFDCB6E),
        onTap: () => _open(const FilesScreen()),
      ),
      _ActionTile(
        icon: Icons.memory_rounded,
        label: 'Processes',
        subtitle: 'Running tasks',
        color: const Color(0xFF0984E3),
        onTap: () => _open(const ProcessesScreen()),
      ),
      _ActionTile(
        icon: Icons.settings_suggest_rounded,
        label: 'Services',
        subtitle: 'Windows services',
        color: const Color(0xFFE17055),
        onTap: () => _open(const ServicesScreen()),
      ),
      _ActionTile(
        icon: Icons.receipt_long_rounded,
        label: 'Activity Logs',
        subtitle: 'Recent events',
        color: const Color(0xFF636E72),
        onTap: () => _open(const LogsScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Text(
            'Manage',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.5,
              fontSize: 13,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, i) => _buildTile(actions[i], theme),
        ),
      ],
    );
  }

  Widget _buildTile(_ActionTile action, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(0.08),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: action.onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(action.icon, color: action.color, size: 22),
                  ),
                  const Spacer(),
                  Text(action.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(action.subtitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}