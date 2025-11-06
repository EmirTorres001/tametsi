import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Para íconos

import '../models/cell_model.dart';
import '../providers/game_provider.dart';

class CellWidget extends ConsumerWidget {
  final int x;
  final int y;

  const CellWidget({super.key, required this.x, required this.y});

  // Mapa de colores para los números
  static const Map<int, Color> numberColors = {
    1: Colors.blue,
    2: Colors.green,
    3: Colors.red,
    4: Colors.purple,
    5: Colors.brown,
    6: Colors.cyan,
    7: Colors.black,
    8: Colors.grey,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cell = ref.watch(gameProvider.select((state) => state.board[x][y]));

    // Si la celda está bloqueada la hacemos transparente
    if (cell.isBlocked) {
      return const SizedBox.shrink();
    }

    final gameNotifier = ref.read(gameProvider.notifier);

    return GestureDetector(
      onTap: () => gameNotifier.revealCell(x, y),
      onLongPress: () => gameNotifier.toggleFlag(x, y),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Container(
          // actualizar animaciones
          key: ValueKey(cell.state),
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: _getCellBackgroundColor(context, cell),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Center(child: _buildCellContent(cell)),
        ),
      ),
    );
  }

  // colores celdas
  Color _getCellBackgroundColor(BuildContext context, Cell cell) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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

  // Lógica para determinar qué mostrar dentro de la celda
  Widget? _buildCellContent(Cell cell) {
    switch (cell.state) {
      case CellState.flagged:
        return const FaIcon(
          FontAwesomeIcons.flag,
          color: Colors.white,
          size: 16,
        );
      case CellState.mine:
        return const FaIcon(
          FontAwesomeIcons.bomb,
          color: Colors.white,
          size: 16,
        );
      case CellState.revealed:
        if (cell.isMine) {
          // Si es una mina revelada al perder
          return const FaIcon(
            FontAwesomeIcons.bomb,
            color: Colors.black,
            size: 16,
          );
        }
        if (cell.adjacentMines > 0) {
          return Text(
            '${cell.adjacentMines}',
            style: TextStyle(
              color: numberColors[cell.adjacentMines],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          );
        }
        return null; // Celda vacía revelada
      case CellState.hidden:
        return null; // Celda oculta, sin contenido
    }
  }
}
