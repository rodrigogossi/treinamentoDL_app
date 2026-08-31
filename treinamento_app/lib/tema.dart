/// Este arquivo define a identidade visual do app: cores, formas e o
/// [ThemeData] usado em todo o `MaterialApp`.
///
/// Por que uma paleta separada em vez de usar `Colors.deepPurple` padrão?
/// Este é um app de ENSINO, não um produto corporativo. Escolhemos uma
/// paleta lúdica (tons de roxo/violeta + verde-menta de destaque) para que,
/// durante a aula, a tela transmita "vamos brincar de ensinar uma IA a ler
/// placas" em vez de "aqui está um dashboard sério".
library;

import 'package:flutter/material.dart';

/// Paleta de cores central do app. Mantida em constantes nomeadas para que
/// qualquer widget possa referenciar `CoresApp.destaque`, por exemplo, sem
/// espalhar códigos de cor mágicos pelo código.
class CoresApp {
  CoresApp._();

  static const Color primaria = Color(0xFF6C4AB6); // roxo principal
  static const Color primariaClara = Color(0xFFB39DDB);
  static const Color destaque = Color(0xFF2EC4B6); // verde-menta (sucesso)
  static const Color alerta = Color(0xFFFF9F1C); // laranja (nenhuma placa)
  static const Color erro = Color(0xFFE63946);
  static const Color fundo = Color(0xFFF8F6FC);
  static const Color superficie = Colors.white;
  static const Color textoPrincipal = Color(0xFF2B2135);
}

/// Monta o [ThemeData] usado pelo `MaterialApp`.
ThemeData construirTemaApp() {
  final esquemaCores = ColorScheme.fromSeed(
    seedColor: CoresApp.primaria,
    primary: CoresApp.primaria,
    secondary: CoresApp.destaque,
    surface: CoresApp.superficie,
    error: CoresApp.erro,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquemaCores,
    scaffoldBackgroundColor: CoresApp.fundo,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: CoresApp.primaria,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CoresApp.primaria,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CoresApp.destaque
            : Colors.grey,
      ),
    ),
  );
}
