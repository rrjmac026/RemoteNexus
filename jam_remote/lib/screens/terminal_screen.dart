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

    setState(() {
      _lines.add('jam> $command');
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
      _lines.add(result.output);
      _lines.add('');
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
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('JAM Terminal')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (context, i) => Text(
                _lines[i],
                style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13, height: 1.4),
              ),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('jam> ', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 14)),
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
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}