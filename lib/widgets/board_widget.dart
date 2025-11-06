import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. IMPORTA TUS DEPENDENCIAS
import '../providers/game_provider.dart'; // Para leer el estado del tablero
import 'cell_widget.dart'; // El widget para cada celda individual

class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa el estado del juego para obtener las dimensiones del tablero
    final gameState = ref.watch(gameProvider);
    final board = gameState.board;

    // Si el tablero aún no se ha inicializado, muestra un contenedor vacío.
    if (board.isEmpty) {
      return const SizedBox.shrink();
    }

    final int rowCount = board.length;
    final int colCount = board[0].length;

    // Usamos un LayoutBuilder para que el tablero se ajuste al espacio disponible
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula el tamaño óptimo de la celda para que quepa en la pantalla
        final double maxCellWidth = constraints.maxWidth / colCount;
        final double maxCellHeight = constraints.maxHeight / rowCount;
        // Usa el menor de los dos para mantener la proporción
        final double cellSize = maxCellWidth < maxCellHeight
            ? maxCellWidth
            : maxCellHeight;

        return Center(
          child: SizedBox(
            width: cellSize * colCount,
            height: cellSize * rowCount,
            child: GridView.builder(
              // Deshabilita el scroll, ya que el tamaño se ajusta
              physics: const NeverScrollableScrollPhysics(),
              // Define la estructura de la cuadrícula
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: colCount,
              ),
              // El número total de celdas
              itemCount: rowCount * colCount,
              // La función que construye cada celda
              itemBuilder: (context, index) {
                final int x = index ~/ colCount; // Calcula la fila (x)
                final int y = index % colCount; // Calcula la columna (y)

                // Devuelve una instancia de CellWidget para estas coordenadas
                return CellWidget(x: x, y: y);
              },
            ),
          ),
        );
      },
    );
  }
}
