enum RecapPeriod { weekly, monthly, yearly }

class ListeningEvent {
  final String trackId, trackName, artistName, albumName;
  final String? artworkUrl, source, provider;
  final List<String> genres;
  final int durationMs;
  final DateTime timestamp;

  ListeningEvent({
    required this.trackId, required this.trackName, required this.artistName,
    required this.albumName, this.artworkUrl, required this.genres,
    required this.durationMs, required this.timestamp, this.source, this.provider,
  });

  Map<String, dynamic> toJson() => {
    'trackId': trackId, 'trackName': trackName, 'artistName': artistName,
    'albumName': albumName, 'artworkUrl': artworkUrl, 'genres': genres,
    'durationMs': durationMs, 'timestamp': timestamp.toIso8601String(),
    'source': source, 'provider': provider,
  };

  factory ListeningEvent.fromJson(Map<String, dynamic> json) => ListeningEvent(
    trackId: json['trackId'] ?? '', trackName: json['trackName'] ?? '',
    artistName: json['artistName'] ?? '', albumName: json['albumName'] ?? '',
    artworkUrl: json['artworkUrl'], genres: List<String>.from(json['genres'] ?? []),
    durationMs: json['durationMs'] ?? 0, timestamp: DateTime.parse(json['timestamp']),
    source: json['source'], provider: json['provider'],
  );
}

class RecapData {
  final RecapPeriod period;
  final DateTime startDate, endDate;
  final int totalListeningTimeMs, totalTracksPlayed, uniqueTracksPlayed;
  final int uniqueArtistsPlayed, uniqueAlbumsPlayed;
  final List<TopItem> topTracks, topArtists, topAlbums;
  final List<GenreStat> topGenres;
  final int currentStreak, longestStreak;
  final List<DateTime> listeningDays;
  final List<HourlyStat> hourlyActivity;
  final List<DailyStat> dailyActivity;
  final int peakHour, newArtistsDiscovered;
  final List<String> discoveredArtists;
  final List<SessionStat> topSessions;
  final int averageSessionMinutes;
  final RecapData? previousPeriod;

  RecapData({
    required this.period, required this.startDate, required this.endDate,
    required this.totalListeningTimeMs, required this.totalTracksPlayed,
    required this.uniqueTracksPlayed, required this.uniqueArtistsPlayed,
    required this.uniqueAlbumsPlayed, required this.topTracks, required this.topArtists,
    required this.topAlbums, required this.topGenres, required this.currentStreak,
    required this.longestStreak, required this.listeningDays, required this.hourlyActivity,
    required this.dailyActivity, required this.peakHour, required this.newArtistsDiscovered,
    required this.discoveredArtists, required this.topSessions, required this.averageSessionMinutes,
    this.previousPeriod,
  });

  double get hoursListened => totalListeningTimeMs / 3600000;
  String get formattedTime {
    final h = totalListeningTimeMs ~/ 3600000;
    final m = (totalListeningTimeMs % 3600000) ~/ 60000;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  double? get changePercent {
    if (previousPeriod == null || previousPeriod!.totalListeningTimeMs == 0) return null;
    return ((totalListeningTimeMs - previousPeriod!.totalListeningTimeMs) / previousPeriod!.totalListeningTimeMs * 100);
  }

  String get periodLabel => period.name[0].toUpperCase() + period.name.substring(1);
  String get dateRange => '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}/${endDate.year}';
  String get mood => peakHour >= 22 || peakHour < 6 ? 'Night Owl 🦉' : peakHour < 12 ? 'Morning Person ☀️' : peakHour < 17 ? 'Daytime Vibes 🌤️' : 'Evening Relaxer 🌙';
}

class TopItem {
  final String id, name;
  final String? imageUrl;
  final int playCount, totalListeningTimeMs;
  double? percentage;
  TopItem({required this.id, required this.name, this.imageUrl, required this.playCount, required this.totalListeningTimeMs, this.percentage});
}

class GenreStat {
  final String name;
  final int count;
  final double percentage;
  static const colors = {'Pop': 0xFFFF6B6B, 'Rock': 0xFF4ECDC4, 'Hip Hop': 0xFF45B7D1, 'Bollywood': 0xFFFF9FF3, 'Punjabi': 0xFFF368E0, 'Lo-Fi': 0xFFA29BFE, 'Electronic': 0xFFFFEAA7};
  int get color => colors[name] ?? 0xFF95A5A6;
  GenreStat({required this.name, required this.count, required this.percentage});
}

class HourlyStat { final int hour, playCount, listeningTimeMs; HourlyStat({required this.hour, required this.playCount, required this.listeningTimeMs}); }
class DailyStat { final DateTime date; final int playCount, listeningTimeMs; DailyStat({required this.date, required this.playCount, required this.listeningTimeMs}); }
class SessionStat { final DateTime startTime; final int durationMinutes, trackCount; SessionStat({required this.startTime, required this.durationMinutes, required this.trackCount}); }

// --- ANALYTICS ENGINE ---
class ListeningAnalytics {
  RecapData generateRecap({ required List<ListeningEvent> events, required RecapPeriod period, Set<String>? knownBefore }) {
    final now = DateTime.now();
    final (start, end) = _dates(period, now);
    final filtered = events.where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end)).toList();
    if (filtered.isEmpty) return _empty(period, start, end);

    final totalMs = filtered.fold<int>(0, (s, e) => s + e.durationMs);
    final uTracks = filtered.map((e) => e.trackId).toSet();
    final uArtists = filtered.map((e) => e.artistName).toSet();
    final uAlbums = filtered.map((e) => e.albumName).toSet();
    final days = filtered.map((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day)).toSet().toList()..sort();
    
    final discovered = uArtists.difference(knownBefore ?? {}).toList();
    final hourly = List.generate(24, (h) => HourlyStat(hour: h, playCount: 0, listeningTimeMs: 0));
    for (var e in filtered) { 
      hourly[e.timestamp.hour] = HourlyStat(hour: e.timestamp.hour, playCount: hourly[e.timestamp.hour].playCount + 1, listeningTimeMs: hourly[e.timestamp.hour].listeningTimeMs + e.durationMs); 
    }
    final peakH = hourly.reduce((a, b) => a.listeningTimeMs > b.listeningTimeMs ? a : b).hour;

    return RecapData(
      period: period, startDate: start, endDate: end, totalListeningTimeMs: totalMs,
      totalTracksPlayed: filtered.length, uniqueTracksPlayed: uTracks.length,
      uniqueArtistsPlayed: uArtists.length, uniqueAlbumsPlayed: uAlbums.length,
      topTracks: _topList(filtered, totalMs, 'track'), topArtists: _topList(filtered, totalMs, 'artist'),
      topAlbums: _topList(filtered, totalMs, 'album'), topGenres: _topGenres(filtered),
      currentStreak: _streak(days, now), longestStreak: _longestStreak(days), listeningDays: days,
      hourlyActivity: hourly, dailyActivity: _dailyStats(filtered), peakHour: peakH,
      newArtistsDiscovered: discovered.length, discoveredArtists: discovered,
      topSessions: _sessions(filtered), averageSessionMinutes: 0, previousPeriod: null,
    );
  }

  (DateTime, DateTime) _dates(RecapPeriod p, DateTime n) {
    if (p == RecapPeriod.weekly) return (DateTime(n.year, n.month, n.day).subtract(const Duration(days: 7)), DateTime(n.year, n.month, n.day));
    if (p == RecapPeriod.monthly) return (DateTime(n.year, n.month, 1), DateTime(n.year, n.month + 1, 0, 23, 59, 59));
    return (DateTime(n.year, 1, 1), DateTime(n.year, 12, 31, 23, 59, 59));
  }

  List<TopItem> _topList(List<ListeningEvent> ev, int total, String type) {
    final map = <String, _Tmp>{};
    for (var e in ev) {
      final id = type == 'track' ? e.trackId : type == 'artist' ? e.artistName : '${e.albumName}-${e.artistName}';
      final name = type == 'track' ? e.trackName : type == 'artist' ? e.artistName : e.albumName;
      map.putIfAbsent(id, () => _Tmp(name, type == 'album' ? e.artworkUrl : null));
      map[id]!.ms += e.durationMs; 
      map[id]!.count++;
    }
    final list = map.entries.map((e) => TopItem(
      id: e.key, 
      name: e.value.name, 
      imageUrl: e.value.img, 
      playCount: e.value.count, 
      totalListeningTimeMs: e.value.ms, 
      percentage: total > 0 ? (e.value.ms / total * 100) : 0
    )).toList();
    
    list.sort((a, b) => b.totalListeningTimeMs.compareTo(a.totalListeningTimeMs));
    return list.take(20).toList();
  }

  List<GenreStat> _topGenres(List<ListeningEvent> ev) {
    final m = <String, int>{}; 
    int t = 0;
    for (var e in ev) { 
      for (var g in e.genres) { 
        m[g] = (m[g] ?? 0) + 1; 
        t++; 
      } 
    }
    final list = m.entries.map((e) => GenreStat(name: e.key, count: e.value, percentage: t > 0 ? (e.value / t * 100) : 0)).toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list.take(5).toList();
  }

  int _streak(List<DateTime> days, DateTime now) {
    int c = 0; 
    var d = DateTime(now.year, now.month, now.day);
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    while (days.contains(d)) { 
      c++; 
      d = d.subtract(const Duration(days: 1)); 
    }
    return c;
  }

  int _longestStreak(List<DateTime> days) {
    if (days.isEmpty) return 0; 
    int max = 1; 
    int c = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i].difference(days[i-1]).inDays == 1) { 
        c++; 
        if (c > max) max = c; 
      } else { 
        c = 1; 
      }
    }
    return max;
  }

  List<DailyStat> _dailyStats(List<ListeningEvent> ev) {
    final m = <String, _D>{};
    for (var e in ev) { 
      final k = '${e.timestamp.year}-${e.timestamp.month}-${e.timestamp.day}'; 
      m.putIfAbsent(k, () => _D(DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))); 
      m[k]!.c++; 
      m[k]!.ms += e.durationMs; 
    }
    return m.values.map((d) => DailyStat(date: d.d, playCount: d.c, listeningTimeMs: d.ms)).toList();
  }

  List<SessionStat> _sessions(List<ListeningEvent> ev) {
    if (ev.isEmpty) return [];
    final list = ev.toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    final res = <SessionStat>[]; 
    var cur = list.first.timestamp; 
    int ms = 0; 
    int cnt = 0;
    
    for (var e in list) {
      if (e.timestamp.difference(cur).inMinutes > 10 && cnt > 0) { 
        res.add(SessionStat(startTime: cur, durationMinutes: ms ~/ 60000, trackCount: cnt)); 
        cur = e.timestamp; 
        ms = 0; 
        cnt = 0; 
      }
      ms += e.durationMs; 
      cnt++; 
      cur = e.timestamp;
    }
    if (cnt > 0) res.add(SessionStat(startTime: cur, durationMinutes: ms ~/ 60000, trackCount: cnt));
    
    res.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
    return res.take(3).toList();
  }

  RecapData _empty(RecapPeriod p, DateTime s, DateTime e) => RecapData(
    period: p, startDate: s, endDate: e, totalListeningTimeMs: 0, totalTracksPlayed: 0,
    uniqueTracksPlayed: 0, uniqueArtistsPlayed: 0, uniqueAlbumsPlayed: 0, topTracks: [], topArtists: [],
    topAlbums: [], topGenres: [], currentStreak: 0, longestStreak: 0, listeningDays: [],
    hourlyActivity: List.generate(24, (i) => HourlyStat(hour: i, playCount: 0, listeningTimeMs: 0)),
    dailyActivity: [], peakHour: 0, newArtistsDiscovered: 0, discoveredArtists: [], topSessions: [], averageSessionMinutes: 0
  );
}

class _Tmp { 
  String name; 
  String? img; 
  int ms = 0; 
  int count = 0; 
  _Tmp(this.name, this.img); 
}

class _D { 
  DateTime d; 
  int c = 0; 
  int ms = 0; 
  _D(this.d); 
}
