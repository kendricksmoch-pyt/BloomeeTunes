import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'recap_analytics.dart';

class ListeningTracker {
  static const String _key = 'bloomee_recap_events';
  static final ListeningTracker _instance = ListeningTracker._internal();
  factory ListeningTracker() => _instance;
  ListeningTracker._internal();

  List<ListeningEvent> _events = [];
  Timer? _timer;
  String? _curId; DateTime? _curStart; int _accMs = 0;
  String? _curName, _curArtist, _curAlbum, _curArt, _curSrc, _curProv;
  List<String> _curGenres = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _events = (prefs.getStringList(_key) ?? []).map((e) => ListeningEvent.fromJson(jsonDecode(e))).toList();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _save());
    debugPrint('[Recap] Loaded ${_events.length} events');
  }

  void onTrackStarted({required String trackId, required String trackName, required String artistName, required String albumName, String? artworkUrl, List<String>? genres, String? source, String? provider}) {
    _finishTrack();
    _curId = trackId; _curName = trackName; _curArtist = artistName; _curAlbum = albumName;
    _curArt = artworkUrl; _curGenres = genres ?? []; _curSrc = source; _curProv = provider;
    _curStart = DateTime.now(); _accMs = 0;
  }

  void onPaused() { if (_curStart != null) { _accMs += DateTime.now().difference(_curStart!).inMilliseconds; _curStart = DateTime.now(); } }
  void onResumed() { _curStart = DateTime.now(); }
  void onTrackEnded() { _finishTrack(); _curId = null; }

  void _finishTrack() {
    if (_curId == null) return;
    int total = _accMs + (_curStart != null ? DateTime.now().difference(_curStart!).inMilliseconds : 0);
    if (total >= 10000) { // Min 10 seconds to count
      _events.add(ListeningEvent(trackId: _curId!, trackName: _curName!, artistName: _curArtist!, albumName: _curAlbum!, artworkUrl: _curArt, genres: _curGenres, durationMs: total, timestamp: DateTime.now(), source: _curSrc, provider: _curProv));
    }
    _accMs = 0;
  }

  List<ListeningEvent> getEvents({DateTime? from, DateTime? until}) {
    var l = _events;
    if (from != null) l = l.where((e) => e.timestamp.isAfter(from)).toList();
    if (until != null) l = l.where((e) => e.timestamp.isBefore(until)).toList();
    return l;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final save = _events.length > 15000 ? _events.sublist(_events.length - 15000) : _events;
    await prefs.setStringList(_key, save.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> clearData() async { _events = []; final p = await SharedPreferences.getInstance(); await p.remove(_key); }
  void dispose() { _timer?.cancel(); _finishTrack(); _save(); }
}
