import 'dart:math';

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

class AudioFeatures {
  final double energy;
  final double danceability;
  final double valence; // Happiness
  final double acousticness;

  AudioFeatures({required this.energy, required this.danceability, required this.valence, required this.acousticness});
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
  final AudioFeatures audioFeatures;
  final String personalityType;
  final String personalityDescription;
  final List<int> auraColors;
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
    required this.audioFeatures, required this.personalityType, required this.personalityDescription,
    required this.auraColors, this.previousPeriod,
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

  String get periodLabel {
    final name = period.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  String get dateRange {
    return '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}/${endDate.year}';
  }
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
  int get color => _genreColors[name] ?? 0xFF95A5A6;
  GenreStat({required this.name, required this.count, required this.percentage});
}

class HourlyStat {
  final int hour, playCount, listeningTimeMs;
  HourlyStat({required this.hour, required this.playCount, required this.listeningTimeMs});
}

class DailyStat {
  final DateTime date;
  final int playCount, listeningTimeMs;
  DailyStat({required this.date, required this.playCount, required this.listeningTimeMs});
}

class SessionStat {
  final DateTime startTime;
  final int durationMinutes, trackCount;
  SessionStat({required this.startTime, required this.durationMinutes, required this.trackCount});
}

// ── Genre Mapping for Audio Features & Aura ───────────────────────────────
const Map<String, int> _genreColors = {
  'Pop': 0xFFFF6B6B, 'Rock': 0xFF4ECDC4, 'Hip Hop': 0xFF45B7D1,
  'Bollywood': 0xFFFF9FF3, 'Punjabi': 0xFFF368E0, 'Lo-Fi': 0xFFA29BFE, 'Electronic': 0xFFFFEAA7,
  'Jazz': 0xFF6C5CE7, 'Classical': 0xFFA29BFE, 'R&B': 0xFFFD79A8, 'Metal': 0xFF2D3436,
};

const Map<String, Map<String, double>> _genreAudioMap = {
  'Pop': {'energy': 0.7, 'dance': 0.8, 'valence': 0.8, 'acoustic': 0.2},
  'Rock': {'energy': 0.9, 'dance': 0.4, 'valence': 0.5, 'acoustic': 0.1},
  'Hip Hop': {'energy': 0.7, 'dance': 0.8, 'valence': 0.4, 'acoustic': 0.1},
  'Lo-Fi': {'energy': 0.3, 'dance': 0.3, 'valence': 0.4, 'acoustic': 0.4},
  'Electronic': {'energy': 0.9, 'dance': 0.9, 'valence': 0.6, 'acoustic': 0.0},
  'Jazz': {'energy': 0.4, 'dance': 0.5, 'valence': 0.6, 'acoustic': 0.8},
};

class ListeningAnalytics {
  RecapData generateRecap({
    required List<ListeningEvent> events,
    required RecapPeriod period,
    Set<String>? knownBefore,
  }) {
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
      final h = e.timestamp.hour;
      hourly[h] = HourlyStat(hour: h, playCount: hourly[h].playCount + 1, listeningTimeMs: hourly[h].listeningTimeMs + e.durationMs);
    }
    final peakH = hourly.reduce((a, b) => a.listeningTimeMs > b.listeningTimeMs ? a : b).hour;

    final topGenres = _topGenres(filtered);
    final audioFeatures = _calculateAudioFeatures(filtered);
    final personality = _calculatePersonality(uArtists.length, discovered.length, filtered.length, uTracks.length);
    final aura = _generateAura(topGenres);

    return RecapData(
      period: period, startDate: start, endDate: end,
      totalListeningTimeMs: totalMs, totalTracksPlayed: filtered.length,
      uniqueTracksPlayed: uTracks.length, uniqueArtistsPlayed: uArtists.length,
      uniqueAlbumsPlayed: uAlbums.length,
      topTracks: _topList(filtered, totalMs, 'track'), topArtists: _topList(filtered, totalMs, 'artist'),
      topAlbums: _topList(filtered, totalMs, 'album'), topGenres: topGenres,
      currentStreak: _streak(days, now), longestStreak: _longestStreak(days),
      listeningDays: days, hourlyActivity: hourly, dailyActivity: _dailyStats(filtered),
      peakHour: peakH, newArtistsDiscovered: discovered.length, discoveredArtists: discovered,
      topSessions: _sessions(filtered), averageSessionMinutes: 0,
      audioFeatures: audioFeatures,
      personalityType: personality.$1, personalityDescription: personality.$2,
      auraColors: aura, previousPeriod: null,
    );
  }

  (DateTime, DateTime) _dates(RecapPeriod p, DateTime n) {
    if (p == RecapPeriod.weekly) return (DateTime(n.year, n.month, n.day).subtract(const Duration(days: 7)), DateTime(n.year, n.month, n.day));
    if (p == RecapPeriod.monthly) return (DateTime(n.year, n.month, 1), DateTime(n.year, n.month + 1, 0, 23, 59, 59));
    return (DateTime(n.year, 1, 1), DateTime(n.year, 12, 31, 23, 59, 59));
  }

  AudioFeatures _calculateAudioFeatures(List<ListeningEvent> ev) {
    double e = 0, d = 0, v = 0, a = 0;
    int count = 0;
    for (var event in ev) {
      for (var g in event.genres) {
        final map = _genreAudioMap[g];
        if (map != null) {
          e += map['energy']!; d += map['dance']!; v += map['valence']!; a += map['acoustic']!;
          count++;
        }
      }
    }
    if (count == 0) return AudioFeatures(energy: 0.5, danceability: 0.5, valence: 0.5, acousticness: 0.5);
    return AudioFeatures(energy: e/count, danceability: d/count, valence: v/count, acousticness: a/count);
  }

  (String, String) _calculatePersonality(int totalArtists, int discoveredArtists, int totalPlays, int uniqueTracks) {
    double discoveryRate = totalArtists > 0 ? discoveredArtists / totalArtists : 0;
    double loyaltyRate = uniqueTracks > 0 ? totalPlays / uniqueTracks : 0;

    if (discoveryRate > 0.5) return ("The Explorer", "You're constantly hunting for new sounds, with $discoveredArtists new artists discovered this period.");
    if (loyaltyRate > 3.0) return ("The Loyalist", "When you find a song you love, you stick with it. You replayed your favorites heavily.");
    if (discoveryRate < 0.2 && loyaltyRate < 2.0) return ("The Curator", "You have a refined, stable taste. You know exactly what you like and stick to your guns.");
    return ("The Vibe Surfer", "You balance finding new tracks with enjoying your classic favorites perfectly.");
  }

  List<int> _generateAura(List<GenreStat> genres) {
    if (genres.isEmpty) return [0xFF6C5CE7, 0xFFA29BFE];
    return genres.take(3).map((g) => g.color).toList();
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
    final list = map.entries.map((e) => TopItem(id: e.key, name: e.value.name, imageUrl: e.value.img, playCount: e.value.count, totalListeningTimeMs: e.value.ms, percentage: total > 0 ? (e.value.ms / total * 100) : 0)).toList();
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
    while (days.contains(d)) { c++; d = d.subtract(const Duration(days: 1)); }
    return c;
  }

  int _longestStreak(List<DateTime> days) {
    if (days.isEmpty) return 0;
    int max = 1; int c = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) { c++; if (c > max) max = c; } else { c = 1; }
    }
    return max;
  }

  List<DailyStat> _dailyStats(List<ListeningEvent> ev) {
    final m = <String, _D>{};
    for (var e in ev) {
      final k = '${e.timestamp.year}-${e.timestamp.month}-${e.timestamp.day}';
      m.putIfAbsent(k, () => _D(DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day)));
      m[k]!.c++; m[k]!.ms += e.durationMs;
    }
    return m.values.map((d) => DailyStat(date: d.d, playCount: d.c, listeningTimeMs: d.ms)).toList();
  }

  List<SessionStat> _sessions(List<ListeningEvent> ev) {
    if (ev.isEmpty) return [];
    final list = ev.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final res = <SessionStat>[];
    var cur = list.first.timestamp; int ms = 0; int cnt = 0;
    for (var e in list) {
      if (e.timestamp.difference(cur).inMinutes > 10 && cnt > 0) {
        res.add(SessionStat(startTime: cur, durationMinutes: ms ~/ 60000, trackCount: cnt));
        cur = e.timestamp; ms = 0; cnt = 0;
      }
      ms += e.durationMs; cnt++; cur = e.timestamp;
    }
    if (cnt > 0) res.add(SessionStat(startTime: cur, durationMinutes: ms ~/ 60000, trackCount: cnt));
    res.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
    return res.take(3).toList();
  }

  RecapData _empty(RecapPeriod p, DateTime s, DateTime e) {
    return RecapData(
      period: p, startDate: s, endDate: e, totalListeningTimeMs: 0, totalTracksPlayed: 0,
      uniqueTracksPlayed: 0, uniqueArtistsPlayed: 0, uniqueAlbumsPlayed: 0,
      topTracks: [], topArtists: [], topAlbums: [], topGenres: [],
      currentStreak: 0, longestStreak: 0, listeningDays: [],
      hourlyActivity: List.generate(24, (i) => HourlyStat(hour: i, playCount: 0, listeningTimeMs: 0)),
      dailyActivity: [], peakHour: 0, newArtistsDiscovered: 0, discoveredArtists: [],
      topSessions: [], averageSessionMinutes: 0,
      audioFeatures: AudioFeatures(energy: 0, danceability: 0, valence: 0, acousticness: 0),
      personalityType: "The Beginner", personalityDescription: "Listen to some music to unlock your personality!",
      auraColors: [0xFF6C5CE7, 0xFFA29BFE],
    );
  }
}

class _Tmp { String name; String? img; int ms = 0; int count = 0; _Tmp(this.name, this.img); }
class _D { DateTime d; int c = 0; int ms = 0; _D(this.d); }
