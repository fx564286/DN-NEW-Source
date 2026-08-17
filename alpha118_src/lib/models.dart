import 'dart:convert';

enum CinemaChain { all, cgv, megabox, lotte }

extension CinemaChainX on CinemaChain {
  String get label => switch (this) {
        CinemaChain.all => '전체',
        CinemaChain.cgv => 'CGV',
        CinemaChain.megabox => '메가박스',
        CinemaChain.lotte => '롯데시네마',
      };

  String get apiKey => switch (this) {
        CinemaChain.all => 'all',
        CinemaChain.cgv => 'cgv',
        CinemaChain.megabox => 'megabox',
        CinemaChain.lotte => 'lottecinema',
      };

  String get bookingUrl => switch (this) {
        CinemaChain.all => 'https://www.cgv.co.kr/ticket/',
        CinemaChain.cgv => 'https://www.cgv.co.kr/ticket/',
        CinemaChain.megabox => 'https://www.megabox.co.kr/booking',
        CinemaChain.lotte => 'https://www.lottecinema.co.kr/NLCHS/Ticketing',
      };

  bool get supportsExactSeatMap => this == CinemaChain.lotte;
}

class Theater {
  const Theater({
    required this.chain,
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  final CinemaChain chain;
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  String get key => '${chain.name}:$id';

  Theater copyWithDistance(double? value) => Theater(
        chain: chain,
        id: id,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        distanceKm: value,
      );
}

class CinemaMovie {
  const CinemaMovie({
    required this.id,
    required this.name,
    this.rating = '',
  });

  final String id;
  final String name;
  final String rating;
}

class Showtime {
  const Showtime({
    required this.id,
    required this.movieId,
    required this.movieName,
    required this.theaterId,
    required this.theaterName,
    required this.playDate,
    required this.startTime,
    required this.endTime,
    required this.screenName,
    required this.totalSeats,
    required this.remainingSeats,
    this.screenId = '',
    this.playSequence = '',
    this.screenDivisionCode = '300',
  });

  final String id;
  final String movieId;
  final String movieName;
  final String theaterId;
  final String theaterName;
  final String playDate;
  final String startTime;
  final String endTime;
  final String screenName;
  final int totalSeats;
  final int remainingSeats;
  final String screenId;
  final String playSequence;
  final String screenDivisionCode;

  int get bookedSeats => totalSeats > 0
      ? (totalSeats - remainingSeats).clamp(0, totalSeats)
      : 0;

  bool get hasExactSeatParameters =>
      theaterId.isNotEmpty && screenId.isNotEmpty && playSequence.isNotEmpty;
}

enum SeatState { available, booked, selected, unknown }

class SeatCell {
  const SeatCell({
    required this.label,
    required this.state,
    this.row = '',
    this.column = 0,
    this.x = 0,
    this.y = 0,
    this.selectable = true,
  });

  final String label;
  final SeatState state;
  final String row;
  final int column;
  final int x;
  final int y;
  final bool selectable;

  bool get isSpacer => label.isEmpty || !selectable;
}

class SeatLayout {
  const SeatLayout({
    required this.rows,
    required this.isExact,
    this.source = '',
    this.fetchedAt,
  });

  final List<List<SeatCell>> rows;
  final bool isExact;
  final String source;
  final DateTime? fetchedAt;

  Iterable<SeatCell> get seats => rows.expand((row) => row);
  int get availableCount =>
      seats.where((seat) => seat.state == SeatState.available).length;
  int get bookedCount =>
      seats.where((seat) => seat.state == SeatState.booked).length;
}

class WatchItem {
  WatchItem({
    required this.id,
    required this.chain,
    required this.theaterId,
    required this.theaterName,
    required this.movieId,
    required this.movieName,
    required this.playDate,
    required this.startTime,
    required this.endTime,
    required this.screenName,
    required this.seatLabels,
    required this.bookingUrl,
    this.showtimeId = '',
    this.screenId = '',
    this.playSequence = '',
    this.screenDivisionCode = '300',
    this.watchMode = 'any',
    this.seatCount = 1,
    this.seatZone = '',
    this.remainingSeatsAtCreation = 0,
    this.matchMode = 'all',
    this.active = true,
  });

  final String id;
  final CinemaChain chain;
  final String theaterId;
  final String theaterName;
  final String movieId;
  final String movieName;
  final String playDate;
  final String startTime;
  final String endTime;
  final String screenName;
  final List<String> seatLabels;
  final String bookingUrl;
  final String showtimeId;
  final String screenId;
  final String playSequence;
  final String screenDivisionCode;
  final String watchMode;
  final int seatCount;
  final String seatZone;
  final int remainingSeatsAtCreation;
  final String matchMode;
  bool active;

  bool get hasExactSeatParameters =>
      chain == CinemaChain.lotte &&
      theaterId.isNotEmpty &&
      screenId.isNotEmpty &&
      playSequence.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'chain': chain.name,
        'theaterId': theaterId,
        'theaterName': theaterName,
        'movieId': movieId,
        'movieName': movieName,
        'playDate': playDate,
        'startTime': startTime,
        'endTime': endTime,
        'screenName': screenName,
        'seatLabels': seatLabels,
        'bookingUrl': bookingUrl,
        'showtimeId': showtimeId,
        'screenId': screenId,
        'playSequence': playSequence,
        'screenDivisionCode': screenDivisionCode,
        'watchMode': watchMode,
        'seatCount': seatCount,
        'seatZone': seatZone,
        'remainingSeatsAtCreation': remainingSeatsAtCreation,
        'matchMode': matchMode,
        'active': active,
      };

  factory WatchItem.fromJson(Map<String, dynamic> json) {
    final chainName = json['chain']?.toString() ?? 'cgv';
    return WatchItem(
      id: json['id']?.toString() ?? '',
      chain: CinemaChain.values.firstWhere(
        (value) => value.name == chainName,
        orElse: () => CinemaChain.cgv,
      ),
      theaterId: json['theaterId']?.toString() ?? '',
      theaterName: json['theaterName']?.toString() ?? '',
      movieId: json['movieId']?.toString() ?? '',
      movieName: json['movieName']?.toString() ?? '',
      playDate: json['playDate']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      screenName: json['screenName']?.toString() ?? '',
      seatLabels: List<String>.from(json['seatLabels'] as List? ?? const []),
      bookingUrl: json['bookingUrl']?.toString() ?? '',
      showtimeId: json['showtimeId']?.toString() ?? '',
      screenId: json['screenId']?.toString() ?? '',
      playSequence: json['playSequence']?.toString() ?? '',
      screenDivisionCode:
          json['screenDivisionCode']?.toString().isNotEmpty == true
              ? json['screenDivisionCode'].toString()
              : '300',
      watchMode: json['watchMode']?.toString() ?? 'any',
      seatCount: (json['seatCount'] as num?)?.toInt() ?? 1,
      seatZone: json['seatZone']?.toString() ?? '',
      remainingSeatsAtCreation:
          (json['remainingSeatsAtCreation'] as num?)?.toInt() ?? 0,
      matchMode: json['matchMode']?.toString() ?? 'all',
      active: json['active'] as bool? ?? true,
    );
  }

  String encode() => jsonEncode(toJson());
  static WatchItem decode(String value) =>
      WatchItem.fromJson(jsonDecode(value) as Map<String, dynamic>);
}

class CinemaCatalog {
  const CinemaCatalog({required this.movies, required this.showtimes});
  final List<CinemaMovie> movies;
  final List<Showtime> showtimes;
}
