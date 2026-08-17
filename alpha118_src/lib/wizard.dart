import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'services.dart';
import 'shared_widgets.dart';

const _ink = Color(0xFF251F22);
const _muted = Color(0xFF6A6065);
const _border = Color(0xFFECE3E8);
const _softPink = Color(0xFFFFEDF4);
const _deepPink = Color(0xFFB83E6F);

enum _SeatMode { any, adjacent, specific }

class WatchWizard extends StatefulWidget {
  const WatchWizard({super.key});

  @override
  State<WatchWizard> createState() => _WatchWizardState();
}

class _WatchWizardState extends State<WatchWizard> {
  final CinemaApi _api = CinemaApi();
  final LocationService _location = LocationService();
  final TextEditingController _search = TextEditingController();

  int _step = 0;
  bool _loadingTheaters = true;
  bool _loadingCatalog = false;
  bool _resolvingSeats = false;
  String? _error;
  List<Theater> _theaters = const [];
  Theater? _theater;
  DateTime _date = DateTime.now();
  CinemaCatalog? _catalog;
  Showtime? _showtime;
  SeatLayout? _layout;
  final Set<String> _selected = <String>{};
  _SeatMode _mode = _SeatMode.specific;
  int _count = 2;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    unawaited(_loadTheaters());
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTheaters() async {
    if (mounted) setState(() => _loadingTheaters = true);
    final location = await _location.getCurrent();
    try {
      final result = await _api.loadNearbyTheaters(
        date: _date,
        position: location.position,
      );
      if (!mounted) return;
      setState(() {
        _theaters = result;
        _loadingTheaters = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTheaters = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _chooseTheater(Theater value) async {
    setState(() {
      _theater = value;
      _step = 1;
      _catalog = null;
      _showtime = null;
      _layout = null;
      _selected.clear();
    });
  }

  Future<void> _chooseDate(DateTime value) async {
    final theater = _theater;
    if (theater == null) return;
    setState(() {
      _date = value;
      _step = 2;
      _loadingCatalog = true;
      _error = null;
      _catalog = null;
      _showtime = null;
      _layout = null;
      _selected.clear();
    });
    try {
      final result = await _api.loadCatalog(theater: theater, date: value);
      if (!mounted) return;
      setState(() {
        _catalog = result;
        _loadingCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _chooseShowtime(Showtime showtime) async {
    if (_resolvingSeats) return;
    final theater = _theater;
    if (theater == null) return;

    // 핵심 UX: 좌석 데이터를 가져오는 동안 별도 로딩/WebView route로 이동하지 않는다.
    // 사용자는 현재 상영시간 목록을 그대로 보고, 데이터가 준비된 뒤 좌석 화면으로 한 번만 전환된다.
    setState(() {
      _resolvingSeats = true;
      _error = null;
      _showtime = showtime;
      _layout = null;
      _selected.clear();
    });

    SeatLayout? layout;
    Object? failure;
    try {
      if (theater.chain == CinemaChain.cgv && showtime.hasExactSeatParameters) {
        layout = await _loadCgvGuestSeatLayout(showtime);
      } else if (theater.chain == CinemaChain.lotte &&
          showtime.hasExactSeatParameters) {
        layout = await _api.loadExactSeatLayout(
          showtime,
          chain: theater.chain,
        );
      }
    } catch (e) {
      failure = e;
    }

    if (!mounted) return;
    setState(() {
      _layout = layout;
      _resolvingSeats = false;
      _step = 3;
      _mode = layout == null ? _SeatMode.adjacent : _SeatMode.specific;
      if (failure != null) _error = failure.toString();
    });
  }

  Future<SeatLayout> _loadCgvGuestSeatLayout(Showtime showtime) async {
    const path = '/cnm/atkt/searchIfSeatData';
    const secret = 'ydqXY0ocnFLmJGHr_zNzFcpjwAsXq_8JcBNURAkRscg';
    final playDate = showtime.playDate.replaceAll(RegExp(r'[^0-9]'), '');
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signature = base64Encode(
      Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode('$timestamp|$path|'))
          .bytes,
    );
    final query = <String, String>{
      'coCd': 'A420',
      'siteNo': showtime.theaterId,
      'scnYmd': playDate,
      'scnsNo': showtime.screenId,
      'scnSseq': showtime.playSequence,
      'seatAreaNo': '001',
      'cusgdCd': '01',
    };
    final uri = Uri.https('api.cgv.co.kr', path, query);
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': 'ko-KR',
        'Origin': 'https://cgv.co.kr',
        'Referer': 'https://cgv.co.kr/cnm/movieBook',
        'X-TIMESTAMP': timestamp,
        'X-SIGNATURE': signature,
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 '
            'Chrome/134 Mobile Safari/537.36 Cineseat/0.2.1-alpha.118',
      },
    ).timeout(const Duration(seconds: 18));

    if (response.statusCode != 200) {
      throw AppFailure('CGV 좌석 조회 실패 (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const AppFailure('CGV 좌석 응답 형식 오류');
    final root = Map<String, dynamic>.from(decoded);
    if (_toInt(root['statusCode']) != 0) {
      throw AppFailure(root['statusMessage']?.toString() ?? 'CGV 좌석 응답 오류');
    }
    final data = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : <String, dynamic>{};
    final items = data['items'] is List ? data['items'] as List : const [];
    final seats = <SeatCell>[];
    for (final groupRaw in items) {
      if (groupRaw is! Map) continue;
      final group = Map<String, dynamic>.from(groupRaw);
      final rawSeats = group['seats'] is List ? group['seats'] as List : const [];
      for (final raw in rawSeats) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final row = (item['seatRowNm']?.toString() ?? '').trim().toUpperCase();
        final rawNo = (item['seatNo']?.toString() ?? '').trim();
        if (row.isEmpty || rawNo.isEmpty) continue;
        final no = int.tryParse(rawNo) ?? 0;
        final loc = (item['seatLocNo']?.toString() ?? '').trim();
        seats.add(
          SeatCell(
            label: '$row${no > 0 ? no : rawNo}',
            state: item['seatStusCd']?.toString() == '00'
                ? SeatState.available
                : SeatState.booked,
            row: row,
            column: no,
            x: _coord(loc, 6, 10),
            y: _coord(loc, 10, 14),
          ),
        );
      }
    }
    if (seats.isEmpty) throw const AppFailure('CGV 좌석 데이터가 비어 있습니다.');

    final grouped = <String, List<SeatCell>>{};
    for (final seat in seats) {
      grouped.putIfAbsent(seat.row, () => <SeatCell>[]).add(seat);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        int rowY(List<SeatCell> values) => values
            .where((s) => s.y > 0)
            .map((s) => s.y)
            .fold<int>(1 << 30, min);
        final y = rowY(a.value).compareTo(rowY(b.value));
        return y != 0 ? y : a.key.compareTo(b.key);
      });

    final rows = <List<SeatCell>>[];
    for (final entry in entries) {
      final sorted = [...entry.value]
        ..sort((a, b) {
          if (a.x > 0 && b.x > 0) return a.x.compareTo(b.x);
          return a.column.compareTo(b.column);
        });
      final rendered = <SeatCell>[];
      SeatCell? previous;
      for (final seat in sorted) {
        if (previous != null) {
          final coordinateGap = seat.x > 0 && previous.x > 0
              ? seat.x - previous.x
              : 0;
          final columnGap = seat.column - previous.column;
          if (coordinateGap >= 4 || columnGap > 1) {
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
      rows.add(rendered);
    }
    return SeatLayout(
      rows: rows,
      isExact: true,
      source: 'CGV 공식 searchIfSeatData · 비회원 실제 좌석 데이터',
      fetchedAt: DateTime.now(),
    );
  }

  static int _coord(String value, int start, int end) {
    if (value.length < end) return 0;
    return int.tryParse(value.substring(start, end)) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {
        _step--;
        if (_step < 3) {
          _layout = null;
          _selected.clear();
          _error = null;
        }
      });
    }
  }

  void _finish() {
    final theater = _theater;
    final showtime = _showtime;
    if (theater == null || showtime == null) return;
    List<String> labels;
    String mode;
    if (_mode == _SeatMode.specific && _selected.isNotEmpty) {
      final values = _selected.toList()..sort();
      labels = values;
      mode = 'specific';
    } else if (_mode == _SeatMode.adjacent) {
      labels = <String>['$_count석 연석'];
      mode = 'adjacent';
    } else {
      labels = <String>['아무 빈 좌석 $_count석 이상'];
      mode = 'any';
    }
    Navigator.of(context).pop(
      WatchItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        chain: theater.chain,
        theaterId: theater.id,
        theaterName: theater.name,
        movieId: showtime.movieId,
        movieName: showtime.movieName,
        playDate: CinemaApi.compactDate(_date),
        startTime: showtime.startTime,
        endTime: showtime.endTime,
        screenName: showtime.screenName,
        seatLabels: labels,
        bookingUrl: theater.chain.bookingUrl,
        showtimeId: showtime.id,
        screenId: showtime.screenId,
        playSequence: showtime.playSequence,
        screenDivisionCode: showtime.screenDivisionCode,
        watchMode: mode,
        seatCount: _count,
        remainingSeatsAtCreation: showtime.remainingSeats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            title: Text(
              ['영화관 선택', '날짜 선택', '영화 및 상영시간', '좌석 조건'][_step],
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('${_step + 1}/4',
                      style: const TextStyle(
                          color: _deepPink, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _progress(),
              Expanded(child: _body()),
            ],
          ),
        ),
      );

  Widget _progress() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
        child: Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                decoration: BoxDecoration(
                  color: i <= _step ? appPink : const Color(0xFFE3DDE0),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _body() => switch (_step) {
        0 => _theaterStep(),
        1 => _dateStep(),
        2 => _showtimeStep(),
        _ => _seatStep(),
      };

  Widget _theaterStep() {
    final q = _search.text.trim().toLowerCase();
    final values = _theaters.where((t) =>
        q.isEmpty ||
        t.name.toLowerCase().contains(q) ||
        t.address.toLowerCase().contains(q)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            hintText: '영화관 이름 또는 주소 검색',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingTheaters)
          const LoadingCard(message: '영화관 목록을 불러오는 중입니다.')
        else if (_error != null)
          ErrorCard(message: _error!, onRetry: _loadTheaters)
        else
          ...values.map((t) => Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  onTap: () => _chooseTheater(t),
                  leading: const Icon(Icons.local_movies_rounded, color: appPink),
                  title: Text(t.name,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(t.address.isEmpty ? t.chain.label : t.address),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              )),
      ],
    );
  }

  Widget _dateStep() {
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final v = now.add(Duration(days: i));
      return DateTime(v.year, v.month, v.day);
    });
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _summary(_theater?.name ?? '', '상영 날짜를 선택하세요.'),
        const SizedBox(height: 14),
        ...dates.map((d) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                onTap: () => _chooseDate(d),
                leading: const Icon(Icons.calendar_today_rounded, color: appPink),
                title: Text('${d.month}월 ${d.day}일',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            )),
      ],
    );
  }

  Widget _showtimeStep() {
    if (_loadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _catalog == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(_error!),
      ));
    }
    final catalog = _catalog;
    if (catalog == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _summary(_theater?.name ?? '', '${_date.month}월 ${_date.day}일'),
        const SizedBox(height: 14),
        ...catalog.movies.map((movie) {
          final shows = catalog.showtimes
              .where((s) => s.movieId == movie.id)
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          if (shows.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: shows.map((s) => ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 17),
                    label: Text('${s.startTime} · ${s.remainingSeats}석'),
                    onPressed: _resolvingSeats ? null : () => _chooseShowtime(s),
                  )).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _seatStep() {
    final show = _showtime;
    if (show == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _summary('${show.movieName} · ${show.startTime}',
            '${_theater?.name ?? ''} · ${show.screenName}'),
        const SizedBox(height: 14),
        if (_layout != null) _seatMap(_layout!) else _fallback(show),
        const SizedBox(height: 16),
        const Text('감시 조건',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text('아무 빈 좌석'),
            selected: _mode == _SeatMode.any,
            onSelected: (_) => setState(() => _mode = _SeatMode.any),
          ),
          ChoiceChip(
            label: const Text('연석'),
            selected: _mode == _SeatMode.adjacent,
            onSelected: (_) => setState(() => _mode = _SeatMode.adjacent),
          ),
          if (_layout != null)
            ChoiceChip(
              label: const Text('특정 좌석'),
              selected: _mode == _SeatMode.specific,
              onSelected: (_) => setState(() => _mode = _SeatMode.specific),
            ),
        ]),
        if (_mode != _SeatMode.specific) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('필요 좌석 수',
                style: TextStyle(fontWeight: FontWeight.w800))),
            IconButton(onPressed: _count > 1 ? () => setState(() => _count--) : null,
                icon: const Icon(Icons.remove_rounded)),
            Text('$_count', style: const TextStyle(fontWeight: FontWeight.w900)),
            IconButton(onPressed: _count < 6 ? () => setState(() => _count++) : null,
                icon: const Icon(Icons.add_rounded)),
          ]),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _mode == _SeatMode.specific && _selected.isEmpty ? null : _finish,
          icon: const Icon(Icons.notifications_active_rounded),
          label: const Text('이 조건으로 좌석 감시 시작'),
        ),
      ],
    );
  }

  Widget _seatMap(SeatLayout layout) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('실제 상영관 좌석표',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              Text('빈 좌석 ${layout.availableCount}석',
                  style: const TextStyle(
                      color: Color(0xFF237A4B), fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1ECEF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text('SCREEN', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, letterSpacing: 2)),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: layout.rows.map((row) => Row(
                  children: row.map((seat) {
                    if (seat.isSpacer) return const SizedBox(width: 27, height: 28);
                    final available = seat.state == SeatState.available;
                    final selected = _selected.contains(seat.label);
                    return GestureDetector(
                      onTap: () => setState(() {
                        _mode = _SeatMode.specific;
                        if (!_selected.add(seat.label)) _selected.remove(seat.label);
                      }),
                      child: Container(
                        width: 27,
                        height: 27,
                        margin: const EdgeInsets.all(2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? appPink
                              : available
                                  ? const Color(0xFFE3F5EB)
                                  : const Color(0xFFE1DDE0),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(seat.label,
                            style: TextStyle(
                                fontSize: 7,
                                color: selected
                                    ? Colors.white
                                    : available
                                        ? const Color(0xFF237A4B)
                                        : _muted,
                                fontWeight: FontWeight.w900)),
                      ),
                    );
                  }).toList(),
                )).toList(),
              ),
            ),
          ],
        ),
      );

  Widget _fallback(Showtime show) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 잔여 ${show.remainingSeats}석',
                style: const TextStyle(
                    color: _deepPink, fontWeight: FontWeight.w900)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ],
        ),
      );

  Widget _summary(String title, String subtitle) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _softPink,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFF3C7D8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
        ]),
      );
}
