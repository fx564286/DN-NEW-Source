import 'package:flutter/material.dart';

import 'models.dart';

const appPink = Color(0xFFE94D8C);
const appBackground = Color(0xFFF8F5F7);
const availableSeatColor = Color(0xFF56B889);
const bookedSeatColor = Color(0xFF9EA5AF);
const selectedSeatColor = appPink;
const unknownSeatColor = Color(0xFFDDE1E6);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: appPink,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: appBackground,
    fontFamilyFallback: const ['Noto Sans KR', 'Roboto'],
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: Color(0xFFF0E8ED)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: appBackground,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFF0E8ED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFF0E8ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: appPink, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: const BorderSide(color: Color(0xFFF0E8ED)),
      selectedColor: scheme.primaryContainer,
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      backgroundColor: Colors.white,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class RoundedSection extends StatelessWidget {
  const RoundedSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: padding, child: child),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => RoundedSection(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text(label, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key, this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Icon(icon, size: 19, color: Colors.black45),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                  color: strong ? appPink : null,
                ),
              ),
            ),
          ],
        ),
      );
}

class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => RoundedSection(
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => RoundedSection(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: appPink),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 불러오기'),
            ),
          ],
        ),
      );
}

Color seatColor(SeatState state) => switch (state) {
      SeatState.available => availableSeatColor,
      SeatState.booked => bookedSeatColor,
      SeatState.selected => selectedSeatColor,
      SeatState.unknown => unknownSeatColor,
    };

class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key, this.includeUnknown = true});
  final bool includeUnknown;

  @override
  Widget build(BuildContext context) {
    final entries = <(SeatState, String)>[
      (SeatState.available, '빈 좌석'),
      (SeatState.booked, '예약 완료'),
      (SeatState.selected, '감시 선택'),
      if (includeUnknown) (SeatState.unknown, '상태 확인 불가'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: entries
          .map(
            (entry) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: seatColor(entry.$1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 6),
                Text(entry.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          )
          .toList(),
    );
  }
}

class AggregateSeatStatus extends StatelessWidget {
  const AggregateSeatStatus({super.key, required this.total, required this.remaining});
  final int total;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? remaining : total;
    final booked = safeTotal > 0 ? (safeTotal - remaining).clamp(0, safeTotal) : 0;
    return RoundedSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('좌석 현황', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const SeatLegend(includeUnknown: false),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SeatCountTile(
                  color: availableSeatColor,
                  label: '빈 좌석',
                  count: remaining,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SeatCountTile(
                  color: bookedSeatColor,
                  label: '예약 완료',
                  count: booked,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '현재 연동 API는 좌석별 위치가 아닌 잔여 좌석 수를 제공합니다. 정확한 좌석 위치는 공식 좌석표에서 확인합니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SeatCountTile extends StatelessWidget {
  const _SeatCountTile({required this.color, required this.label, required this.count});
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0E8ED)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  Text('$count석', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      );
}
