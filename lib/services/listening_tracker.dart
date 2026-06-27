import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'recap_analytics.dart';

class ListeningTracker with WidgetsBindingObserver {
  static final ListeningTracker _instance = ListeningTracker._internal();
  factory ListeningTracker() => _instance;
  ListeningTracker._internal();

  List<ListeningEvent> _events = [];
  String? _curId; 
  DateTime? _curStart; 
  int _accMs = 0;
  String? _curName, _curArtist, _curAlbum, _curArt, _curSrc, _curProv;
  List<String> _curGenres = [];

  Future<void> init() async {
    await _loadData();
    // Listen to app lifecycle to force-save when the app is closed/minimized
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[Recap] Tracker initialized. Loaded ${_events.length} events');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If app is closed, minimized, or goes to background, save instantly
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached) {
      _finishTrack();
      _saveData();
    }
  }

  Future<String> get _filePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/bloomee_recap_events.json';
  }

  Future<void> _loadData() async {
    try {
      final file = File(await _filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        _events = (jsonDecode(contents) as List).map((e) => ListeningEvent.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[Recap] Error loading data: $e');
      _events = [];
    }
  }

  Future<void> _saveData() async {
    try {
      final file = File(await _filePath);
      // Keep the file from growing infinitely (max 15,000 events)
      final save = _events.length > 15000 ? _events.sublist(_events.length - 15000) : _events;
      await file.writeAsString(jsonEncode(save.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[Recap] Error saving data: $e');
    }
  }

  void onTrackStarted({
    required String trackId, 
    required String trackName, 
    required String artistName, 
    required String albumName, 
    String? artworkUrl, 
    List<String>? genres, 
    String? source, 
    String? provider
  }) {
    // Finish the previous track and save it instantly
    _finishTrack();
    _saveData();

    _curId = trackId; 
    _curName = trackName; 
    _curArtist = artistName; 
    _curAlbum = albumName;
    _curArt = artworkUrl; 
    _curGenres = genres ?? []; 
    _curSrc = source; 
    _curProv = provider;
    _curStart = DateTime.now(); 
    _accMs = 0;
  }

  void onPaused() {
    if (_curStart != null) {
      _accMs += DateTime.now().difference(_curStart!).inMilliseconds;
      _curStart = null; // Stop counting until resumed
      _saveData(); // Save instantly on pause
    }
  }

  void onResumed() {
    _curStart = DateTime.now(); // Resume counting
  }

  void onTrackEnded() {
    _finishTrack();
    _curId = null;
    _saveData(); // Save instantly when song ends or is skipped
  }

  void _finishTrack() {
    if (_curId == null) return;
    int total = _accMs + (_curStart != null ? DateTime.now().difference(_curStart!).inMilliseconds : 0);
    
    // Only record if listened for 10 seconds or more
    if (total >= 10000) {
      _events.add(ListeningEvent(
        trackId: _curId!, 
        trackName: _curName!, 
        artistName: _curArtist!, 
        albumName: _curAlbum!, 
        artworkUrl: _curArt, 
        genres: _curGenres, 
        durationMs: total, 
        timestamp: DateTime.now(), 
        source: _curSrc, 
        provider: _curProv
      ));
    }
    _accMs = 0;
    _curStart = null;
  }

  List<ListeningEvent> getEvents({DateTime? from, DateTime? until}) {
    var l = _events;
    if (from != null) l = l.where((e) => e.timestamp.isAfter(from)).toList();
    if (until != null) l = l.where((e) => e.timestamp.isBefore(until)).toList();
    return l;
  }

  Future<void> clearData() async {
    _events = [];
    _curId = null;
    final file = File(await _filePath);
    if (await file.exists()) await file.delete();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finishTrack();
    _saveData();
  }
}
