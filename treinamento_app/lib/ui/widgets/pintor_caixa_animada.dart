/// Este widget desenha a caixa delimitadora da placa com uma animação de
/// "traçado" — a borda vai sendo desenhada progressivamente, como se alguém
/// estivesse contornando a placa com uma caneta. É puramente estético: o
/// objetivo é dar um momento visual de "a IA encontrou algo" na hora certa
/// da aula, reforçando que aquela caixa é o resultado ativo da detecção, e
/// não apenas uma imagem estática.
library;

import 'package:flutter/material.dart';

import '../../tema.dart';

class CaixaDetectadaAnimada extends StatefulWidget {
  const CaixaDetectadaAnimada({super.key, required this.retanguloFracional});

  /// Retângulo da caixa em coordenadas FRACIONÁRIAS (0.0 a 1.0), relativas
  /// ao tamanho do widget pai. Usar frações (em vez de pixels absolutos)
  /// permite que a caixa acompanhe corretamente a imagem mesmo quando ela é
  /// redimensionada para caber na tela.
  final Rect retanguloFracional;

  @override
  State<CaixaDetectadaAnimada> createState() => _CaixaDetectadaAnimadaState();
}

class _CaixaDetectadaAnimadaState extends State<CaixaDetectadaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _progresso;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progresso = CurvedAnimation(
      parent: _controlador,
      curve: Curves.easeOutCubic,
    );
    _controlador.forward();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progresso,
      builder: (context, _) {
        return CustomPaint(
          painter: _PintorCaixa(widget.retanguloFracional, _progresso.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PintorCaixa extends CustomPainter {
  _PintorCaixa(this.retanguloFracional, this.progresso);

  final Rect retanguloFracional;
  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    final retangulo = Rect.fromLTRB(
      retanguloFracional.left * size.width,
      retanguloFracional.top * size.height,
      retanguloFracional.right * size.width,
      retanguloFracional.bottom * size.height,
    );

    final pincel = Paint()
      ..color = CoresApp.destaque
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // `computeMetrics` nos dá o comprimento total do contorno do retângulo;
    // `extractPath` recorta só uma fração inicial dele — é isso que cria o
    // efeito de "desenhando aos poucos" conforme `progresso` vai de 0 a 1.
    final caminhoCompleto = Path()..addRect(retangulo);
    final metrica = caminhoCompleto.computeMetrics().first;
    final trechoAnimado = metrica.extractPath(0, metrica.length * progresso);

    canvas.drawPath(trechoAnimado, pincel);
  }

  @override
  bool shouldRepaint(covariant _PintorCaixa oldDelegate) {
    return oldDelegate.progresso != progresso ||
        oldDelegate.retanguloFracional != retanguloFracional;
  }
}
