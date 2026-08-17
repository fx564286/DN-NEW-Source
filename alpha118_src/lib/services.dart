import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocationResult {
  const LocationResult({this.position, this.message});
  final Position? position;
  final String? message;
  bool get hasLocation => position != null;
}

class LocationService {
  Future<LocationResult> getCurrent() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(message: '휴대전화 위치 서비스가 꺼져 있습니다.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(message: '위치 권한이 거부되어 일반 목록으로 표시합니다.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(message: '설정에서 위치 권한을 허용하면 가까운 영화관을 추천합니다.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult(position: position);
    } on TimeoutException {
      return const LocationResult(message: '현재 위치 확인 시간이 초과되어 일반 목록으로 표시합니다.');
    } catch (_) {
      return const LocationResult(message: '현재 위치를 확인하지 못해 일반 목록으로 표시합니다.');
    }
  }

  double distanceKm(Position position, Theater theater) {
    if (theater.latitude == null || theater.longitude == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          theater.latitude!,
          theater.longitude!,
        ) /
        1000;
  }
}

class WatchStore {
  static const _key = 'watch_items_v021';

  Future<List<WatchItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? const [];
    final items = <WatchItem>[];
    for (final value in values) {
      try {
        items.add(WatchItem.decode(value));
      } catch (_) {
        // 손상된 과거 항목은 앱 시작을 막지 않고 건너뜁니다.
      }
    }
    return items;
  }

  Future<void> save(List<WatchItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, items.map((item) => item.encode()).toList());
  }
}

class CinemaApi {
  CinemaApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _base = 'https://mcp.aka.page';
  static const _lotteTicketing =
      'https://www.lottecinema.co.kr/LCWS/Ticketing/TicketingData.aspx';
  final Random _random = Random();

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final requestId =
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}';
      final uri = Uri.parse('$_base$path').replace(queryParameters: query);
      try {
        final response = await _client
            .get(uri, headers: {'x-request-id': requestId})
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final value = jsonDecode(utf8.decode(response.bodyBytes));
          if (value is Map<String, dynamic>) return value;
          throw const AppFailure('영화관 응답 형식이 올바르지 않습니다.');
        }
        if (response.statusCode == 429 || response.statusCode >= 500) {
          lastError = AppFailure('영화관 서버 응답 오류 (${response.statusCode})');
        } else {
          throw AppFailure('영화관 조회 실패 (${response.statusCode})');
        }
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        final delay = Duration(
          milliseconds: 500 * (1 << attempt) + _random.nextInt(350),
        );
        await Future<void>.delayed(delay);
      }
    }
    throw AppFailure(
      lastError is AppFailure
          ? lastError.message
          : '영화관 정보를 불러오지 못했습니다. 네트워크를 확인하고 다시 시도하세요.',
    );
  }

  Future<List<Theater>> loadNearbyTheaters({
    required DateTime date,
    Position? position,
  }) async {
    final chains = [CinemaChain.cgv, CinemaChain.megabox, CinemaChain.lotte];
    final results = await Future.wait(
      chains.map((chain) async {
        try {
          return await _loadTheaters(chain, date, position);
        } catch (_) {
          return <Theater>[];
        }
      }),
    );
    final merged = results.expand((value) => value).toList();
    if (merged.isEmpty) {
      throw const AppFailure('영화관 지점 정보를 불러오지 못했습니다.');
    }
    final seen = <String>{};
    final deduped = merged.where((theater) => seen.add(theater.key)).toList();
    if (position != null) {
      final location = LocationService();
      for (var i = 0; i < deduped.length; i++) {
        final item = deduped[i];
        final calculated = location.distanceKm(position, item);
        deduped[i] = item.copyWithDistance(
          calculated.isFinite ? calculated : item.distanceKm,
        );
      }
      deduped.sort((a, b) {
        final ad = a.distanceKm ?? double.infinity;
        final bd = b.distanceKm ?? double.infinity;
        return ad.compareTo(bd);
      });
    } else {
      deduped.sort((a, b) {
        final chain = a.chain.index.compareTo(b.chain.index);
        return chain != 0 ? chain : a.name.compareTo(b.name);
      });
    }
    return deduped;
  }

  Future<List<Theater>> _loadTheaters(
    CinemaChain chain,
    DateTime date,
    Position? position,
  ) async {
    final query = <String, String>{
      'playDate': compactDate(date),
      'limit': '100',
    };
    if (position != null) {
      query['lat'] = position.latitude.toStringAsFixed(6);
      query['lng'] = position.longitude.toStringAsFixed(6);
    }
    final json = await _get('/api/${chain.apiKey}/theaters', query);
    final data = _map(json['data']);
    final list = _maps(data['theaters']);
    return list.map((item) {
      final id = chain == CinemaChain.cgv
          ? _text(item['theaterCode'])
          : _text(item['theaterId']);
      final rawName = _text(item['theaterName']);
      final name = rawName.startsWith(chain.label)
          ? rawName
          : '${chain.label} $rawName';
      return Theater(
        chain: chain,
        id: id,
        name: name,
        address: _text(item['address']),
        latitude: _number(item['latitude']),
        longitude: _number(item['longitude']),
        distanceKm: _number(item['distanceKm']),
      );
    }).where((item) => item.id.isNotEmpty && item.name.trim().isNotEmpty).toList();
  }

  Future<CinemaCatalog> loadCatalog({
    required Theater theater,
    required DateTime date,
  }) async {
    return switch (theater.chain) {
      CinemaChain.cgv => _loadCgvCatalog(theater, date),
      CinemaChain.megabox => _loadSharedCatalog(theater, date, 'megabox'),
      CinemaChain.lotte => _loadSharedCatalog(theater, date, 'lottecinema'),
      CinemaChain.all => throw const AppFailure('영화관 체인을 선택해 주세요.'),
    };
  }

  Future<CinemaCatalog> _loadCgvCatalog(
    Theater theater,
    DateTime date,
  ) async {
    final query = {
      'playDate': compactDate(date),
      'theaterCode': theater.id,
    };
    final responses = await Future.wait([
      _get('/api/cgv/movies', query),
      _get('/api/cgv/timetable', {...query, 'limit': '200'}),
    ]);
    final movieData = _map(responses[0]['data']);
    final timetableData = _map(responses[1]['data']);
    final showtimes = _maps(timetableData['timetable'])
        .map(_parseShowtime)
        .where((item) => _isUsableShowtime(item, date))
        .toList();
    final activeMovieIds = showtimes.map((item) => item.movieId).toSet();
    var movies = _maps(movieData['movies'])
        .map(
          (item) => CinemaMovie(
            id: _text(item['movieCode']),
            name: _text(item['movieName']),
            rating: _text(item['rating']),
          ),
        )
        .where(
          (movie) =>
              movie.id.isNotEmpty &&
              movie.name.isNotEmpty &&
              activeMovieIds.contains(movie.id),
        )
        .toList();
    if (movies.isEmpty && showtimes.isNotEmpty) {
      movies = showtimes
          .map((item) => CinemaMovie(id: item.movieId, name: item.movieName))
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
    }
    return CinemaCatalog(movies: _uniqueMovies(movies), showtimes: showtimes);
  }

  Future<CinemaCatalog> _loadSharedCatalog(
    Theater theater,
    DateTime date,
    String key,
  ) async {
    final json = await _get('/api/$key/movies', {
      'playDate': compactDate(date),
      'theaterId': theater.id,
    });
    final data = _map(json['data']);
    final showtimes = _maps(data['showtimes'])
        .map(_parseShowtime)
        .where((item) => _isUsableShowtime(item, date))
        .toList();
    final activeMovieIds = showtimes.map((item) => item.movieId).toSet();
    var movies = _maps(data['movies'])
        .map(
          (item) => CinemaMovie(
            id: _text(item['movieId']),
            name: _text(item['movieName']),
            rating: _text(item['rating']),
          ),
        )
        .where(
          (movie) =>
              movie.id.isNotEmpty &&
              movie.name.isNotEmpty &&
              activeMovieIds.contains(movie.id),
        )
        .toList();
    if (movies.isEmpty && showtimes.isNotEmpty) {
      movies = showtimes
          .map((item) => CinemaMovie(id: item.movieId, name: item.movieName))
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
    }
    return CinemaCatalog(movies: _uniqueMovies(movies), showtimes: showtimes);
  }

  Showtime _parseShowtime(Map<String, dynamic> item) {
    final scheduleId = _text(item['scheduleId']);
    final inferred = _inferLotteSchedule(scheduleId);
    return Showtime(
      id: scheduleId,
      movieId: _text(item['movieId'] ?? item['movieCode']),
      movieName: _text(item['movieName']),
      theaterId: _text(item['theaterId'] ?? item['theaterCode']),
      theaterName: _text(item['theaterName']),
      playDate: _text(item['playDate']),
      startTime: normalizeTime(_text(item['startTime'])),
      endTime: normalizeTime(_text(item['endTime'])),
      screenName:
          _text(item['screenName'] ?? item['hallName'] ?? item['screenId']),
      totalSeats: _integer(item['totalSeats']),
      remainingSeats: _integer(item['remainingSeats']),
      screenId: _text(item['screenId']).isNotEmpty
          ? _text(item['screenId'])
          : inferred.$1,
      playSequence: _text(item['playSequence']).isNotEmpty
          ? _text(item['playSequence'])
          : inferred.$2,
      screenDivisionCode: _text(item['screenDivisionCode']).isEmpty
          ? '300'
          : _text(item['screenDivisionCode']),
    );
  }

  (String, String) _inferLotteSchedule(String scheduleId) {
    final parts = scheduleId.split('-');
    if (parts.length >= 4 && RegExp(r'^\d{8}$').hasMatch(parts.first)) {
      return (parts[parts.length - 2], parts.last);
    }
    return ('', '');
  }

  bool _isUsableShowtime(Showtime showtime, DateTime date) {
    if (showtime.movieId.isEmpty || showtime.startTime.isEmpty) return false;
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    if (!isToday) return true;
    final parts = showtime.startTime.split(':');
    if (parts.length != 2) return true;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return true;
    final start = DateTime(date.year, date.month, date.day, hour, minute);
    return start.isAfter(now.subtract(const Duration(minutes: 5)));
  }

  List<CinemaMovie> _uniqueMovies(List<CinemaMovie> values) {
    final seen = <String>{};
    final result = values.where((item) => seen.add(item.id)).toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<SeatLayout?> loadExactSeatLayout(
    Showtime showtime, {
    CinemaChain? chain,
  }) async {
    if (chain != CinemaChain.lotte || !showtime.hasExactSeatParameters) {
      return null;
    }
    return _loadLotteExactSeatLayout(showtime);
  }

  Future<SeatLayout> _loadLotteExactSeatLayout(Showtime showtime) async {
    final request = http.MultipartRequest('POST', Uri.parse(_lotteTicketing));
    request.headers['Accept'] = 'application/json, text/javascript, */*; q=0.01';
    request.fields['paramList'] = jsonEncode({
      'MethodName': 'GetSeats',
      'channelType': 'HO',
      'osType': 'W',
      'osVersion':
          'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 Chrome/134 Mobile Safari/537.36',
      'cinemaId': int.tryParse(showtime.theaterId) ?? showtime.theaterId,
      'screenId': int.tryParse(showtime.screenId) ?? showtime.screenId,
      'playDate': dashedDate(showtime.playDate),
      'playSequence':
          int.tryParse(showtime.playSequence) ?? showtime.playSequence,
      'screenDivisionCode':
          int.tryParse(showtime.screenDivisionCode) ?? showtime.screenDivisionCode,
    });

    http.StreamedResponse streamed;
    try {
      streamed =
          await _client.send(request).timeout(const Duration(seconds: 18));
    } on TimeoutException {
      throw const AppFailure('실제 좌석표 조회 시간이 초과됐습니다.');
    } on http.ClientException {
      throw const AppFailure('실제 좌석표에 연결하지 못했습니다.');
    }
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw AppFailure('실제 좌석표 조회 실패 (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final root = _map(decoded);
    if (root['IsOK'] == false) {
      throw AppFailure(_text(root['ResultMessage']).isEmpty
          ? '실제 좌석표 응답에 실패했습니다.'
          : _text(root['ResultMessage']));
    }
    final seatsRoot = _map(root['Seats']);
    final items = _maps(seatsRoot['Items']);
    if (items.isEmpty) {
      throw const AppFailure('이 회차의 실제 좌석 배치가 제공되지 않습니다.');
    }

    final parsed = items.map((item) {
      final row = _text(item['ShowSeatRow']).isNotEmpty
          ? _text(item['ShowSeatRow'])
          : _text(item['SeatRow']);
      final column = _integer(item['ShowSeatColumn'] ?? item['SeatColumn']);
      final rawNo = _text(item['SeatNo']);
      final label = rawNo.isNotEmpty
          ? rawNo
          : row.isEmpty || column <= 0
              ? ''
              : '$row$column';
      final status = _integer(item['SeatStatusCode']);
      final disabled = _text(item['SalesDisableTicketCode']).isNotEmpty;
      return _LotteSeat(
        cell: SeatCell(
          label: label,
          state: status == 0 && !disabled
              ? SeatState.available
              : SeatState.booked,
          row: row,
          column: column,
          x: _integer(item['SeatXCoordinate']),
          y: _integer(item['SeatYCoordinate']),
          selectable: label.isNotEmpty,
        ),
        width: max(1, _integer(item['SeatXLength'])),
      );
    }).where((seat) => seat.cell.label.isNotEmpty).toList();

    parsed.sort((a, b) {
      final yCompare = a.cell.y.compareTo(b.cell.y);
      if (yCompare != 0) return yCompare;
      final rowCompare = a.cell.row.compareTo(b.cell.row);
      if (rowCompare != 0) return rowCompare;
      final xCompare = a.cell.x.compareTo(b.cell.x);
      if (xCompare != 0) return xCompare;
      return a.cell.column.compareTo(b.cell.column);
    });

    final grouped = <String, List<_LotteSeat>>{};
    for (final seat in parsed) {
      final key = seat.cell.row.isNotEmpty
          ? '${seat.cell.y}:${seat.cell.row}'
          : '${seat.cell.y}';
      grouped.putIfAbsent(key, () => []).add(seat);
    }
    final rows = grouped.values.map(_withAisleSpacers).toList();
    return SeatLayout(
      rows: rows,
      isExact: true,
      source: '롯데시네마 공식 좌석 데이터',
      fetchedAt: DateTime.now(),
    );
  }

  List<SeatCell> _withAisleSpacers(List<_LotteSeat> seats) {
    seats.sort((a, b) {
      final xCompare = a.cell.x.compareTo(b.cell.x);
      return xCompare != 0
          ? xCompare
          : a.cell.column.compareTo(b.cell.column);
    });
    if (seats.length < 2) return seats.map((seat) => seat.cell).toList();
    final result = <SeatCell>[];
    for (var index = 0; index < seats.length; index++) {
      final current = seats[index];
      if (index > 0) {
        final previous = seats[index - 1];
        final columnGap = current.cell.column - previous.cell.column;
        final coordinateGap =
            current.cell.x - (previous.cell.x + max(1, previous.width));
        final spacerCount = columnGap > 1
            ? min(columnGap - 1, 3)
            : coordinateGap > max(current.width, previous.width) * 1.2
                ? 1
                : 0;
        for (var gap = 0; gap < spacerCount; gap++) {
          result.add(const SeatCell(
            label: '',
            state: SeatState.unknown,
            selectable: false,
          ));
        }
      }
      result.add(current.cell);
    }
    return result;
  }

  static String compactDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  static String dashedDate(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 8) {
      return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}';
    }
    return value;
  }

  static String normalizeTime(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.contains(':')) return value.substring(0, min(value.length, 5));
    if (digits.length >= 4) {
      return '${digits.substring(0, 2)}:${digits.substring(2, 4)}';
    }
    return value;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const {};
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value.map(_map).where((item) => item.isNotEmpty).toList();
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _LotteSeat {
  const _LotteSeat({required this.cell, required this.width});
  final SeatCell cell;
  final int width;
}
