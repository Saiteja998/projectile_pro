import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(
  const MaterialApp(home: ProjectilePro(), debugShowCheckedModeBanner: false),
);

class ProjectilePro extends StatefulWidget {
  const ProjectilePro({super.key});

  @override
  State<ProjectilePro> createState() => _ProjectileProState();
}

class _ProjectileProState extends State<ProjectilePro>
    with SingleTickerProviderStateMixin {
  // Physics parameters (SI units)
  double v0 = 25.0; // initial speed (m/s)
  double angleDeg = 45.0; // launch angle (degrees)
  final double g = 9.8;

  // Simulation state
  bool isLaunched = false;
  bool isPaused = false;
  double t = 0.0; // current simulation time (s)
  final List<Offset> pathPoints = []; // stores world coordinates (meters)
  late final Ticker _ticker;

  // Visual mapping
  double metersPerPixel =
      1.0; // computed based on range and canvas size in build

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!isLaunched || isPaused) return;

    // advance time by frame delta (seconds)
    final double dt = 1 / 60; // fixed-step for predictable behavior
    t += dt;

    final theta = angleDeg * pi / 180.0;
    final vx = v0 * cos(theta);
    final vy = v0 * sin(theta);

    final x = vx * t;
    final y = vy * t - 0.5 * g * t * t;

    if (y < 0) {
      // hit ground: stop and add final point at ground (y=0)
      final double tGround = _timeOfFlight();
      final double xGround = vx * tGround;
      pathPoints.add(Offset(xGround, 0));
      setState(() {
        isLaunched = false;
        _ticker.stop();
      });
      return;
    }

    setState(() {
      pathPoints.add(Offset(x, y));
    });
  }

  // Physics helpers
  double _timeOfFlight() {
    final theta = angleDeg * pi / 180.0;
    return 2 * v0 * sin(theta) / g;
  }

  double _range() {
    final theta = angleDeg * pi / 180.0;
    return v0 * v0 * sin(2 * theta) / g;
  }

  double _maxHeight() {
    final theta = angleDeg * pi / 180.0;
    return (v0 * v0 * pow(sin(theta), 2)) / (2 * g);
  }

  void _launch() {
    // reset path and time
    pathPoints.clear();
    t = 0.0;

    setState(() {
      isLaunched = true;
      isPaused = false;
    });

    _ticker.start();
  }

  void _pauseResume() {
    if (!isLaunched) return;
    setState(() => isPaused = !isPaused);
    if (isPaused) {
      _ticker.stop();
    } else {
      _ticker.start();
    }
  }

  void _reset() {
    _ticker.stop();
    setState(() {
      isLaunched = false;
      isPaused = false;
      t = 0.0;
      pathPoints.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double timeOfFlight = _timeOfFlight().clamp(0.0, double.infinity);
    final double rangeMeters = _range().clamp(0.0, double.infinity);
    final double maxHeight = _maxHeight().clamp(0.0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projectile Pro'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade900,
      body: Column(
        children: [
          // Top: Visualization area
          Expanded(
            flex: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasW = constraints.maxWidth;
                final canvasH = constraints.maxHeight;

                // compute metersPerPixel so the entire range fits nicely in width with margins
                final double margin = 20.0;
                final double usableW = max(100, canvasW - 2 * margin);
                final double targetRange = max(rangeMeters, 10.0);
                metersPerPixel =
                    (targetRange + 2) /
                    (usableW / 1.0); // extra margin in meters per pixel
                // But ensure vertical fits as well: adjust if max height would overflow
                final double topSpaceMeters =
                    maxHeight + 2.0; // add margin above
                final double usableH = max(100, canvasH - 2 * margin);
                final double metersPerPixelY =
                    (topSpaceMeters) / (usableH / 1.0);
                // pick the larger metersPerPixel to ensure fit both horizontally and vertically
                metersPerPixel = max(metersPerPixel, metersPerPixelY);

                return Container(
                  margin: EdgeInsets.all(margin),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: CustomPaint(
                    painter: _ProjectilePainter(
                      pathPoints: List<Offset>.from(pathPoints),
                      metersPerPixel: metersPerPixel,
                      projectileRadiusPx: 8,
                      showGrid: true,
                      rangeMeters: rangeMeters,
                      maxHeightMeters: maxHeight,
                    ),
                    child: GestureDetector(
                      onTapDown: (details) {
                        // Tap to launch from tapped location? (optional) - For now just shows coordinates
                        final local = details.localPosition;
                        // convert to meters world if needed - skipping for now
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(),
                    ),
                  ),
                );
              },
            ),
          ),

          // Middle: Controls & stats
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8,
              ),
              child: Column(
                children: [
                  // Sliders row
                  Row(
                    children: [
                      Expanded(
                        child: _buildLabeledSlider(
                          label: 'Speed (m/s)',
                          value: v0,
                          min: 5,
                          max: 80,
                          onChanged: (val) {
                            if (isLaunched)
                              return; // prevent changing mid-flight
                            setState(() => v0 = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLabeledSlider(
                          label: 'Angle (°)',
                          value: angleDeg,
                          min: 5,
                          max: 85,
                          onChanged: (val) {
                            if (isLaunched) return;
                            setState(() => angleDeg = val);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isLaunched ? null : _launch,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Launch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: isLaunched ? _pauseResume : null,
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(isPaused ? 'Resume' : 'Pause'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.replay),
                        label: const Text('Reset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Stats
                  Card(
                    color: Colors.grey.shade800,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(
                            'Time (s)',
                            timeOfFlight.toStringAsFixed(2),
                          ),
                          _statItem(
                            'Range (m)',
                            rangeMeters.toStringAsFixed(2),
                          ),
                          _statItem('Max H (m)', maxHeight.toStringAsFixed(2)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Info text
                  const Text(
                    'Note: You cannot change speed/angle while launched. Use Reset to set new values.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(1)}',
          style: const TextStyle(color: Colors.white70),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: Colors.amber,
          inactiveColor: Colors.white12,
        ),
      ],
    );
  }

  Widget _statItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.amberAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ProjectilePainter extends CustomPainter {
  final List<Offset> pathPoints; // in meters coordinates: (x, y)
  final double metersPerPixel;
  final int projectileRadiusPx;
  final bool showGrid;
  final double rangeMeters;
  final double maxHeightMeters;

  _ProjectilePainter({
    required this.pathPoints,
    required this.metersPerPixel,
    this.projectileRadiusPx = 6,
    this.showGrid = false,
    required this.rangeMeters,
    required this.maxHeightMeters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // draw ground line
    final paintGround = Paint()..color = Colors.white12;
    final groundY = size.height - 8; // some bottom margin
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      paintGround,
    );

    // transform world meters -> canvas coordinates:
    // world origin (0,0) maps to (leftMargin, groundY)
    final double leftMargin = 8;
    final double originX = leftMargin;
    final double originY = groundY;

    // optional grid
    if (showGrid) {
      final Paint gridPaint = Paint()
        ..color = Colors.white10
        ..style = PaintingStyle.stroke;
      final double stepMeters = max(1.0, (rangeMeters / 10.0).ceilToDouble());
      final double stepPx = stepMeters / metersPerPixel;
      for (double x = originX; x < size.width; x += stepPx) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    // draw trajectory path
    if (pathPoints.isNotEmpty) {
      final Paint pathPaint = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final Path path = Path();

      for (int i = 0; i < pathPoints.length; i++) {
        final world = pathPoints[i];
        final px = originX + world.dx / metersPerPixel;
        final py = originY - world.dy / metersPerPixel;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }

      canvas.drawPath(path, pathPaint);

      // draw projectile at last point
      final last = pathPoints.last;
      final px = originX + last.dx / metersPerPixel;
      final py = originY - last.dy / metersPerPixel;
      final Paint projPaint = Paint()..color = Colors.cyanAccent;
      canvas.drawCircle(
        Offset(px, py),
        projectileRadiusPx.toDouble(),
        projPaint,
      );
      // glow
      final Paint glow = Paint()..color = Colors.cyanAccent.withOpacity(0.25);
      canvas.drawCircle(
        Offset(px, py),
        projectileRadiusPx.toDouble() * 2.4,
        glow,
      );
    }

    // draw origin marker and labels
    final textPainter = (String text, Color color, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, at);
    };

    textPainter(
      'Origin (0,0)',
      Colors.white54,
      Offset(originX + 4, originY + 6),
    );
    // display scale
    textPainter(
      'Scale: ${metersPerPixel.toStringAsFixed(2)} m/px',
      Colors.white54,
      Offset(10, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _ProjectilePainter oldDelegate) {
    return oldDelegate.pathPoints != pathPoints ||
        oldDelegate.metersPerPixel != metersPerPixel;
  }
}
