enum CellState { hidden, revealed, flagged, mine }

class Cell {
  final int x;
  final int y;
  bool isMine;
  bool isBlocked; // Para formas irregulares
  CellState state;
  int adjacentMines;

  Cell({
    required this.x,
    required this.y,
    this.isMine = false,
    this.isBlocked = false,
    this.state = CellState.hidden,
    this.adjacentMines = 0,
  });
}
