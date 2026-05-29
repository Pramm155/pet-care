import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool withPattern;

  const AppBackground({
    super.key,
    required this.child,
    this.withPattern = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            const Color.fromARGB(255, 247, 248, 248),
            Colors.white,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Pattern / Siluet hewan di background
          if (withPattern) ...[
            _buildSiluetPattern(),
          ],
          // Elemen dekoratif bulat
          _buildDecorations(),
          // Konten utama
          child,
        ],
      ),
    );
  }

  Widget _buildSiluetPattern() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.03,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1,
          ),
          itemCount: 20,
          itemBuilder: (context, index) {
            final icons = [
              Icons.pets,
              Icons.pets,
              Icons.pets,
              Icons.pets,
              Icons.pets,
            ];
            return Icon(
              icons[index % icons.length],
              size: 50,
              color: Colors.blue.shade900,
            );
          },
        ),
      ),
    );
  }

  Widget _buildDecorations() {
    return Positioned.fill(
      child: CustomPaint(
        painter: BackgroundPainter(),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade200.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // Lingkaran besar di pojok kiri atas
    canvas.drawCircle(
      Offset(-50, -50),
      150,
      paint,
    );

    // Lingkaran sedang di pojok kanan bawah
    canvas.drawCircle(
      Offset(size.width + 50, size.height + 50),
      200,
      paint,
    );

    // Lingkaran kecil di tengah
    paint.color = Colors.blue.shade300.withOpacity(0.1);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      100,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}