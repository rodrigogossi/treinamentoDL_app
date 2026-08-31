/// Ponto de entrada do app. Aqui montamos a árvore de widgets raiz,
/// registramos o [EstadoApp] via `provider` (disponível para todas as
/// telas) e disparamos o carregamento do modelo YOLOv8n assim que o app
/// sobe.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'estado_app.dart';
import 'tema.dart';
import 'ui/tela_inicial.dart';

void main() {
  runApp(const AppTreinamentoAlpr());
}

class AppTreinamentoAlpr extends StatelessWidget {
  const AppTreinamentoAlpr({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EstadoApp()..inicializar(),
      child: MaterialApp(
        title: 'Leitor de Placas com IA',
        debugShowCheckedModeBanner: false,
        theme: construirTemaApp(),
        home: const TelaInicial(),
      ),
    );
  }
}
