import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_timer_state.dart';
import '../services/blocker_service.dart';
import '../widgets/countdown_ring.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlockerService>(
      builder: (context, svc, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          appBar: _buildAppBar(context, svc),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              child: _buildBody(context, svc),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, BlockerService svc) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C6FFF), Color(0xFFB06BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(CupertinoIcons.timer, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Take It Slow',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        ],
      ),
      actions: [
        if (svc.phase != BlockerPhase.unauthorized)
          CupertinoButton(
            padding: const EdgeInsets.only(right: 12),
            onPressed: () => Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
            child: const Icon(CupertinoIcons.settings, color: Colors.white54),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, BlockerService svc) {
    switch (svc.phase) {
      case BlockerPhase.unauthorized:
        return _UnauthorizedView(key: const ValueKey('unauth'));
      case BlockerPhase.idle:
        return _IdleView(pulse: _pulse, key: const ValueKey('idle'));
      case BlockerPhase.countdown:
        return _CountdownView(
          svc: svc,
          key: const ValueKey('countdown'),
        );
      case BlockerPhase.accessible:
        return _AccessibleView(
          svc: svc,
          key: const ValueKey('access'),
        );
    }
  }
}

// ─── Unauthorized ─────────────────────────────────────────────────────────────

class _UnauthorizedView extends StatelessWidget {
  const _UnauthorizedView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<BlockerService>();
    return _CenteredPadded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C6FFF).withOpacity(0.3),
                  Colors.transparent
                ],
              ),
            ),
            child: const Icon(CupertinoIcons.lock_shield,
                size: 54, color: Color(0xFF7C6FFF)),
          ),
          const SizedBox(height: 28),
          const Text('Screen Time Access Required',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            'Take It Slow uses Screen Time to block and monitor app usage. Tap below to grant access.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.white.withOpacity(0.55)),
          ),
          const SizedBox(height: 40),
          _GradientButton(
            label: 'Grant Permission',
            onPressed: () async {
              final ok = await svc.requestAuthorization();
              if (!ok && context.mounted) {
                _showSnack(context,
                    'Permission denied. You can enable it in Settings → Screen Time.');
              } else if (ok && context.mounted) {
                await svc.showAppPicker();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Idle ─────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final Animation<double> pulse;
  const _IdleView({required this.pulse, super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<BlockerService>();
    return _CenteredPadded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: pulse,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF5F5F).withOpacity(0.2),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFFF5F5F).withOpacity(0.6),
                        width: 2.5),
                  ),
                  child: const Icon(CupertinoIcons.hand_raised_fill,
                      size: 44, color: Color(0xFFFF5F5F)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('YouTube is Blocked',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'Open YouTube to trigger your\n10-minute cool-down timer.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 8),
          Consumer<BlockerService>(
            builder: (_, s, __) => Text(
              'Access window: ${s.accessDurationMinutes} min after waiting',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF7C6FFF)),
            ),
          ),
          const SizedBox(height: 48),
          // Manual fallback button
          OutlinedButton.icon(
            onPressed: svc.triggerManualCountdown,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
            ),
            icon: const Icon(CupertinoIcons.play_arrow_solid,
                size: 16, color: Colors.white54),
            label: const Text('Start wait manually',
                style:
                    TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ─── Countdown ────────────────────────────────────────────────────────────────

class _CountdownView extends StatelessWidget {
  final BlockerService svc;
  const _CountdownView({required this.svc, super.key});

  @override
  Widget build(BuildContext context) {
    return _CenteredPadded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Patience…',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Do something else first',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 44),
          Consumer<BlockerService>(
            builder: (_, s, __) => CountdownRing(
              progress: s.countdownSecondsLeft / 600.0,
              timeText: s.formatSeconds(s.countdownSecondsLeft),
              sublabel: 'remaining',
              color: const Color(0xFFFF9F43),
              size: 230,
            ),
          ),
          const SizedBox(height: 44),
          _TipCard(tip: _randomTip()),
        ],
      ),
    );
  }

  String _randomTip() {
    const tips = [
      'Take a short walk.',
      'Do 10 push-ups.',
      'Read a page of a book.',
      'Drink a glass of water.',
      'Stretch for a few minutes.',
      'Write in your journal.',
      'Tidy one small space.',
    ];
    return tips[DateTime.now().minute % tips.length];
  }
}

// ─── Accessible ───────────────────────────────────────────────────────────────

class _AccessibleView extends StatelessWidget {
  final BlockerService svc;
  const _AccessibleView({required this.svc, super.key});

  @override
  Widget build(BuildContext context) {
    return _CenteredPadded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.checkmark_seal_fill,
              size: 54, color: Color(0xFF26DE81)),
          const SizedBox(height: 16),
          const Text('YouTube Unlocked',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Enjoy your time',
              style: TextStyle(fontSize: 15, color: Colors.white54)),
          const SizedBox(height: 44),
          Consumer<BlockerService>(
            builder: (_, s, __) => CountdownRing(
              progress:
                  s.accessSecondsLeft / (s.accessDurationMinutes * 60.0),
              timeText: s.formatSeconds(s.accessSecondsLeft),
              sublabel: 'left',
              color: const Color(0xFF26DE81),
              size: 230,
            ),
          ),
          const SizedBox(height: 44),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.info_circle,
                    size: 16, color: Colors.white38),
                const SizedBox(width: 8),
                Text(
                  'YouTube blocks when the timer hits 00:00',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.45)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _CenteredPadded extends StatelessWidget {
  final Widget child;
  const _CenteredPadded({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: child,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C6FFF), Color(0xFFB06BFF)],
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C6FFF).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF9F43).withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(tip,
              style: const TextStyle(
                  fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }
}

void _showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2A2A3E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
