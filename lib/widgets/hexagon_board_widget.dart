import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/cell_model.dart';
import '../providers/game_provider.dart';

/// Mapa de colores para los números, para una mejor apariencia visual
const Map<int, Color> numberColors = {
  1: Colors.blue,
  2: Colors.green,
  3: Colors.red,
  4: Colors.purple,
  5: Colors.brown,
  6: Colors.cyan,
  7: Colors.black,
  8: Colors.grey,
};

/// Widget principal que maneja el estado, el tamaño y las interacciones
class HexagonBoardWidget extends ConsumerWidget {
  const HexagonBoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final board = gameState.board;

    if (board.isEmpty) {
      return const SizedBox.shrink();
    }

    final int rowCount = board.length;
    final int colCount = board[0].length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // --- 1. Calcular el Tamaño del Hexágono ---
        final double boardPixelWidth = constraints.maxWidth;
        final double boardPixelHeight = constraints.maxHeight;

        // Fórmulas para un hexágono "pointy top" en layout "odd-q"
        // (x=fila, y=columna)
        // Ancho total = (ancho hex) * columnas
        // Altura total = (alto hex * 0.75) * (filas - 1) + alto hex
        // O más simple: (alto hex) * (0.75 * filas + 0.25)
        // O más simple aún: (radio * 2) * (0.75 * filas + 0.25) = radio * (1.5 * filas + 0.5)

        // CORRECCIÓN: La lógica del provider (isOddCol = y % 2 != 0) es "odd-q".
        // La altura total es (filas * alto_hex) + (radio, si hay columnas impares)
        // Esta es la matemática más robusta y correcta:

        final double radiusFromWidth = boardPixelWidth / (sqrt(3) * colCount);
        final double radiusFromHeight = boardPixelHeight / (2 * rowCount + 1);
        final double radius = min(radiusFromWidth, radiusFromHeight);

        // Si el radio es 0 o inválido, no dibujes nada.
        if (radius <= 0 || radius.isNaN) {
          return const Center(child: Text("Calculando tamaño..."));
        }

        final double finalHexWidth = sqrt(3) * radius;
        final double finalHexHeight = 2 * radius;

        // Calcula el tamaño total real del tablero dibujado
        final double totalWidth = finalHexWidth * colCount;
        final double totalHeight =
            finalHexHeight * rowCount + radius; // Altura total con el offset

        // Calcula el offset para centrar el tablero
        final Offset centerOffset = Offset(
          (boardPixelWidth - totalWidth) / 2,
          (boardPixelHeight - totalHeight) / 2,
        );
        // --- FIN DE LA CORRECCIÓN ---

        return GestureDetector(
          // --- 2. Manejar Interacciones (Tap) ---
          onTapDown: (details) {
            final (int x, int y) = _pixelToHex(
              details.localPosition,
              radius,
              centerOffset,
            );

            if (_isValidCell(x, y, rowCount, colCount, board)) {
              ref.read(gameProvider.notifier).revealCell(x, y);
            }
          },
          // --- 3. Manejar Interacciones (Long Press) ---
          onLongPressStart: (details) {
            final (int x, int y) = _pixelToHex(
              details.localPosition,
              radius,
              centerOffset,
            );

            if (_isValidCell(x, y, rowCount, colCount, board)) {
              ref.read(gameProvider.notifier).toggleFlag(x, y);
            }
          },

          // --- 4. Dibujar el Tablero ---
          child: CustomPaint(
            painter: _HexagonPainter(
              board: board,
              radius: radius,
              centerOffset: centerOffset,
              isDarkMode: Theme.of(context).brightness == Brightness.dark,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  bool _isValidCell(int x, int y, int rows, int cols, List<List<Cell>> board) {
    return x >= 0 && x < rows && y >= 0 && y < cols && !board[x][y].isBlocked;
  }
}

/// El Painter que dibuja el tablero en el Canvas
class _HexagonPainter extends CustomPainter {
  final List<List<Cell>> board;
  final double radius;
  final Offset centerOffset;
  final bool isDarkMode;

  final Path _hexPath;
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = Colors.black.withOpacity(0.1);

  _HexagonPainter({
    required this.board,
    required this.radius,
    required this.centerOffset,
    required this.isDarkMode,
  }) : _hexPath = _createHexPath(radius);

  @override
  void paint(Canvas canvas, Size size) {
    final int rowCount = board.length;
    final int colCount = board[0].length;

    for (int x = 0; x < rowCount; x++) {
      for (int y = 0; y < colCount; y++) {
        final Cell cell = board[x][y];
        if (cell.isBlocked) continue;

        // Calcula el centro en píxeles de este hexágono
        final Offset hexCenter = _hexToPixel(x, y, radius, centerOffset);

        // --- 1. Dibujar el Hexágono ---
        _fillPaint.color = _getCellBackgroundColor(cell);

        canvas.save();
        canvas.translate(hexCenter.dx, hexCenter.dy);
        canvas.drawPath(_hexPath, _fillPaint);
        canvas.drawPath(_hexPath, _strokePaint);
        canvas.restore();

        // --- 2. Dibujar el Contenido (Número, Bandera, Bomba) ---
        _drawCellContent(canvas, cell, hexCenter);
      }
    }
  }

  /// Dibuja el contenido de la celda
  void _drawCellContent(Canvas canvas, Cell cell, Offset center) {
    Widget? contentWidget;
    switch (cell.state) {
      case CellState.flagged:
        contentWidget = FaIcon(
          FontAwesomeIcons.flag,
          color: Colors.white,
          size: radius * 0.8,
        );
        break;
      case CellState.mine:
        contentWidget = FaIcon(
          FontAwesomeIcons.bomb,
          color: Colors.white,
          size: radius * 0.8,
        );
        break;
      case CellState.revealed:
        if (cell.isMine) {
          contentWidget = FaIcon(
            FontAwesomeIcons.bomb,
            color: Colors.black,
            size: radius * 0.8,
          );
        } else if (cell.adjacentMines > 0) {
          contentWidget = Text(
            '${cell.adjacentMines}',
            style: TextStyle(
              color: numberColors[cell.adjacentMines],
              fontWeight: FontWeight.bold,
              fontSize: radius,
            ),
          );
        }
        break;
      case CellState.hidden:
        break;
    }

    if (contentWidget != null) {
      TextPainter textPainter = TextPainter(
        text: (contentWidget is Text)
            ? TextSpan(text: contentWidget.data, style: contentWidget.style)
            : (contentWidget is FaIcon)
            ? TextSpan(
                text: String.fromCharCode(contentWidget.icon!.codePoint),
                style: TextStyle(
                  fontFamily: contentWidget.icon!.fontFamily,
                  package: contentWidget.icon!.fontPackage,
                  fontSize: contentWidget.size,
                  color: contentWidget.color,
                ),
              )
            : const TextSpan(),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final Offset textOffset = Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  /// Obtiene el color de fondo de la celda
  Color _getCellBackgroundColor(Cell cell) {
    switch (cell.state) {
      case CellState.hidden:
      case CellState.flagged:
        return isDarkMode ? Colors.blueGrey.shade700 : Colors.blueGrey.shade300;
      case CellState.revealed:
        return isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
      case CellState.mine:
        return Colors.red.withOpacity(0.7);
    }
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.radius != radius ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

// --- FUNCIONES MATEMÁTICAS DE COORDENADAS ---

/// Crea un Path para un hexágono "pointy top" centrado en (0,0)
Path _createHexPath(double radius) {
  final Path path = Path();
  for (int i = 0; i < 6; i++) {
    final double angle = (pi / 3) * i + (pi / 6); // +pi/6 para "pointy top"
    final double x = radius * cos(angle);
    final double y = radius * sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

/// Convierte coordenadas de la cuadrícula "odd-q" (x, y) a píxeles (Offset)
/// (x=row, y=col)
/// Esto coincide con la lógica de vecinos de 'game_provider.dart'
Offset _hexToPixel(int x, int y, double radius, Offset centerOffset) {
  // La lógica del provider (isOddCol = y % 2 != 0) es "odd-q".
  // La conversión de píxeles correcta para "odd-q" (pointy top) es:

  // Añadimos medio hexágono (radio) al offset para que el toque (0,0)
  // no quede cortado en el borde.
  final double px =
      centerOffset.dx + radius * sqrt(3) * y + (radius * sqrt(3) / 2);
  final double py = centerOffset.dy + radius * 2 * x + radius;

  if (y % 2 != 0) {
    // Si la columna es impar, se desplaza hacia abajo por 'radius' (media altura)
    return Offset(px, py + radius);
  } else {
    return Offset(px, py);
  }
}

/// Convierte píxeles (Offset) a coordenadas axiales (q, r)
(int, int) _pixelToAxial(Offset pixel, double radius, Offset centerOffset) {
  // Ajusta el píxel basándose en el offset de centrado y el padding
  final double relX = pixel.dx - centerOffset.dx - (radius * sqrt(3) / 2);
  final double relY = pixel.dy - centerOffset.dy - radius;

  // Convierte píxeles a coordenadas axiales fraccionarias (pointy top)
  double q_frac = (sqrt(3) / 3 * relX - 1 / 3 * relY) / radius;
  double r_frac = (2 / 3 * relY) / radius;

  // Redondea a las coordenadas axiales enteras más cercanas
  return _axialRound(q_frac, r_frac);
}

/// Redondea coordenadas axiales
(int, int) _axialRound(double q, double r) {
  double s = -q - r;
  int q_round = q.round();
  int r_round = r.round();
  int s_round = s.round();

  double q_diff = (q_round - q).abs();
  double r_diff = (r_round - r).abs();
  double s_diff = (s_round - s).abs();

  if (q_diff > r_diff && q_diff > s_diff) {
    q_round = -r_round - s_round;
  } else if (r_diff > s_diff) {
    r_round = -q_round - s_round;
  }

  return (q_round, r_round);
}

/// Convierte píxeles (Offset) a coordenadas de la cuadrícula "odd-q" (x, y)
(int, int) _pixelToHex(Offset pixel, double radius, Offset centerOffset) {
  // 1. Convierte píxel a axial (la matemática más robusta)
  final (int q, int r) = _pixelToAxial(pixel, radius, centerOffset);

  // 2. Convierte axial (q, r) a "odd-q" offset (x, y)
  // Esta es la conversión inversa a la de "odd-q" a axial:
  // q = y
  // r = x - (y - (y & 1)) ~/ 2

  final int y = q;
  final int x = r + (q - (q & 1)) ~/ 2;

  return (x, y);
}
