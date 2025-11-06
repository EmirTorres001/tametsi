import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. IMPORTA TUS DEPENDENCIAS
import '../providers/game_provider.dart';
import '../models/cell_model.dart'; // Importa el modelo de celda
import 'cell_widget.dart'; // El widget para la celda cuadrada

// --- ¡NUEVO IMPORT! ---
// (Este archivo aún no existe, tu editor mostrará un error, ¡es normal!)
import 'hexagon_board_widget.dart';

class BoardWidget extends ConsumerWidget {
  // Asegúrate de que el constructor sea 'const'
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si el tablero aún no se ha inicializado, no muestres nada.
    final board = ref.watch(gameProvider.select((state) => state.board));
    if (board.isEmpty) {
      return const SizedBox.shrink();
    }

    // --- ¡MODIFICACIÓN CLAVE! ---
    // 1. Lee la topología actual del estado del juego
    final topology = ref.watch(gameProvider.select((state) => state.topology));

    // 2. Decide qué widget de tablero dibujar
    switch (topology) {
      case 'hexagon':
        // Devuelve el widget que sabe dibujar hexágonos (que crearemos a continuación)
        return const HexagonBoardWidget();

      case 'triangle':
        // Aún no lo hemos creado, así que mostramos un placeholder
        return const Center(
          child: Text(
            "Renderizador de Triángulos (próximamente)",
            style: TextStyle(color: Colors.grey),
          ),
        );

      case 'square':
      default:
        // Devuelve el GridView que ya tenías para los cuadrados
        return _buildSquareGrid(board);
    }
  }

  // --- ¡NUEVA FUNCIÓN! ---
  // Extraje tu lógica de GridView existente a una función privada
  // para mantener el método `build` limpio.
  Widget _buildSquareGrid(List<List<Cell>> board) {
    final int rowCount = board.length;
    final int colCount = board[0].length;

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
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: colCount,
              ),
              itemCount: rowCount * colCount,
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
