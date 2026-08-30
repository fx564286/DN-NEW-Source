#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build_app')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'alpha119 marker not found: {label}')
    return text.replace(old, new, 1)

# Provider capability.
models = root / 'lib/models.dart'
text = models.read_text(encoding='utf-8')
text = replace_once(
    text,
    "  bool get supportsExactSeatMap => this == CinemaChain.lotte;",
    "  bool get supportsExactSeatMap => this != CinemaChain.all;",
    'provider exact-seat capability',
)
text = replace_once(
    text,
    "  bool get hasExactSeatParameters =>\n      chain == CinemaChain.lotte &&\n      theaterId.isNotEmpty &&\n      screenId.isNotEmpty &&\n      playSequence.isNotEmpty;",
    """  bool get hasExactSeatParameters =>
      (chain == CinemaChain.lotte &&
          theaterId.isNotEmpty &&
          screenId.isNotEmpty &&
          playSequence.isNotEmpty) ||
      (chain == CinemaChain.megabox && showtimeId.isNotEmpty) ||
      (chain == CinemaChain.cgv &&
          theaterId.isNotEmpty &&
          screenId.isNotEmpty &&
          playSequence.isNotEmpty);""",
    'watch exact-seat parameters',
)
models.write_text(text, encoding='utf-8')

# Megabox official seat endpoint and parser. This restores the exact-seat path
# that existed in the earlier all-provider seat implementation.
services = root / 'lib/services.dart'
text = services.read_text(encoding='utf-8')
text = replace_once(
    text,
    "  static const _lotteTicketing =\n      'https://www.lottecinema.co.kr/LCWS/Ticketing/TicketingData.aspx';\n  final Random _random = Random();",
    """  static const _lotteTicketing =
      'https://www.lottecinema.co.kr/LCWS/Ticketing/TicketingData.aspx';
  static const _megaboxSeatList =
      'https://www.megabox.co.kr/on/oh/ohz/PcntSeatChoi/selectSeatList.do';
  final Random _random = Random();""",
    'Megabox endpoint',
)
old_loader = """  Future<SeatLayout?> loadExactSeatLayout(
    Showtime showtime, {
    CinemaChain? chain,
  }) async {
    if (chain != CinemaChain.lotte || !showtime.hasExactSeatParameters) {
      return null;
    }
    return _loadLotteExactSeatLayout(showtime);
  }

  Future<SeatLayout> _loadLotteExactSeatLayout(Showtime showtime) async {"""
new_loader = """  Future<SeatLayout?> loadExactSeatLayout(
    Showtime showtime, {
    CinemaChain? chain,
  }) async {
    return switch (chain) {
      CinemaChain.lotte when showtime.hasExactSeatParameters =>
        _loadLotteExactSeatLayout(showtime),
      CinemaChain.megabox when showtime.id.isNotEmpty =>
        _loadMegaboxExactSeatLayout(showtime),
      _ => null,
    };
  }

  Future<SeatLayout> _loadMegaboxExactSeatLayout(Showtime showtime) async {
    final uri = Uri.parse(_megaboxSeatList).replace(
      queryParameters: {'playSchdlNo': showtime.id},
    );
    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer':
              'https://www.megabox.co.kr/on/oh/ohz/PcntSeatChoi/selectPcntSeatChoi.do',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 Chrome/134 Mobile Safari/537.36 Cineseat/0.2.1-alpha.119',
        },
      ).timeout(const Duration(seconds: 18));
    } on TimeoutException {
      throw const AppFailure('메가박스 실제 좌석표 조회 시간이 초과됐습니다.');
    } on http.ClientException {
      throw const AppFailure('메가박스 실제 좌석표에 연결하지 못했습니다.');
    }
    if (response.statusCode != 200) {
      throw AppFailure('메가박스 실제 좌석표 조회 실패 (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final root = _map(decoded);
    final items = _maps(root['seatListSD01']);
    if (items.isEmpty) {
      throw const AppFailure('이 회차의 메가박스 실제 좌석 배치가 제공되지 않습니다.');
    }

    final grouped = <String, List<SeatCell>>{};
    for (final item in items) {
      final row = _text(item['rowNm']).trim().toUpperCase();
      final column = _integer(item['seatNo']);
      if (row.isEmpty || column <= 0) continue;
      final exposed = _text(item['seatExpoAt']).toUpperCase();
      if (exposed == 'N') continue;
      final x = (_number(item['horzCoorVal']) ?? 0).round();
      final y = (_number(item['vertCoorVal']) ?? 0).round();
      final status = _text(item['seatStatCd']).toUpperCase();
      grouped.putIfAbsent(row, () => <SeatCell>[]).add(
        SeatCell(
          label: '$row$column',
          state: status == 'GERN_SELL'
              ? SeatState.available
              : SeatState.booked,
          row: row,
          column: column,
          x: x,
          y: y,
        ),
      );
    }
    if (grouped.isEmpty) {
      throw const AppFailure('메가박스 좌석 응답에 표시 가능한 좌석이 없습니다.');
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final ay = a.value.map((seat) => seat.y).fold<int>(
              1 << 30,
              (value, next) => next < value ? next : value,
            );
        final by = b.value.map((seat) => seat.y).fold<int>(
              1 << 30,
              (value, next) => next < value ? next : value,
            );
        final compared = ay.compareTo(by);
        return compared != 0 ? compared : a.key.compareTo(b.key);
      });

    final rows = entries.map((entry) {
      final seats = [...entry.value]
        ..sort((a, b) {
          final xCompared = a.x.compareTo(b.x);
          return xCompared != 0 ? xCompared : a.column.compareTo(b.column);
        });
      final rendered = <SeatCell>[];
      SeatCell? previous;
      for (final seat in seats) {
        if (previous != null) {
          final columnGap = seat.column - previous.column;
          final coordinateGap = seat.x - previous.x;
          final spacerCount = columnGap > 1
              ? min(columnGap - 1, 3)
              : coordinateGap >= 4
                  ? 1
                  : 0;
          for (var index = 0; index < spacerCount; index++) {
            rendered.add(const SeatCell(
              label: '',
              state: SeatState.unknown,
              selectable: false,
            ));
          }
        }
        rendered.add(seat);
        previous = seat;
      }
      return rendered;
    }).toList();

    return SeatLayout(
      rows: rows,
      isExact: true,
      source: '메가박스 공식 selectSeatList · 실제 좌석 데이터',
      fetchedAt: DateTime.now(),
    );
  }

  Future<SeatLayout> _loadLotteExactSeatLayout(Showtime showtime) async {"""
text = replace_once(text, old_loader, new_loader, 'exact seat provider switch')
services.write_text(text, encoding='utf-8')

# Seamless wizard: keep current showtime screen while Megabox exact data is fetched,
# then move to the seat map only when the SeatLayout is ready.
wizard = root / 'lib/wizard.dart'
text = wizard.read_text(encoding='utf-8')
old = """      } else if (theater.chain == CinemaChain.lotte &&
          showtime.hasExactSeatParameters) {
        layout = await _api.loadExactSeatLayout(
          showtime,
          chain: theater.chain,
        );
      }"""
new = """      } else if ((theater.chain == CinemaChain.lotte &&
              showtime.hasExactSeatParameters) ||
          (theater.chain == CinemaChain.megabox && showtime.id.isNotEmpty)) {
        layout = await _api.loadExactSeatLayout(
          showtime,
          chain: theater.chain,
        );
      }"""
text = replace_once(text, old, new, 'Megabox seamless exact-seat branch')
text = text.replace('Cineseat/0.2.1-alpha.118', 'Cineseat/0.2.1-alpha.119')
wizard.write_text(text, encoding='utf-8')

print('alpha119 Megabox exact-seat patch applied')
