import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'shared_widgets.dart';
import 'wizard.dart';

const _ink = Color(0xFF251F22);
const _muted = Color(0xFF6A6065);
const _border = Color(0xFFECE3E8);
const _softPink = Color(0xFFFFEDF4);
const _deepPink = Color(0xFFB83E6F);

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  Future<void> _addWatch() async {
    final item = await Navigator.of(context).push<WatchItem>(
      MaterialPageRoute(builder: (_) => const WatchWizard()),
    );
    if (item != null) await widget.controller.add(item);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final pages = <Widget>[
            _HomePage(controller: widget.controller, onAdd: _addWatch),
            const _NotificationsPage(),
            _SettingsPage(controller: widget.controller),
          ];
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: IndexedStack(index: _tab, children: pages),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() => _tab = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.radar_outlined),
                  selectedIcon: Icon(Icons.radar_rounded),
                  label: '감시',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none_rounded),
                  selectedIcon: Icon(Icons.notifications_rounded),
                  label: '알림',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: '설정',
                ),
              ],
            ),
          );
        },
      );
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.controller, required this.onAdd});
  final AppController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final active = controller.items.where((item) => item.active).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        const Text(
          'CINEMA SEAT WATCH',
          style: TextStyle(
            color: appPink,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          '영화관 자리 알리미',
          style: TextStyle(
            color: _ink,
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE94D8C), Color(0xFFB83E6F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active == 0 ? '새 좌석 감시를 시작하세요' : '$active개 조건을 감시 중입니다',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'CGV·메가박스·롯데시네마의 영화와 회차를 선택하고 원하는 좌석 조건을 등록합니다.',
                style: TextStyle(
                  color: Color(0xFFFFEAF2),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _deepPink,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    '새 좌석 감시 만들기',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (controller.startupWarning != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5DD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(controller.startupWarning!),
          ),
        ],
        const SizedBox(height: 23),
        Row(
          children: [
            const Expanded(
              child: Text(
                '내 좌석 감시',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (controller.items.isNotEmpty)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('추가'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (controller.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: _border),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_seat_outlined, size: 42, color: appPink),
                SizedBox(height: 12),
                Text(
                  '등록된 감시 조건이 없습니다',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          )
        else
          ...controller.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 11),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _softPink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.chain.label,
                          style: const TextStyle(
                            color: _deepPink,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: item.active,
                        onChanged: (_) => unawaited(controller.toggle(item)),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () => unawaited(controller.remove(item)),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  Text(
                    item.movieName,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.theaterName} · ${item.screenName} · ${item.startTime}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.seatLabels.isEmpty ? '아무 빈 좌석' : item.seatLabels.join(' · '),
                    style: const TextStyle(
                      color: _deepPink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: appPink),
            SizedBox(height: 12),
            Text(
              '알림 기록',
              style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text('좌석이 발견되면 Android 알림으로 알려드립니다.'),
          ],
        ),
      );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        children: [
          const Text(
            '설정',
            style: TextStyle(color: _ink, fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.radar_rounded, color: appPink),
                  title: const Text('백그라운드 감시 새로고침'),
                  onTap: () => unawaited(controller.refreshBackgroundMonitor()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: appPink),
                  title: const Text('감시 목록 전체 삭제'),
                  onTap: () => unawaited(controller.clear()),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: appPink),
                  title: Text('앱 버전'),
                  subtitle: Text('0.2.1-alpha118'),
                ),
              ],
            ),
          ),
        ],
      );
}
