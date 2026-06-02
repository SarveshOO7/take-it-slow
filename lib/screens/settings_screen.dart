import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/blocker_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _minutes;
  late final TextEditingController _ctrl;

  static const _presets = [
    (15, '15 min'),
    (30, '30 min'),
    (60, '1 hr'),
    (120, '2 hrs'),
  ];

  @override
  void initState() {
    super.initState();
    _minutes = context.read<BlockerService>().accessDurationMinutes;
    _ctrl = TextEditingController(text: '$_minutes');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setMinutes(int m) {
    final clamped = m.clamp(5, 480);
    setState(() {
      _minutes = clamped;
      final t = clamped.toString();
      if (_ctrl.text != t) {
        _ctrl.text = t;
        _ctrl.selection =
            TextSelection.collapsed(offset: t.length);
      }
    });
  }

  void _save() {
    context.read<BlockerService>().setAccessDuration(_minutes);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF7C6FFF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('YouTube Access Window'),
              const SizedBox(height: 6),
              Text(
                'After your 10-minute wait, YouTube unlocks for this long.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
              const SizedBox(height: 28),
              _durationCard(),
              const SizedBox(height: 28),
              _SectionHeader('Quick Presets'),
              const SizedBox(height: 12),
              _presetRow(),
              const SizedBox(height: 40),
              _appSelectionCard(),
              const SizedBox(height: 40),
              _infoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IntrinsicWidth(
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _MaxValueFormatter(480),
                  ],
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 5) _setMinutes(n);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(' min',
                    style: TextStyle(fontSize: 26, color: Colors.white54)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbColor: const Color(0xFF7C6FFF),
              activeTrackColor: const Color(0xFF7C6FFF),
              inactiveTrackColor: Colors.white12,
              overlayColor: const Color(0xFF7C6FFF).withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _minutes.toDouble(),
              min: 5,
              max: 480,
              onChanged: (v) => _setMinutes(v.round()),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5 min',
                  style: TextStyle(fontSize: 11, color: Colors.white30)),
              Text('8 hrs',
                  style: TextStyle(fontSize: 11, color: Colors.white30)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetRow() {
    return Row(
      children: _presets.map((p) {
        final active = _minutes == p.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setMinutes(p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF7C6FFF)
                      : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: active
                      ? null
                      : Border.all(color: Colors.white12),
                ),
                child: Text(
                  p.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? Colors.white : Colors.white60,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _appSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Blocked Apps',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Choose which apps to block. YouTube is selected by default.',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(12),
              onPressed: () =>
                  context.read<BlockerService>().showAppPicker(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.app_badge, size: 18),
                  SizedBox(width: 8),
                  Text('Change App Selection'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF7C6FFF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.info_circle,
                  size: 16, color: Color(0xFF7C6FFF)),
              SizedBox(width: 8),
              Text('How it works',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C6FFF))),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('1.', 'Open YouTube — it\'s blocked.'),
          _infoRow('2.', 'Wait 10 minutes doing something else.'),
          _infoRow('3.',
              'YouTube unlocks for your access window (default 60 min).'),
          _infoRow('4.', 'Window closes → YouTube is blocked again.'),
        ],
      ),
    );
  }

  Widget _infoRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num,
              style: const TextStyle(
                  color: Color(0xFF7C6FFF),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white38,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _MaxValueFormatter extends TextInputFormatter {
  final int max;
  const _MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final n = int.tryParse(next.text);
    if (n != null && n > max) return old;
    return next;
  }
}
