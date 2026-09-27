import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/terminal_service.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<String> _lines = ['Connected to JAM-PC', "Type 'help' for a list of commands.", ''];
  bool _busy = false;
  String _cwd = ''; // '' = virtual root, e.g. 'C' or 'C/Users/Jam'

  /// Turns the backend's posix-style cwd ('', 'C', 'C/Users/Jam') into a
  /// Windows-flavored prompt: 'jam>' at root, 'jam\C:>' or 'jam\C:\Users\Jam>' below it.
  String get _prompt {
    if (_cwd.isEmpty) return 'jam> ';
    final parts = _cwd.split('/');
    final drive = '${parts.first}:';
    final rest = parts.length > 1 ? '\\${parts.skip(1).join('\\')}' : '';
    return 'jam\\$drive$rest> ';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submit() async {
    final command = _inputController.text.trim();
    if (command.isEmpty || _busy) return;

    final promptUsed = _prompt;
    setState(() {
      _lines.add('$promptUsed$command');
      _inputController.clear();
      _busy = true;
    });
    _scrollToBottom();

    if (command.toLowerCase() == 'clear') {
      setState(() { _lines.clear(); _busy = false; });
      return;
    }

    final result = await TerminalService.sendCommand(command);

    setState(() {
      if (result.output.isNotEmpty) _lines.add(result.output);
      _lines.add('');
      if (result.cwd != null) _cwd = result.cwd!;
      _busy = false;
    });
    _scrollToBottom();

    if (result.shouldExit && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withOpacity(0.72)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Expanded(child: _buildOutputCard()),
                  const SizedBox(height: 12),
                  _buildInputCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _lines.length,
            itemBuilder: (context, i) => Text(
              _lines[i],
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Text(_prompt,
                  style: const TextStyle(
                      color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w600)),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !_busy,
                  autofocus: true,
                  style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}