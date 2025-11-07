import 'dart:async';
import 'package:flutter/foundation.dart'; // Para `compute`
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cell_model.dart';
import '../models/level_model.dart';
import '../services/level_service.dart';

// --- Estados del Juego ---
enum GameStatus { playing, won, lost }

// --- Clase que representa el Estado del Juego ---
@immutable
class GameState {
  final List<List<Cell>> board;
  final GameStatus status;
  final int mineCount;
  final int flagCount;
  final Duration timer;
  final bool isLoading;
  final String topology; // <-- MODIFICADO: Añadido

  const GameState({
    required this.board,
    this.topology = 'square', // <-- MODIFICADO: Añadido
    this.status = GameStatus.playing,
    this.mineCount = 0,
    this.flagCount = 0,
    this.timer = Duration.zero,
    this.isLoading = true,
  });

  // Método `copyWith` para crear fácilmente un nuevo estado a partir del anterior.
  GameState copyWith({
    List<List<Cell>>? board,
    GameStatus? status,
    int? mineCount,
    int? flagCount,
    Duration? timer,
    bool? isLoading,
    String? topology, // <-- MODIFICADO: Añadido
  }) {
    return GameState(
      board: board ?? this.board,
      status: status ?? this.status,
      mineCount: mineCount ?? this.mineCount,
      flagCount: flagCount ?? this.flagCount,
      timer: timer ?? this.timer,
      isLoading: isLoading ?? this.isLoading,
      topology: topology ?? this.topology, // <-- MODIFICADO: Añadido
    );
  }
}

// --- El Notifier (El Cerebro) ---
class GameNotifier extends StateNotifier<GameState> {
  final LevelService _levelService = LevelService();
  Timer? _timer;

  GameNotifier() : super(const GameState(board: []));

  // Inicia un nuevo juego
  Future<void> newGame(String levelPath) async {
    _timer?.cancel();
    state = const GameState(board: [], isLoading: true); // Empieza a cargar

    final level = await _levelService.loadLevel(levelPath);

    // Usamos `compute` para procesar el tablero en un isolate separado,
    // evitando que la UI se congele en niveles grandes.
    final processedBoard = await compute(_createBoardFromLevel, level);

    state = GameState(
      board: processedBoard,
      mineCount: level.layout.join().split('M').length - 1,
      flagCount: 0,
      timer: Duration.zero,
      status: GameStatus.playing,
      isLoading: false, // Termina de cargar
      topology: level.topology, // <-- MODIFICADO: Se establece la topología
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == GameStatus.playing) {
        state = state.copyWith(
          timer: Duration(seconds: state.timer.inSeconds + 1),
        );
      } else {
        timer.cancel();
      }
    });
  }

  // Lógica para revelar una celda
  void revealCell(int x, int y) {
    if (state.status != GameStatus.playing ||
        state.board[x][y].state != CellState.hidden) {
      return;
    }

    final newBoard = _cloneBoard();
    final cell = newBoard[x][y];

    if (cell.isMine) {
      _revealAllMines(newBoard);
      state = state.copyWith(board: newBoard, status: GameStatus.lost);
      _timer?.cancel();
      return;
    }

    // <-- MODIFICADO: Pasa la topología a la función de revelado
    _revealEmptyCells(newBoard, x, y, state.topology);
    state = state.copyWith(board: newBoard);
    _checkWinCondition();
  }

  // Lógica para poner/quitar bandera
  void toggleFlag(int x, int y) {
    if (state.status != GameStatus.playing) return;

    final cell = state.board[x][y];
    if (cell.state == CellState.revealed) return;

    final newBoard = _cloneBoard();
    final newCell = newBoard[x][y];
    int newFlagCount = state.flagCount;

    if (newCell.state == CellState.hidden) {
      newCell.state = CellState.flagged;
      newFlagCount++;
    } else if (newCell.state == CellState.flagged) {
      newCell.state = CellState.hidden;
      newFlagCount--;
    }

    state = state.copyWith(board: newBoard, flagCount: newFlagCount);
    _checkWinCondition();
  }

  // --- Lógica Auxiliar ---

  void _checkWinCondition() {
    bool allMinesFlagged = true;
    bool allSafeRevealed = true;

    for (var row in state.board) {
      for (var cell in row) {
        if (cell.isBlocked) continue;
        if (cell.isMine && cell.state != CellState.flagged) {
          allMinesFlagged = false;
        }
        if (!cell.isMine && cell.state == CellState.hidden) {
          allSafeRevealed = false;
        }
      }
    }

    if (allMinesFlagged || allSafeRevealed) {
      state = state.copyWith(status: GameStatus.won);
      _timer?.cancel();
    }
  }

  // <-- MODIFICADO: Acepta topología
  void _revealEmptyCells(
    List<List<Cell>> board,
    int x,
    int y,
    String topology,
  ) {
    int rows = board.length;
    int cols = board[0].length;

    if (x < 0 || x >= rows || y < 0 || y >= cols) return;
    final cell = board[x][y];
    if (cell.state == CellState.revealed || cell.isBlocked) return;

    cell.state = CellState.revealed;

    if (cell.adjacentMines == 0) {
      // <-- MODIFICADO: Usa la nueva lógica de vecinos
      final neighbors = _getNeighbors(x, y, rows, cols, topology);
      for (final n in neighbors) {
        _revealEmptyCells(board, n[0], n[1], topology);
      }
    }
  }

  void _revealAllMines(List<List<Cell>> board) {
    for (var row in board) {
      for (var cell in row) {
        if (cell.isMine) {
          cell.state = CellState.mine;
        }
      }
    }
  }

  List<List<Cell>> _cloneBoard() {
    return state.board
        .map(
          (row) => row
              .map(
                (cell) => Cell(
                  x: cell.x,
                  y: cell.y,
                  isMine: cell.isMine,
                  isBlocked: cell.isBlocked,
                  state: cell.state,
                  adjacentMines: cell.adjacentMines,
                ),
              )
              .toList(),
        )
        .toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// --- Creación del Tablero (Función Pura para `compute`) ---
List<List<Cell>> _createBoardFromLevel(Level level) {
  int rows = level.rows;
  int cols = level.cols;
  var board = List.generate(
    rows,
    (x) => List.generate(cols, (y) => Cell(x: x, y: y)),
  );

  // Coloca minas y celdas bloqueadas
  for (int x = 0; x < rows; x++) {
    for (int y = 0; y < cols; y++) {
      final char = level.layout[x][y];
      if (char == '0') board[x][y].isBlocked = true;
      if (char == 'M') {
        board[x][y].isMine = true;
      }
    }
  }

  // Calcula las minas adyacentes para cada celda
  for (int x = 0; x < rows; x++) {
    for (int y = 0; y < cols; y++) {
      if (!board[x][y].isMine && !board[x][y].isBlocked) {
        // <-- MODIFICADO: Usa la nueva función de conteo
        board[x][y].adjacentMines = _countAdjacentMines(
          board,
          x,
          y,
          level.topology,
          rows,
          cols,
        );
      }
    }
  }
  return board;
}

// --- NUEVA FUNCIÓN: Obtiene una lista de coordenadas de vecinos [x, y] ---
// Usada por _revealEmptyCells y _countAdjacentMines
List<List<int>> _getNeighbors(
  int x,
  int y,
  int rows,
  int cols,
  String topology,
) {
  List<List<int>> neighbors = [];

  switch (topology) {
    case 'square':
      for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
          if (i == 0 && j == 0) continue;
          neighbors.add([x + i, y + j]);
        }
      }
      break;

    case 'hexagon':
      // --- ¡NUEVA LÓGICA DE VECINOS PARA "FLAT-TOP, ODD-R"! ---
      // (x=fila, y=columna)
      // "odd-r" significa que las filas impares (x=1, 3, 5...) están desplazadas

      bool isOddRow = x % 2 != 0;
      List<List<int>> directions;
      if (isOddRow) {
        // Vecinos de una fila impar (desplazada a la derecha)
        directions = [
          [0, -1], // O
          [0, 1], // E
          [-1, 0], // NO
          [-1, 1], // NE
          [1, 0], // SO
          [1, 1], // SE
        ];
      } else {
        // Vecinos de una fila par
        directions = [
          [0, -1], // O
          [0, 1], // E
          [-1, -1], // NO
          [-1, 0], // NE
          [1, -1], // SO
          [1, 0], // SE
        ];
      }
      for (final d in directions) {
        neighbors.add([x + d[0], y + d[1]]);
      }
      break;

    // (el case 'triangle' se queda igual)
    case 'triangle':
      bool isPointingUp = (x + y) % 2 == 0;
      List<List<int>> directions;
      if (isPointingUp) {
        directions = [
          [1, 0],
          [0, -1],
          [0, 1],
        ];
      } else {
        directions = [
          [-1, 0],
          [0, -1],
          [0, 1],
        ];
      }
      for (final d in directions) {
        neighbors.add([x + d[0], y + d[1]]);
      }
      break;
  }

  // Filtra los vecinos que están fuera del tablero
  return neighbors.where((n) {
    int nx = n[0];
    int ny = n[1];
    return nx >= 0 && nx < rows && ny >= 0 && ny < cols;
  }).toList();
}

// --- NUEVA FUNCIÓN: Cuenta las minas adyacentes según la topología ---
int _countAdjacentMines(
  List<List<Cell>> board,
  int x,
  int y,
  String topology,
  int rows,
  int cols,
) {
  int adjacentMines = 0;
  final neighbors = _getNeighbors(x, y, rows, cols, topology);

  for (final n in neighbors) {
    // No es necesario comprobar los límites aquí, _getNeighbors ya lo hizo
    if (board[n[0]][n[1]].isMine) {
      adjacentMines++;
    }
  }
  return adjacentMines;
}

// --- El Provider Principal ---
final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});
