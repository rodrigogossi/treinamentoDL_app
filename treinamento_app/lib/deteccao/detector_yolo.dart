/// Este arquivo é responsável por carregar o modelo YOLOv8n exportado em
/// TFLite e rodar a inferência sobre uma imagem, devolvendo uma lista de
/// [Deteccao] já em coordenadas da imagem original.
///
/// Ele é a "cola" entre três peças:
///   1. `utilitarios_imagem.dart`  -> prepara a imagem de entrada (letterbox)
///      e converte as caixas de volta para o espaço da foto original.
///   2. `tflite_flutter`           -> roda a rede neural propriamente dita.
///   3. `pos_processamento_yolo.dart` -> transforma a saída bruta em caixas.
///
/// POR QUE TFLITE E NÃO ONNX?
/// O TFLite tem um runtime nativo mobile mantido pelo Google (LiteRT),
/// com binding Dart oficial via `tflite_flutter` e execução eficiente em
/// CPU/GPU/NNAPI no Android sem depender de bibliotecas C++ extras que
/// precisariam ser compiladas manualmente para cada plataforma — o que seria
/// complicado demais para um app de demonstração didática. ONNX Runtime
/// também funciona em Flutter, mas exige mais configuração nativa por
/// plataforma e tem uma comunidade Flutter bem menor; para o nosso caso de
/// uso (modelo pequeno, 1 classe, foco didático), TFLite é o caminho de
/// menor atrito.
library;

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../modelos/deteccao.dart';
import 'pos_processamento_yolo.dart';
import 'utilitarios_imagem.dart';

/// Envolve o [Interpreter] do `tflite_flutter` e expõe uma API simples:
/// `carregar()` uma vez, depois `detectar(imagem)` quantas vezes precisar.
class DetectorYolo {
  DetectorYolo({
    this.tamanhoEntrada = 640,
    this.limiarConfianca = 0.4,
    this.limiarIoU = 0.45,
  });

  /// Resolução (largura = altura) esperada pelo modelo. Precisa bater com o
  /// `imgsz` usado na exportação (`model.export(format="tflite", imgsz=640)`).
  final int tamanhoEntrada;

  /// Confiança mínima para considerar um candidato como "placa real".
  /// Ver explicação detalhada em `pos_processamento_yolo.dart`.
  final double limiarConfianca;

  /// Limiar de sobreposição (IoU) usado no NMS.
  /// Ver explicação detalhada em `pos_processamento_yolo.dart`.
  final double limiarIoU;

  Interpreter? _interpreter;

  /// Quantidade de classes que o modelo prevê. Nosso treino usou apenas 1
  /// classe ("placa"), mas mantemos como campo para deixar claro de onde
  /// vem o número de canais da saída (4 coordenadas + numeroClasses).
  static const int _numeroClasses = 1;

  bool get carregado => _interpreter != null;

  /// Carrega o arquivo `.tflite` empacotado nos assets do app. Deve ser
  /// chamado uma única vez (ex: na inicialização do `EstadoApp`).
  Future<void> carregar() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/best_float32.tflite',
    );
  }

  /// Roda o pipeline de detecção completo sobre [imagemOriginal] (já
  /// decodificada pelo pacote `image`) e devolve as detecções encontradas,
  /// já em coordenadas de pixel da imagem original (não do modelo).
  Future<List<Deteccao>> detectar(img.Image imagemOriginal) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError(
        'DetectorYolo.carregar() precisa ser chamado antes de detectar().',
      );
    }

    // 1) Prepara a entrada: redimensiona com letterbox e monta o tensor
    //    normalizado que a rede neural espera, na ORDEM DE EIXOS que o
    //    modelo carregado realmente usa (ver comentário de
    //    `construirTensorEntrada` sobre NHWC vs NCHW).
    final infoLetterbox = aplicarLetterbox(imagemOriginal, tamanhoEntrada);
    final formaEntrada = interpreter.getInputTensor(0).shape;
    final tensorEntrada = construirTensorEntrada(
      infoLetterbox.imagem,
      formaEntrada,
    );

    // 2) Descobre a forma real da saída do modelo carregado (em vez de
    //    "chutar" [1,5,8400] fixo) — assim, se você treinar com mais
    //    classes no futuro, o código se adapta sozinho.
    final formaSaida = interpreter.getOutputTensor(0).shape;
    final bufferSaida = _criarBufferSaida(formaSaida);

    // 3) Roda a inferência. Esta é a única linha que efetivamente "usa a
    //    IA" — tudo antes e depois é preparação/interpretação dos dados.
    interpreter.run(tensorEntrada, bufferSaida);

    // 4) Normaliza a saída bruta para uma lista de linhas
    //    [cx, cy, w, h, confiança] e delega a decodificação real
    //    (filtro de confiança + NMS) para `pos_processamento_yolo.dart`.
    final linhas = _extrairLinhas(bufferSaida, formaSaida);
    final deteccoesNoEspacoDoModelo = decodificarSaidaYolo(
      linhas,
      limiarConfianca: limiarConfianca,
      limiarIoU: limiarIoU,
    );

    // 5) Converte as caixas do espaço do modelo (0-640) para o espaço da
    //    foto original, desfazendo o letterbox do passo 1.
    return deteccoesNoEspacoDoModelo
        .map(
          (d) => Deteccao(
            caixa: converterCaixaParaImagemOriginal(d.caixa, infoLetterbox),
            confianca: d.confianca,
          ),
        )
        .toList();
  }

  /// Cria uma lista aninhada preenchida com zeros, na mesma forma
  /// tridimensional `[batch, dimensãoA, dimensãoB]` da saída do modelo, para
  /// o `tflite_flutter` escrever o resultado da inferência dentro dela.
  List _criarBufferSaida(List<int> forma) {
    if (forma.length != 3) {
      throw StateError(
        'Forma de saída inesperada: $forma. Este código espera uma saída '
        '3D típica do YOLOv8 exportado (ex: [1, 5, 8400]). Abra o arquivo '
        '.tflite no Netron (https://netron.app) para inspecionar a forma '
        'real e ajustar `_extrairLinhas` se necessário.',
      );
    }
    return List.generate(
      forma[0],
      (_) => List.generate(forma[1], (_) => List.filled(forma[2], 0.0)),
    );
  }

  /// Transforma o buffer de saída bruto (cuja orientação de eixos pode
  /// variar conforme a versão da exportação) em uma lista uniforme de
  /// linhas `[cx, cy, w, h, confiança]`, uma por candidato a caixa.
  ///
  /// DETALHE TÉCNICO IMPORTANTE (o motivo de este método existir):
  /// A exportação padrão do Ultralytics para TFLite mantém a saída no
  /// formato "canais primeiro": [1, 4+numeroClasses, numeroCaixas], ou seja,
  /// [1, 5, 8400] no nosso caso — 5 "linhas" (cx, cy, w, h, confiança), cada
  /// uma com 8400 valores (um por candidato). Isso é o OPOSTO do que seria
  /// mais intuitivo (8400 candidatos, cada um com 5 valores). Por isso
  /// primeiro detectamos qual dimensão é a dos "canais" (tamanho igual a
  /// 4+numeroClasses) e, se for a dimensão 1 (o caso comum), fazemos a
  /// transposição manualmente.
  List<List<double>> _extrairLinhas(List bufferSaida, List<int> forma) {
    final dimensao1 = forma[1];
    final dimensao2 = forma[2];
    final numeroCanais = 4 + _numeroClasses;

    final saidaSemBatch = bufferSaida[0] as List;

    final canaisNaDimensao1 = dimensao1 == numeroCanais;

    List<List<double>> linhas;
    if (canaisNaDimensao1) {
      // Formato [canais, numeroCaixas] -> precisa transpor.
      final numeroCaixas = dimensao2;
      linhas = List.generate(numeroCaixas, (i) {
        return List.generate(
          numeroCanais,
          (canal) => (saidaSemBatch[canal][i] as num).toDouble(),
        );
      });
    } else {
      // Formato já é [numeroCaixas, canais] -> usa direto.
      linhas = saidaSemBatch
          .map<List<double>>(
            (linha) =>
                (linha as List).map((v) => (v as num).toDouble()).toList(),
          )
          .toList();
    }

    // As coordenadas (cx, cy, w, h) podem vir normalizadas entre 0.0 e 1.0
    // (relativas ao tamanho de entrada) ou já em pixels de 0 a
    // `tamanhoEntrada`, dependendo da versão exata da exportação. Detectamos
    // isso olhando se os valores são pequenos (<=1.5) e, se forem,
    // multiplicamos pelo tamanho de entrada para converter para pixels —
    // é essencial verificar esse detalhe ao trocar de versão do
    // Ultralytics, por isso deixamos essa checagem explícita em vez de
    // assumir um formato fixo.
    final pareceNormalizado =
        linhas.isNotEmpty && linhas.first.take(4).every((v) => v <= 1.5);
    if (pareceNormalizado) {
      for (final linha in linhas) {
        for (var i = 0; i < 4; i++) {
          linha[i] = linha[i] * tamanhoEntrada;
        }
      }
    }

    return linhas;
  }

  /// Libera os recursos nativos do interpretador. Chame ao encerrar o app
  /// (ou quando o `EstadoApp` for descartado).
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
