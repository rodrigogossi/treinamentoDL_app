/// Este arquivo é responsável por decodificar a saída BRUTA do modelo YOLO
/// em caixas delimitadoras utilizáveis.
///
/// ================================================================
///  POR QUE ESTA É A PARTE MAIS "MÁGICA" DO PIPELINE
/// ================================================================
/// O modelo não devolve "aqui está a placa". Ele devolve um monte de
/// números: para uma imagem de entrada 640x640, o YOLOv8n gera 8400
/// "candidatos" a caixa (uma grade de possíveis detecções em 3 escalas
/// diferentes: 80x80 + 40x40 + 20x20 = 8400 pontos). Para CADA um desses
/// 8400 candidatos, o modelo devolve 5 números (porque treinamos 1 classe
/// só: "placa"):
///
///   [centro_x, centro_y, largura, altura, confiança]
///
/// A esmagadora maioria desses 8400 candidatos não é nada — são "ruído" que
/// o modelo aprendeu a atribuir baixíssima confiança. O trabalho deste
/// arquivo é:
///
///   1. Descartar os candidatos com confiança baixa (provavelmente não são
///      placas de verdade).
///   2. Dos candidatos que sobraram, muitos vão se sobrepor — o modelo às
///      vezes "vota" na mesma placa com várias caixas ligeiramente
///      diferentes. Usamos NMS (Non-Maximum Suppression) para manter só a
///      melhor caixa de cada objeto e descartar as duplicatas.
///
/// Sem esse pós-processamento, o modelo pareceria "não funcionar" — na
/// verdade ele está funcionando perfeitamente, só que devolvendo dados em um
/// formato bruto demais para usar diretamente.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../modelos/deteccao.dart';

/// Decodifica as linhas brutas de saída do modelo em uma lista de
/// [Deteccao], já filtradas por confiança e sem duplicatas (após NMS).
///
/// [linhas] deve ser uma lista onde cada elemento é `[cx, cy, w, h, confiança]`
/// no espaço de coordenadas do MODELO (pixels de 0 a `tamanhoEntrada`, ex:
/// 0-640) — NÃO no espaço da foto original. A conversão para o espaço da
/// foto original acontece depois, em
/// `utilitarios_imagem.converterCaixaParaImagemOriginal`.
///
/// [limiarConfianca]: abaixo desse valor, o candidato é descartado antes
/// mesmo de entrar na disputa do NMS. Usamos 0.4 como padrão — valor típico
/// para modelos YOLO em cenários de demonstração: alto o suficiente para
/// evitar caixas "fantasma" em fundos que lembram uma placa (ex: uma faixa
/// retangular clara no chão), mas baixo o suficiente para não perder
/// detecções em fotos com ângulo ou iluminação não ideais — que é exatamente
/// o tipo de foto tirada ao vivo, na hora, durante uma aula.
///
/// [limiarIoU]: o quanto duas caixas podem se sobrepor (Intersection over
/// Union) antes de serem consideradas "a mesma placa". 0.45 é o padrão usado
/// pelo próprio Ultralytics — funciona bem porque placas veiculares raramente
/// aparecem coladas umas nas outras na mesma foto, então um limiar
/// relativamente permissivo não corre o risco de fundir duas placas
/// diferentes em uma só.
List<Deteccao> decodificarSaidaYolo(
  List<List<double>> linhas, {
  double limiarConfianca = 0.4,
  double limiarIoU = 0.45,
}) {
  // -----------------------------------------------------------------
  // PASSO 1: converter cada linha (cx, cy, w, h, confiança) em uma
  // [Deteccao], já descartando quem tem confiança baixa.
  // -----------------------------------------------------------------
  final candidatas = <Deteccao>[];
  for (final linha in linhas) {
    final confianca = linha[4];
    if (confianca < limiarConfianca) continue;

    final cx = linha[0];
    final cy = linha[1];
    final largura = linha[2];
    final altura = linha[3];

    // O modelo trabalha com "centro + tamanho" (cx, cy, w, h), mas é mais
    // fácil calcular sobreposição de área usando "canto superior esquerdo +
    // canto inferior direito" — por isso convertemos aqui.
    final caixa = Rect.fromLTWH(
      cx - largura / 2,
      cy - altura / 2,
      largura,
      altura,
    );

    candidatas.add(Deteccao(caixa: caixa, confianca: confianca));
  }

  // -----------------------------------------------------------------
  // PASSO 2: ordenar por confiança, da maior para a menor. O NMS abaixo
  // depende dessa ordem: sempre aceitamos primeiro o candidato mais
  // confiante entre os que sobrarem.
  // -----------------------------------------------------------------
  candidatas.sort((a, b) => b.confianca.compareTo(a.confianca));

  // -----------------------------------------------------------------
  // PASSO 3: Non-Maximum Suppression (NMS) guloso.
  //
  // A ideia é simples: percorremos as candidatas da mais confiante para a
  // menos confiante. Para cada uma, verificamos se ela se sobrepõe demais
  // (IoU acima do limiar) com alguma caixa que JÁ aceitamos antes. Se sim,
  // ela é descartada por ser considerada "a mesma placa, de novo". Se não,
  // ela é aceita como uma nova detecção.
  // -----------------------------------------------------------------
  final selecionadas = <Deteccao>[];
  for (final candidata in candidatas) {
    final sobrepoeAlgumaJaAceita = selecionadas.any(
      (aceita) => _calcularIoU(candidata.caixa, aceita.caixa) > limiarIoU,
    );

    if (!sobrepoeAlgumaJaAceita) {
      selecionadas.add(candidata);
    }
  }

  return selecionadas;
}

/// Calcula a Intersecção sobre União (IoU) entre duas caixas — a métrica
/// padrão para medir "o quanto duas caixas se sobrepõem", de 0.0 (nenhuma
/// sobreposição) a 1.0 (caixas idênticas).
///
///   IoU = área da interseção / área da união
double _calcularIoU(Rect a, Rect b) {
  final esquerda = math.max(a.left, b.left);
  final topo = math.max(a.top, b.top);
  final direita = math.min(a.right, b.right);
  final base = math.min(a.bottom, b.bottom);

  final larguraInterseccao = math.max(0.0, direita - esquerda);
  final alturaInterseccao = math.max(0.0, base - topo);
  final areaInterseccao = larguraInterseccao * alturaInterseccao;

  final areaA = a.width * a.height;
  final areaB = b.width * b.height;
  final areaUniao = areaA + areaB - areaInterseccao;

  if (areaUniao <= 0) return 0.0;
  return areaInterseccao / areaUniao;
}
