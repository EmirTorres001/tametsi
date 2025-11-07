import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/cell_model.dart';
import '../providers/game_provider.dart';

/// --- NUEVO: Provider para la celda tocada ---
final touchedCellProvider = StateProvider<(int, int)?>((ref) => null);

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

class HexagonBoardWidget extends ConsumerStatefulWidget {
  const HexagonBoardWidget({super.key});

  @override
  ConsumerState<HexagonBoardWidget> createState() => _HexagonBoardWidgetState();
}

class _HexagonBoardWidgetState extends ConsumerState<HexagonBoardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final board = gameState.board;
    if (board.isEmpty) return const SizedBox.shrink();
    final int rowCount = board.length;
    final int colCount = board[0].length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double boardPixelWidth = constraints.maxWidth;
        final double boardPixelHeight = constraints.maxHeight;

        final double widthRatio = (colCount * 1.5) + 0.5;
        final double heightRatio = (rowCount + 0.5) * sqrt(3);

        final double radiusFromWidth = boardPixelWidth / widthRatio;
        final double radiusFromHeight = boardPixelHeight / heightRatio;
        final double radius = min(radiusFromWidth, radiusFromHeight);

        if (radius <= 0 || radius.isNaN) {
          return const Center(child: Text("Calculando tamaño..."));
        }

        final double totalRenderedWidth = widthRatio * radius;
        final double totalRenderedHeight = heightRatio * radius;

        final Offset centerOffset = Offset(
          (boardPixelWidth - totalRenderedWidth) / 2,
          (boardPixelHeight - totalRenderedHeight) / 2,
        );

        return GestureDetector(
          onTapDown: (details) {
            final (int x, int y) = _pixelToHex(
              details.localPosition,
              radius,
              centerOffset,
            );
            if (_isValidCell(x, y, rowCount, colCount, board)) {
              // Actualiza provider de celda tocada
              ref.read(touchedCellProvider.notifier).state = (x, y);
              _animController.forward(from: 0.0);

              // Acción de juego
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
              ref.read(touchedCellProvider.notifier).state = (x, y);
              _animController.forward(from: 0.0);
              ref.read(gameProvider.notifier).toggleFlag(x, y);
            }
          },
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return CustomPaint(
                painter: _HexagonPainter(
                  board: board,
                  radius: radius,
                  centerOffset: centerOffset,
                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                  touchedCell: ref.watch(touchedCellProvider),
                  touchProgress: _animController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
        );
      },
    );
  }

  bool _isValidCell(int x, int y, int rows, int cols, List<List<Cell>> board) {
    return x >= 0 && x < rows && y >= 0 && y < cols && !board[x][y].isBlocked;
  }
}

// --- Painter con animación visual ---
class _HexagonPainter extends CustomPainter {
  final List<List<Cell>> board;
  final double radius;
  final Offset centerOffset;
  final bool isDarkMode;
  final (int, int)? touchedCell;
  final double touchProgress; // Valor de 0.0 a 1.0
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
    required this.touchedCell,
    required this.touchProgress,
  }) : _hexPath = _createHexPath(radius);

  @override
  void paint(Canvas canvas, Size size) {
    final int rowCount = board.length;
    final int colCount = board[0].length;

    for (int x = 0; x < rowCount; x++) {
      for (int y = 0; y < colCount; y++) {
        final cell = board[x][y];
        if (cell.isBlocked) continue;

        final Offset hexCenter = _hexToPixel(x, y, radius, centerOffset);

        // --- Efecto visual al tocar ---
        bool isTouched = (touchedCell?.$1 == x && touchedCell?.$2 == y);
        double scale = isTouched ? (1.0 + 0.2 * (1 - touchProgress)) : 1.0;
        Color color = _getCellBackgroundColor(cell);
        if (isTouched) {
          color = color.withOpacity(0.5 + 0.5 * (1 - touchProgress));
        }

        _fillPaint.color = color;
        canvas.save();
        canvas.translate(hexCenter.dx, hexCenter.dy);
        canvas.scale(scale);
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
  bool shouldRepaint(covariant _HexagonPainter old) =>
      old.board != board ||
      old.radius != radius ||
      old.isDarkMode != isDarkMode ||
      old.touchedCell != touchedCell ||
      old.touchProgress != touchProgress;
}

Path _createHexPath(double radius) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = (pi / 3) * i;
    final x = radius * cos(angle);
    final y = radius * sin(angle);
    if (i == 0)
      path.moveTo(x, y);
    else
      path.lineTo(x, y);
  }
  path.close();
  return path;
}

Offset _hexToPixel(int x, int y, double radius, Offset centerOffset) {
  final double hexWidth = 2 * radius;
  final double hexHeight = sqrt(3) * radius;

  double pixelX = radius * 1.5 * y;
  double pixelY = hexHeight * x;
  if (y % 2 != 0) pixelY += hexHeight * 0.5;

  return Offset(
    pixelX + centerOffset.dx + radius,
    pixelY + centerOffset.dy + (hexHeight / 2),
  );
}

(int, int) _pixelToHex(Offset pixel, double radius, Offset centerOffset) {
  final double hexHeight = sqrt(3) * radius;
  final px = pixel.dx - centerOffset.dx - radius;
  final py = pixel.dy - centerOffset.dy - (hexHeight / 2);

  int row = (py / hexHeight).floor();
  int col = ((px - (row.isOdd ? radius * 0.75 : 0)) / (radius * 1.5)).floor();

  return (row, col);
}
