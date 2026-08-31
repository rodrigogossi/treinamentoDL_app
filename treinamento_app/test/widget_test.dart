// Teste de fumaça simples: garante que a tela inicial (storytelling) sobe
// sem erros e mostra o botão para iniciar o fluxo de captura.
//
// Não testamos o pipeline de ALPR aqui de propósito: ele depende de câmera
// física e do modelo TFLite, que não estão disponíveis no ambiente de teste
// headless. Testes de pipeline completo devem ser feitos manualmente em um
// dispositivo/emulador real (ver README.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:treinamento_app/ui/tela_inicial.dart';

void main() {
  testWidgets('Tela inicial mostra o título e o botão de começar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TelaInicial()),
    );

    expect(find.text('Leitor de Placas com IA'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });
}
