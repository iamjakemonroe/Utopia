import 'package:flutter/material.dart';

import '../../domain/chess_types.dart';

/// How one side's pieces are finished in a chess piece set: the gradient
/// the glyph is filled with, the rim light around it, and an optional glow.
class ChessPieceFinish {
  const ChessPieceFinish({
    required this.gradient,
    required this.rim,
    this.rimBlur = 2,
    this.glow,
    this.highlight = 0.7,
  });

  /// Top-left to bottom-right fill.
  final List<Color> gradient;
  final Color rim;
  final double rimBlur;
  final Color? glow;

  /// Strength of the specular dot near the top of the piece.
  final double highlight;
}

/// Character sets: pieces with faces that blink, look around and react to
/// the game (see ChessPieceArt). [none] is a plain, faceless set.
enum ChessCharacter { none, buddies, monsters, robots }

/// A purchasable chess piece set: a finish for each side, and for the
/// character sets, who the pieces are.
class ChessPieceStyle {
  const ChessPieceStyle({
    required this.white,
    required this.black,
    this.character = ChessCharacter.none,
  });

  final ChessPieceFinish white;
  final ChessPieceFinish black;
  final ChessCharacter character;

  ChessPieceFinish of(PieceColor color) =>
      color == PieceColor.white ? white : black;

  static ChessPieceStyle byId(String? id) => _styles[id] ?? _styles['classic']!;

  static const _styles = {
    'classic': ChessPieceStyle(
      white: ChessPieceFinish(
        gradient: [Color(0xFFFFFFFF), Color(0xFFF2ECDD), Color(0xFFD8C89A)],
        rim: Color(0x8C000000),
        rimBlur: 3,
        highlight: 0.8,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFF5B4A94), Color(0xFF2A2050), Color(0xFF15102E)],
        rim: Color(0xE6FFC94D),
        rimBlur: 1.5,
        highlight: 0.45,
      ),
    ),
    'chess_crystal': ChessPieceStyle(
      white: ChessPieceFinish(
        gradient: [Color(0xFFFFFFFF), Color(0xFFDDF6FF), Color(0xFF9ED8F5)],
        rim: Color(0xFF7FE3FF),
        rimBlur: 4,
        glow: Color(0x667FE3FF),
        highlight: 0.9,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFF9FD0F0), Color(0xFF2E5F8A), Color(0xFF12304F)],
        rim: Color(0xFFB8F1FF),
        rimBlur: 2.5,
        glow: Color(0x557FE3FF),
        highlight: 0.7,
      ),
    ),
    'chess_royal': ChessPieceStyle(
      white: ChessPieceFinish(
        gradient: [Color(0xFFFFF6CF), Color(0xFFFFD45E), Color(0xFFC9921E)],
        rim: Color(0xAA5A3A00),
        rimBlur: 3,
        glow: Color(0x44FFD45E),
        highlight: 0.9,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFF5A5A66), Color(0xFF22222C), Color(0xFF0A0A10)],
        rim: Color(0xFFFFD45E),
        rimBlur: 1.5,
        highlight: 0.5,
      ),
    ),
    'chess_neon': ChessPieceStyle(
      white: ChessPieceFinish(
        gradient: [Color(0xFFFFE3F6), Color(0xFFFF5FD2), Color(0xFFB4007E)],
        rim: Color(0xFFFF5FD2),
        rimBlur: 6,
        glow: Color(0x99FF5FD2),
        highlight: 0.6,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFFD9FFFF), Color(0xFF29E6FF), Color(0xFF0077A8)],
        rim: Color(0xFF29E6FF),
        rimBlur: 6,
        glow: Color(0x9929E6FF),
        highlight: 0.6,
      ),
    ),
    'chess_buddies': ChessPieceStyle(
      character: ChessCharacter.buddies,
      white: ChessPieceFinish(
        gradient: [Color(0xFFFFFFFF), Color(0xFFFFE3CC), Color(0xFFF2A97A)],
        rim: Color(0x99A0522D),
        rimBlur: 2.5,
        highlight: 0.95,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFFD9C8FF), Color(0xFF7B5CFF), Color(0xFF3F2596)],
        rim: Color(0xFFFFE29A),
        rimBlur: 2,
        highlight: 0.85,
      ),
    ),
    'chess_monsters': ChessPieceStyle(
      character: ChessCharacter.monsters,
      white: ChessPieceFinish(
        gradient: [Color(0xFFF2FFC2), Color(0xFFA6E34F), Color(0xFF4F9A1F)],
        rim: Color(0x99234D0A),
        rimBlur: 2.5,
        highlight: 0.8,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFFFFB8EC), Color(0xFFC04FE0), Color(0xFF5E1A8C)],
        rim: Color(0xFFFFD6F5),
        rimBlur: 2,
        highlight: 0.75,
      ),
    ),
    'chess_robots': ChessPieceStyle(
      character: ChessCharacter.robots,
      white: ChessPieceFinish(
        gradient: [Color(0xFFFFFFFF), Color(0xFFD3DCEA), Color(0xFF7F8DA6)],
        rim: Color(0x99323C52),
        rimBlur: 2.5,
        glow: Color(0x333DF5FF),
        highlight: 1,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFF9AA4B8), Color(0xFF3C4456), Color(0xFF151A26)],
        rim: Color(0xFF6FF0FF),
        rimBlur: 2,
        glow: Color(0x333DF5FF),
        highlight: 0.8,
      ),
    ),
    'chess_candy': ChessPieceStyle(
      white: ChessPieceFinish(
        gradient: [Color(0xFFFFFFFF), Color(0xFFFFC4E1), Color(0xFFFF8FC4)],
        rim: Color(0x99B0306E),
        rimBlur: 2.5,
        highlight: 0.9,
      ),
      black: ChessPieceFinish(
        gradient: [Color(0xFFE9FFF6), Color(0xFF7EF0C8), Color(0xFF2BB98B)],
        rim: Color(0x99146B4E),
        rimBlur: 2.5,
        highlight: 0.9,
      ),
    ),
  };
}
