import 'dart:async';
import 'package:flutter/foundation.dart'; // Para `compute`
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cell_model.dart';
import '../models/level_model.dart';
import '../services/level_service.dart';

// --- Estados del Juego ---
enum GameStatus { playing, won, lost }

// --- Clase que representa el Estado del Juego ---
// Es inmutable, cada cambio crea una nueva instancia.
@immutable
class GameState {
  final List<List<Cell>> board;
  final GameStatus status;
  final int mineCount;
  final int flagCount;
  final Duration timer;
  final bool isLoading;

  const GameState({
    required this.board,
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
  }) {
    return GameState(
      board: board ?? this.board,
      status: status ?? this.status,
      mineCount: mineCount ?? this.mineCount,
      flagCount: flagCount ?? this.flagCount,
      timer: timer ?? this.timer,
      isLoading: isLoading ?? this.isLoading,
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

    _revealEmptyCells(newBoard, x, y);
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
        if (cell.isMine && cell.state != CellState.flagged)
          allMinesFlagged = false;
        if (!cell.isMine && cell.state == CellState.hidden)
          allSafeRevealed = false;
      }
    }

    if (allMinesFlagged || allSafeRevealed) {
      state = state.copyWith(status: GameStatus.won);
      _timer?.cancel();
    }
  }

  void _revealEmptyCells(List<List<Cell>> board, int x, int y) {
    if (x < 0 || x >= board.length || y < 0 || y >= board[0].length) return;
    final cell = board[x][y];
    if (cell.state == CellState.revealed || cell.isBlocked) return;

    cell.state = CellState.revealed;

    if (cell.adjacentMines == 0) {
      for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
          if (i == 0 && j == 0) continue;
          _revealEmptyCells(board, x + i, y + j);
        }
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

  int totalMines = 0;
  for (int x = 0; x < rows; x++) {
    for (int y = 0; y < cols; y++) {
      final char = level.layout[x][y];
      if (char == '0') board[x][y].isBlocked = true;
      if (char == 'M') {
        board[x][y].isMine = true;
        totalMines++;
      }
    }
  }

  for (int x = 0; x < rows; x++) {
    for (int y = 0; y < cols; y++) {
      if (!board[x][y].isMine) {
        int adjacentMines = 0;
        for (int i = -1; i <= 1; i++) {
          for (int j = -1; j <= 1; j++) {
            if (i == 0 && j == 0) continue;
            int nx = x + i;
            int ny = y + j;
            if (nx >= 0 &&
                nx < rows &&
                ny >= 0 &&
                ny < cols &&
                board[nx][ny].isMine) {
              adjacentMines++;
            }
          }
        }
        board[x][y].adjacentMines = adjacentMines;
      }
    }
  }
  return board;
}

// --- El Provider Principal ---
final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});
