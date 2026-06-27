import 'dart:ui';
import 'dart:math';
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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tracker = ListeningTracker();
    final analytics = ListeningAnalytics();
    final now = DateTime.now();
    
    DateTime start;
    if (_period == RecapPeriod.weekly) {
      start = now.subtract(const Duration(days: 7));
    } else if (_period == RecapPeriod.monthly) {
      start = DateTime(now.year, now.month, 1);
    } else {
      start = DateTime(now.year, 1, 1);
    }
    
    final knownBefore = tracker.getEvents(until: start).map((e) => e.artistName).toSet();
    final recap = analytics.generateRecap(
      events: tracker.getEvents(), 
      period: _period, 
      knownBefore: knownBefore
    );
    
    if (mounted) {
      setState(() {
        _recap = recap;
        _loading = false;
      });
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Select Period", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(label: const Text('Weekly', style: TextStyle(color: Colors.white)), selected: _period == RecapPeriod.weekly, selectedColor: Colors.purple, onSelected: (_) { setState(() => _period = RecapPeriod.weekly); Navigator.pop(context); _load(); }),
                  ChoiceChip(label: const Text('Monthly', style: TextStyle(color: Colors.white)), selected: _period == RecapPeriod.monthly, selectedColor: Colors.purple, onSelected: (_) { setState(() => _period = RecapPeriod.monthly); Navigator.pop(context); _load(); }),
                  ChoiceChip(label: const Text('Yearly', style: TextStyle(color: Colors.white)), selected: _period == RecapPeriod.yearly, selectedColor: Colors.purple, onSelected: (_) { setState(() => _period = RecapPeriod.yearly); Navigator.pop(context); _load(); }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    if (_recap == null || _recap!.totalTracksPlayed == 0) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.graphic_eq, size: 80, color: Colors.white54),
              SizedBox(height: 16),
              Text("No listening data yet!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Listen to music and come back here.", style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return _CinematicStoryView(
      recap: _recap!, 
      onClose: () => Navigator.pop(context), 
      onChangePeriod: _showSettings
    );
  }
}

// ── CINEMATIC STORY VIEW ──────────────────────────────────────────────────
class _CinematicStoryView extends StatefulWidget {
  final RecapData recap;
  final VoidCallback onClose;
  final VoidCallback onChangePeriod;

  const _CinematicStoryView({required this.recap, required this.onClose, required this.onChangePeriod});

  @override
  State<_CinematicStoryView> createState() => _CinematicStoryViewState();
}

class _CinematicStoryViewState extends State<_CinematicStoryView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildSlides() {
    final r = widget.recap;
    return [
      _SlideIntro(recap: r),
      _SlideTimeListened(recap: r),
      _SlideTopArtist(recap: r),
      _SlideTopTrack(recap: r),
      _SlidePersonality(recap: r),
      _SlideAudioAffinity(recap: r),
      _SlideTopGenres(recap: r),
      _SlideOutro(recap: r),
    ];
  }

  void _goToNext() {
    if (_currentPage < _buildSlides().length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  void _goToPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = _buildSlides();
    
    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Blurred Background
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: _DynamicBackground(
              key: ValueKey(_currentPage),
              imageUrl: _getBackgroundImage(_currentPage),
              fallbackColors: widget.recap.auraColors,
            ),
          ),
          
          // Foreground Content (Tap Zones + PageView)
          Row(
            children: [
              // Left Tap Zone (Go Back)
              Expanded(
                flex: 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _goToPrevious,
                ),
              ),
              // Middle Tap Zone (Ignore to allow scrolling)
              Expanded(
                flex: 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {},
                ),
              ),
              // Right Tap Zone (Go Forward)
              Expanded(
                flex: 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _goToNext,
                ),
              ),
            ],
          ),

          // PageView for swiping
          PageView(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: slides,
          ),

          // Top UI (Progress Bars & Buttons)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(slides.length, (i) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      alignment: Alignment.centerLeft,
                      widthFactor: i <= _currentPage ? 1.0 : 0.0,
                      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 15,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white),
                  onPressed: widget.onChangePeriod,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getBackgroundImage(int page) {
    if (page == 2 && widget.recap.topArtists.isNotEmpty) return widget.recap.topArtists.first.imageUrl;
    if (page == 3 && widget.recap.topTracks.isNotEmpty) return widget.recap.topTracks.first.imageUrl;
    return null;
  }
}

// ── DYNAMIC BLURRED BACKGROUND ────────────────────────────────────────────
class _DynamicBackground extends StatelessWidget {
  final String? imageUrl;
  final List<int> fallbackColors;

  const _DynamicBackground({super.key, this.imageUrl, required this.fallbackColors});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: imageUrl != null
              ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildGradient())
              : _buildGradient(),
        ),
        // Heavy Blur Layer
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(fallbackColors[0]),
            Color(fallbackColors.length > 1 ? fallbackColors[1] : fallbackColors[0]),
            Colors.black,
          ],
        ),
      ),
    );
  }
}

// ── SLIDE WIDGETS & ANIMATIONS ────────────────────────────────────────────
abstract class _BaseSlide extends StatelessWidget {
  final RecapData recap;
  const _BaseSlide({required this.recap});

  Widget buildSlide(BuildContext context, Widget child) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            // Staggered Spring Animation Wrapper
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              builder: (context, value, c) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - value)),
                    child: c,
                  ),
                );
              },
              child: child,
            ),
            const Spacer(),
            const Text("Tap sides to navigate", style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SlideIntro extends _BaseSlide {
  const _SlideIntro({required super.recap});
  @override
  Widget build(BuildContext context) {
    return buildSlide(context, Column(
      children: [
        const Text("🎵", style: TextStyle(fontSize: 80)),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(colors: [Color(recap.auraColors[0]), Colors.white]).createShader(bounds),
          child: Text(
            "${recap.periodLabel} Recap", 
            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1.1),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(recap.dateRange, style: const TextStyle(color: Colors.white70, fontSize: 18)),
      ],
    ));
  }
}

class _SlideTimeListened extends _BaseSlide {
  const _SlideTimeListened({required super.recap});
  @override
  Widget build(BuildContext context) {
    return buildSlide(context, Column(
      children: [
        const Text("You listened for", style: TextStyle(color: Colors.white70, fontSize: 20)),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [Colors.purple, Colors.blue]).createShader(bounds),
          child: Text(
            recap.hoursListened.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.w900, height: 1),
          ),
        ),
        const Text("hours", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300)),
        const SizedBox(height: 32),
        glassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill(Icons.music_note, "${recap.uniqueTracksPlayed} Tracks"),
              const SizedBox(width: 16),
              _pill(Icons.person, "${recap.uniqueArtistsPlayed} Artists"),
            ],
          )
        )
      ],
    ));
  }

  Widget _pill(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _SlideTopArtist extends _BaseSlide {
  const _SlideTopArtist({required super.recap});
  @override
  Widget build(BuildContext context) {
    final artist = recap.topArtists.isNotEmpty ? recap.topArtists.first : null;
    return buildSlide(context, Column(
      children: [
        const Text("Your Top Artist", style: TextStyle(color: Colors.white70, fontSize: 20)),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(recap.auraColors[0]).withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
          ),
          child: CircleAvatar(
            radius: 90,
            backgroundColor: Colors.white24,
            backgroundImage: artist?.imageUrl != null ? NetworkImage(artist!.imageUrl!) : null,
            child: artist?.imageUrl == null ? const Icon(Icons.person, size: 90, color: Colors.white) : null,
          ),
        ),
        const SizedBox(height: 24),
        Text(artist?.name ?? "Unknown", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ],
    ));
  }
}

class _SlideTopTrack extends _BaseSlide {
  const _SlideTopTrack({required super.recap});
  @override
  Widget build(BuildContext context) {
    final track = recap.topTracks.isNotEmpty ? recap.topTracks.first : null;
    return buildSlide(context, Column(
      children: [
        const Text("Your Top Track", style: TextStyle(color: Colors.white70, fontSize: 20)),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: track?.imageUrl != null 
              ? Image.network(track!.imageUrl!, width: 200, height: 200, fit: BoxFit.cover) 
              : Container(width: 200, height: 200, color: Colors.white24, child: const Icon(Icons.music_note, size: 80, color: Colors.white)),
        ),
        const SizedBox(height: 24),
        Text(track?.name ?? "Unknown", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text("${track?.playCount ?? 0} Plays", style: const TextStyle(color: Colors.white70, fontSize: 16)),
      ],
    ));
  }
}

class _SlidePersonality extends _BaseSlide {
  const _SlidePersonality({required super.recap});
  @override
  Widget build(BuildContext context) {
    return buildSlide(context, Column(
      children: [
        const Text("Your Listening Personality", style: TextStyle(color: Colors.white70, fontSize: 20), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [Colors.orange, Colors.red]).createShader(bounds),
          child: Text(
            recap.personalityType,
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        glassCard(
          child: Text(recap.personalityDescription, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5), textAlign: TextAlign.center),
        )
      ],
    ));
  }
}

class _SlideAudioAffinity extends _BaseSlide {
  const _SlideAudioAffinity({required super.recap});
  @override
  Widget build(BuildContext context) {
    return buildSlide(context, Column(
      children: [
        const Text("Your Audio Aura", style: TextStyle(color: Colors.white70, fontSize: 20)),
        const SizedBox(height: 24),
        CustomPaint(
          size: const Size(300, 300),
          painter: RadarChartPainter(recap.audioFeatures, recap.auraColors),
        ),
        const SizedBox(height: 16),
        const Text("Based on your genre affinities", style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    ));
  }
}

class _SlideTopGenres extends _BaseSlide {
  const _SlideTopGenres({required super.recap});
  @override
  Widget build(BuildContext context) {
    return buildSlide(context, Column(
      children: [
        const Text("Top Genres", style: TextStyle(color: Colors.white70, fontSize: 20)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: recap.topGenres.map((g) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Color(g.color).withOpacity(0.3),
              border: Border.all(color: Color(g.color), width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(g.name, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          )).toList(),
        )
      ],
    ));
  }
}

class _SlideOutro extends _BaseSlide {
  const _SlideOutro({required super.recap});
  @override
  Widget build(BuildContext context) {
    return buildSlide(context, Column(
      children: [
        const Text("🔥 Longest Streak", style: TextStyle(color: Colors.white70, fontSize: 20)),
        const SizedBox(height: 16),
        Text("${recap.longestStreak} Days", style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.w900)),
        const SizedBox(height: 32),
        const Text("Thanks for using Bloomee", style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
        const Text("Tap the X to close", style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    ));
  }
}

// ── CUSTOM GLOWING RADAR CHART PAINTER ────────────────────────────────────
class RadarChartPainter extends CustomPainter {
  final AudioFeatures features;
  final List<int> colors;

  RadarChartPainter(this.features, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;
    
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final dataPaint = Paint()
      ..shader = LinearGradient(colors: [Color(colors[0]), Color(colors[1])]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10); // Glow effect

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const labels = ["Energy", "Dance", "Mood", "Acoustic"];
    final values = [features.energy, features.danceability, features.valence, features.acousticness];
    final angles = List.generate(4, (i) => (i * 90 - 90) * (pi / 180));

    for (var i = 0; i < 4; i++) {
      final p1 = center + Offset(radius * cos(angles[i]), radius * sin(angles[i]));
      canvas.drawLine(center, p1, bgPaint);
    }
    canvas.drawPath(_createPolygonPath(center, radius, angles), bgPaint);

    final dataPoints = List.generate(4, (i) => center + Offset(radius * values[i] * cos(angles[i]), radius * values[i] * sin(angles[i])));
    final dataPath = Path()..addPolygon(dataPoints, true);
    
    canvas.drawPath(dataPath, dataPaint); // Draw glow
    canvas.drawPath(dataPath, borderPaint); // Draw solid border over glow

    final textStyle = const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold);
    for (var i = 0; i < 4; i++) {
      final p = center + Offset((radius + 20) * cos(angles[i]), (radius + 20) * sin(angles[i]));
      final tp = TextPainter(text: TextSpan(text: labels[i], style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  Path _createPolygonPath(Offset center, double radius, List<double> angles) {
    final path = Path();
    for (var i = 0; i < angles.length; i++) {
      final p = center + Offset(radius * cos(angles[i]), radius * sin(angles[i]));
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
