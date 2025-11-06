import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/cell_model.dart';
import '../providers/game_provider.dart';

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

class HexagonBoardWidget extends ConsumerWidget {
  const HexagonBoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final board = gameState.board;
    if (board.isEmpty) return const SizedBox.shrink();
    final int rowCount = board.length;
    final int colCount = board[0].length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // --- 1. Calcular Tamaño para "FLAT-TOP, ODD-Q" (V7.0 - ¡Correcto para la imagen!) ---
        final double boardPixelWidth = constraints.maxWidth;
        final double boardPixelHeight = constraints.maxHeight;

        // Ancho de un hexágono (de lado a lado) es 2 * r
        // Altura de un hexágono (de punta a punta) es sqrt(3) * r

        // Ancho total del tablero:
        // Cada columna ocupa 1.5 * r horizontalmente. El ancho total es (columnas * 1.5 * r) + 0.5 * r
        final double widthRatio = (colCount * 1.5) + 0.5;

        // Alto total del tablero:
        // Cada fila ocupa sqrt(3) * r verticalmente. El alto total es (filas + 0.5) * sqrt(3) * r
        // (El 0.5 es para el offset de la última columna)
        final double heightRatio = (rowCount + 0.5) * sqrt(3);

        final double radiusFromWidth = boardPixelWidth / widthRatio;
        final double radiusFromHeight = boardPixelHeight / heightRatio;
        final double radius = min(radiusFromWidth, radiusFromHeight);

        if (radius <= 0 || radius.isNaN) {
          return const Center(child: Text("Calculando tamaño..."));
        }

        // Calcula el tamaño total real que el tablero renderizará
        final double totalRenderedWidth = widthRatio * radius;
        final double totalRenderedHeight = heightRatio * radius;

        // Calcula el offset para centrar el tablero
        final Offset centerOffset = Offset(
          (boardPixelWidth - totalRenderedWidth) / 2,
          (boardPixelHeight - totalRenderedHeight) / 2,
        );
        // --- FIN DE LA CORRECCIÓN DE CÁLCULO ---

        return GestureDetector(
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
        final Offset hexCenter = _hexToPixel(x, y, radius, centerOffset);
        _fillPaint.color = _getCellBackgroundColor(cell);
        canvas.save();
        canvas.translate(hexCenter.dx, hexCenter.dy);
        canvas.drawPath(_hexPath, _fillPaint);
        canvas.drawPath(_hexPath, _strokePaint);
        canvas.restore();
        _drawCellContent(canvas, cell, hexCenter);
      }
    }
  }

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

// --- ¡¡¡FUNCIONES MATEMÁTICAS TOTALMENTE NUEVAS PARA FLAT-TOP, ODD-Q!!! ---

/// Crea un Path para un hexágono "FLAT top" centrado en (0,0)
Path _createHexPath(double radius) {
  final Path path = Path();
  for (int i = 0; i < 6; i++) {
    // ¡Ángulo 0 para "flat top"! (en lugar de pi/6)
    final double angle = (pi / 3) * i;
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

/// Convierte coordenadas "odd-q" (x, y) a píxeles (Offset)
/// (x=row, y=col)
Offset _hexToPixel(int x, int y, double radius, Offset centerOffset) {
  final double hexWidth = 2 * radius; // Ancho de un hexágono (de lado a lado)
  final double hexHeight =
      sqrt(3) * radius; // Altura de un hexágono (de punta a punta)

  // Desplazamiento horizontal por columna
  double pixelX = radius * 1.5 * y;

  // Desplazamiento vertical por fila
  // Las columnas impares se desplazan media altura del hexágono hacia abajo
  double pixelY = hexHeight * x;
  if (y % 2 != 0) {
    pixelY += hexHeight * 0.5; // Desplaza media altura (radius * sqrt(3) / 2)
  }

  // Suma el offset de centrado general del tablero
  // y añade un padding inicial para que el hex (0,0) se dibuje completo
  return Offset(
    pixelX + centerOffset.dx + radius,
    pixelY + centerOffset.dy + (hexHeight / 2),
  );
}

/// Convierte píxeles (Offset) a coordenadas axiales (q, r)
(int, int) _pixelToAxial(Offset pixel, double radius, Offset centerOffset) {
  final double hexWidth = 2 * radius;
  final double hexHeight = sqrt(3) * radius;

  // Invierte el offset de centrado y el padding inicial
  final double adjustedX = pixel.dx - centerOffset.dx - radius;
  final double adjustedY = pixel.dy - centerOffset.dy - (hexHeight / 2);

  // Calcula una "columna aproximada" para saber si aplicar el offset inverso
  int roughCol = (adjustedX / (radius * 1.5))
      .round(); // Dividir por el paso horizontal
  double finalAdjustedY = adjustedY;
  if (roughCol % 2 != 0) {
    finalAdjustedY -= hexHeight * 0.5; // Resta el offset que se sumó al dibujar
  }

  // Convierte píxeles ajustados a coordenadas axiales fraccionarias (flat top)
  double q_frac = (2 / 3 * adjustedX) / radius;
  double r_frac = (-1 / 3 * adjustedX + sqrt(3) / 3 * finalAdjustedY) / radius;

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
  // x = r (fila)
  // y = q + (r - (r&1)) ~/ 2 (columna)

  final int x = r; // Fila
  final int y = q + (r - (r & 1)) ~/ 2; // Columna

  return (x, y);
}
