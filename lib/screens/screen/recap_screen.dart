import 'package:flutter/material.dart';
import '../../services/recap_analytics.dart';
import '../../services/listening_tracker.dart';

class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});
  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  RecapData? _recap;
  RecapPeriod _period = RecapPeriod.monthly;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tracker = ListeningTracker();
    final analytics = ListeningAnalytics();
    final now = DateTime.now();
    final start = _period == RecapPeriod.weekly ? now.subtract(const Duration(days: 7)) : _period == RecapPeriod.monthly ? DateTime(now.year, now.month, 1) : DateTime(now.year, 1, 1);
    final knownBefore = tracker.getEvents(until: start).map((e) => e.artistName).toSet();
    final recap = analytics.generateRecap(events: tracker.getEvents(), period: _period, knownBefore: knownBefore);
    if (mounted) setState(() { _recap = recap; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${_period.name[0].toUpperCase()}${_period.name.substring(1)} Recap'), actions: [IconButton(icon: const Icon(Icons.tune), onPressed: () => _showSettings())]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _recap == null || _recap!.totalTracksPlayed == 0 ? _emptyState() : RefreshIndicator(onRefresh: _load, child: _mainList(theme)),
    );
  }

  Widget _emptyState() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.headphones_outlined, size: 80, color: Colors.grey), SizedBox(height: 16), Text("No listening data yet!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text("Listen to some music and come back.", style: TextStyle(color: Colors.grey))]));

  Widget _mainList(ThemeData theme) => ListView(padding: const EdgeInsets.all(16), children: [
    GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _StoryView(recap: _recap!))),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]), borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Your Recap", style: TextStyle(color: Colors.white70, fontSize: 16)),
          Text(_recap!.formattedTime, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.1)),
          const SizedBox(height: 16),
          Row(children: [_chip(Icons.music_note, '${_recap!.uniqueTracksPlayed} Tracks'), const SizedBox(width: 12), _chip(Icons.person, '${_recap!.uniqueArtistsPlayed} Artists'), const SizedBox(width: 12), _chip(Icons.local_fire_department, '${_recap!.currentStreak}d Streak')]),
          const SizedBox(height: 20), const Center(child: Text("Tap to view Full Story →", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ]),
      ),
    ),
    const SizedBox(height: 24),
    Row(children: [_statCard("Mood", _recap!.mood, Icons.emoji_emotions, Colors.purple), const SizedBox(width: 12), _statCard("Discovered", "${_recap!.newArtistsDiscovered} new", Icons.explore, Colors.teal)]),
    if (_recap!.changePercent != null) ...[const SizedBox(height: 12), _statCard("vs Last Period", "${_recap!.changePercent! > 0 ? '+' : ''}${_recap!.changePercent!.toStringAsFixed(0)}%", _recap!.changePercent! > 0 ? Icons.trending_up : Icons.trending_down, _recap!.changePercent! > 0 ? Colors.green : Colors.red)],
    const SizedBox(height: 24), _sectionTitle("Top Tracks"),
    ..._recap!.topTracks.take(5).map((t) => ListTile(leading: Text('#${_recap!.topTracks.indexOf(t)+1}', style: TextStyle(color: _recap!.topTracks.indexOf(t) < 3 ? theme.colorScheme.primary : Colors.grey, fontWeight: FontWeight.bold)), title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${t.playCount} plays • ${t.percentage?.toStringAsFixed(1)}%'), trailing: const Icon(Icons.play_arrow, color: Colors.grey))),
    const SizedBox(height: 24), _sectionTitle("Top Artists"),
    SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _recap!.topArtists.length.clamp(0, 8), itemBuilder: (context, i) { final a = _recap!.topArtists[i]; return Padding(padding: const EdgeInsets.only(right: 16), child: Column(children: [CircleAvatar(radius: 35, backgroundColor: Colors.grey[800], backgroundImage: a.imageUrl != null ? NetworkImage(a.imageUrl!) : null, child: a.imageUrl == null ? const Icon(Icons.person) : null), const SizedBox(height: 8), SizedBox(width: 80, child: Text(a.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))])); })),
    const SizedBox(height: 24), _sectionTitle("Top Genres"),
    Wrap(spacing: 8, runSpacing: 8, children: _recap!.topGenres.map((g) => Chip(backgroundColor: Color(g.color).withOpacity(0.2), label: Text('${g.name} (${g.percentage.toStringAsFixed(0)}%)', style: TextStyle(color: Color(g.color))), side: BorderSide.none)).toList()),
    const SizedBox(height: 24), _sectionTitle("Activity Heatmap"), _Heatmap(daily: _recap!.dailyActivity, color: theme.colorScheme.primary),
    const SizedBox(height: 24), _sectionTitle("When You Listen"), _HourlyChart(hourly: _recap!.hourlyActivity, color: theme.colorScheme.primary),
    const SizedBox(height: 40),
  ]);

  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
  Widget _chip(IconData i, String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, color: Colors.white, size: 16), const SizedBox(width: 6), Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]));
  Widget _statCard(String t, String v, IconData i, Color c) => Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c), const SizedBox(height: 8), Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)), Text(t, style: const TextStyle(color: Colors.grey, fontSize: 12))])));

  void _showSettings() => showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Padding(padding: EdgeInsets.all(16), child: Text("Recap Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
    ToggleButtons(selected: [_period == RecapPeriod.weekly, _period == RecapPeriod.monthly, _period == RecapPeriod.yearly], isSelected: [_period == RecapPeriod.weekly, _period == RecapPeriod.monthly, _period == RecapPeriod.yearly], onPressed: (i) { setState(() => _period = RecapPeriod.values[i]); Navigator.pop(context); _load(); }, children: const [Padding(padding: EdgeInsets.all(12), child: Text('Weekly')), Padding(padding: EdgeInsets.all(12), child: Text('Monthly')), Padding(padding: EdgeInsets.all(12), child: Text('Yearly'))]),
    const SizedBox(height: 16),
    ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: const Text("Clear Recap Data", style: TextStyle(color: Colors.red)), onTap: () { ListeningTracker().clearData(); Navigator.pop(context); _load(); })
  ])));
}

class _StoryView extends StatelessWidget {
  final RecapData recap;
  const _StoryView({required this.recap});
  @override
  Widget build(BuildContext context) {
    final slides = [
      _Slide(colors: [Colors.purple, Colors.deepPurple], child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("🎵", style: TextStyle(fontSize: 60)), const SizedBox(height: 16), Text("${recap.periodLabel} Recap", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), Text(recap.dateRange, style: const TextStyle(color: Colors.white70))])),
      _Slide(colors: [Colors.blue, Colors.indigo], child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("You listened to", style: TextStyle(color: Colors.white70)), Text(recap.hoursListened.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold, height: 1)), const Text("hours of music", style: TextStyle(color: Colors.white))])),
      _Slide(colors: [Colors.teal, Colors.green], child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Top Artist", style: TextStyle(color: Colors.white70, fontSize: 20)), const SizedBox(height: 16), CircleAvatar(radius: 60, backgroundColor: Colors.white24, backgroundImage: recap.topArtists.isNotEmpty && recap.topArtists.first.imageUrl != null ? NetworkImage(recap.topArtists.first.imageUrl!) : null), const SizedBox(height: 16), Text(recap.topArtists.isNotEmpty ? recap.topArtists.first.name : "N/A", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center)])),
      _Slide(colors: [Colors.orange, Colors.red], child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("🔥 Current Streak", style: TextStyle(color: Colors.white70, fontSize: 20)), Text("${recap.currentStreak} Days", style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)), Text("Longest: ${recap.longestStreak} days", style: const TextStyle(color: Colors.white70))])),
      _Slide(colors: [Colors.pink, Colors.purple], child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Your Vibe", style: TextStyle(color: Colors.white70, fontSize: 20)), const SizedBox(height: 16), Text(recap.mood, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))])),
      _Slide(colors: [Colors.indigo, Colors.blue], child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Discovery", style: TextStyle(color: Colors.white70, fontSize: 20)), Text("${recap.newArtistsDiscovered}", style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)), const Text("New Artists Found", style: TextStyle(color: Colors.white))])),
    ];
    return Scaffold(backgroundColor: Colors.black, body: PageView.builder(scrollDirection: Axis.vertical, children: slides));
  }
}

class _Slide extends StatelessWidget { final List<Color> colors; final Widget child; const _Slide({required this.colors, required this.child}); @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)), child: Padding(padding: const EdgeInsets.all(32), child: child)); }

class _Heatmap extends StatelessWidget { final List<DailyStat> daily; final Color color; const _Heatmap({required this.daily, required this.color}); @override Widget build(BuildContext context) { if (daily.isEmpty) return const SizedBox(); final max = daily.map((d) => d.listeningTimeMs).reduce((a, b) => a > b ? a : b); return Wrap(spacing: 3, runSpacing: 3, children: daily.map((d) { final op = max > 0 ? (d.listeningTimeMs / max) : 0.0; return Tooltip(message: "${d.date.day}/${d.date.month}\n${d.listeningTimeMs ~/ 60000} min", child: Container(width: 14, height: 14, decoration: BoxDecoration(color: d.listeningTimeMs > 0 ? color.withOpacity(0.2 + (op * 0.8)) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(3)))); }).toList()); }}
class _HourlyChart extends StatelessWidget { final List<HourlyStat> hourly; final Color color; const _HourlyChart({required this.hourly, required this.color}); @override Widget build(BuildContext context) { if (hourly.isEmpty) return const SizedBox(); final max = hourly.map((h) => h.listeningTimeMs).reduce((a, b) => a > b ? a : b); final now = DateTime.now().hour; return SizedBox(height: 100, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: hourly.map((h) { final ht = max > 0 ? (h.listeningTimeMs / max * 100) : 0.0; return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Container(height: ht.clamp(2.0, 100.0), decoration: BoxDecoration(color: h.hour == now ? Colors.red : color.withOpacity(0.6), borderRadius: BorderRadius.circular(4)))); }); }).toList())); }}
