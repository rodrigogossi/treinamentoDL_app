/// Este arquivo concentra toda a manipulação "crua" de pixels usada pelo
/// pipeline de detecção: redimensionar a foto para o formato que o modelo
/// espera (letterbox), converter pixels em tensores de entrada, converter
/// caixas do espaço do modelo de volta para o espaço da foto original, e
/// desenhar/recortar regiões da imagem.
///
/// Isolamos essas funções aqui (em vez de espalhar pelo `detector_yolo.dart`)
/// porque são o tipo de código que os alunos vão querer "abrir e ler linha a
/// linha" durante a aula — cada função faz UMA coisa e é comentada como se
/// fosse um mini-tutorial de processamento de imagem.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

/// Guarda o resultado de aplicar "letterbox" em uma imagem: a imagem
/// redimensionada e centralizada em um canvas quadrado, mais os parâmetros
/// necessários para desfazer essa transformação depois (ver
/// [converterCaixaParaImagemOriginal]).
///
/// O QUE É LETTERBOX? É a técnica clássica do YOLO para redimensionar uma
/// foto retangular (ex: 1920x1080) para um quadrado (ex: 640x640) SEM
/// distorcer a imagem: ela é encolhida mantendo a proporção original e
/// "sobra" de espaço é preenchida com uma cor neutra (cinza), como as barras
/// pretas de um filme widescreen na TV.
class ImagemLetterboxed {
  const ImagemLetterboxed({
    required this.imagem,
    required this.escala,
    required this.deslocamentoX,
    required this.deslocamentoY,
    required this.larguraOriginal,
    required this.alturaOriginal,
  });

  /// A imagem final, quadrada (tamanhoAlvo x tamanhoAlvo), pronta para virar
  /// tensor de entrada do modelo.
  final img.Image imagem;

  /// Fator de escala aplicado à imagem original (mesmo valor para largura e
  /// altura, já que preservamos a proporção).
  final double escala;

  /// Quantos pixels de preenchimento (cinza) foram adicionados nas laterais
  /// esquerda/direita.
  final double deslocamentoX;

  /// Quantos pixels de preenchimento (cinza) foram adicionados em cima/baixo.
  final double deslocamentoY;

  final int larguraOriginal;
  final int alturaOriginal;
}

/// Redimensiona [original] para um quadrado [tamanhoAlvo] x [tamanhoAlvo]
/// usando letterbox (proporção preservada + preenchimento cinza 114,114,114
/// — a mesma cor de padding usada pelo Ultralytics no treino, para que o
/// modelo veja durante a inferência exatamente o tipo de imagem que viu
/// durante o treino).
ImagemLetterboxed aplicarLetterbox(img.Image original, int tamanhoAlvo) {
  final larguraOriginal = original.width;
  final alturaOriginal = original.height;

  // A escala é o MENOR fator entre largura e altura, para garantir que a
  // imagem inteira caiba no quadrado sem cortar nada.
  final escala = math.min(
    tamanhoAlvo / larguraOriginal,
    tamanhoAlvo / alturaOriginal,
  );

  final novaLargura = (larguraOriginal * escala).round();
  final novaAltura = (alturaOriginal * escala).round();

  final redimensionada = img.copyResize(
    original,
    width: novaLargura,
    height: novaAltura,
    interpolation: img.Interpolation.linear,
  );

  // Centraliza a imagem redimensionada dentro do quadrado, distribuindo o
  // preenchimento igualmente nos dois lados.
  final deslocamentoX = (tamanhoAlvo - novaLargura) / 2.0;
  final deslocamentoY = (tamanhoAlvo - novaAltura) / 2.0;

  final tela = img.Image(width: tamanhoAlvo, height: tamanhoAlvo);
  img.fill(tela, color: img.ColorRgb8(114, 114, 114));
  img.compositeImage(
    tela,
    redimensionada,
    dstX: deslocamentoX.round(),
    dstY: deslocamentoY.round(),
  );

  return ImagemLetterboxed(
    imagem: tela,
    escala: escala,
    deslocamentoX: deslocamentoX,
    deslocamentoY: deslocamentoY,
    larguraOriginal: larguraOriginal,
    alturaOriginal: alturaOriginal,
  );
}

/// Converte a imagem já "letterboxed" em um tensor de entrada no formato que
/// o modelo carregado realmente espera, com cada pixel normalizado de
/// [0,255] para [0.0, 1.0].
///
/// Por que normalizar? O modelo foi TREINADO com pixels normalizados nesse
/// intervalo (é o padrão do Ultralytics/YOLO). Se enviarmos valores de 0 a
/// 255 sem normalizar, a rede neural recebe números fora da escala que ela
/// aprendeu a interpretar, e a detecção sai completamente errada.
///
/// ATENÇÃO — "NHWC vs NCHW" (a pegadinha que mais vale explicar em aula):
/// Exportações TFLite "clássicas" (via TensorFlow) usam a ordem de eixos
/// NHWC: [batch, altura, largura, canais] — ex: [1, 640, 640, 3]. Já
/// exportações mais recentes do Ultralytics (via o conversor LiteRT-Torch)
/// preservam a ordem NATIVA do PyTorch, NCHW: [batch, canais, altura,
/// largura] — ex: [1, 3, 640, 640]. São o MESMO modelo, mas o tensor de
/// entrada precisa ser montado de um jeito diferente para cada caso — se
/// você montar no formato errado, a inferência roda sem erro nenhum, mas
/// devolve resultados sem sentido (porque os números caem nas posições
/// erradas do tensor). Por isso [formaEntrada] vem do próprio interpretador
/// carregado (`interpreter.getInputTensor(0).shape`), em vez de assumirmos
/// um formato fixo: assim o código se adapta automaticamente a qualquer uma
/// das duas convenções.
List construirTensorEntrada(img.Image imagem, List<int> formaEntrada) {
  final altura = imagem.height;
  final largura = imagem.width;

  final canaisPorUltimo = formaEntrada.length == 4 && formaEntrada[3] == 3;

  if (canaisPorUltimo) {
    // NHWC: [1, altura, largura, 3]
    return List.generate(
      1,
      (_) => List.generate(
        altura,
        (y) => List.generate(largura, (x) {
          final pixel = imagem.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );
  }

  // NCHW: [1, 3, altura, largura] — um "plano" inteiro por canal de cor.
  return List.generate(
    1,
    (_) => List.generate(3, (canal) {
      return List.generate(altura, (y) {
        return List.generate(largura, (x) {
          final pixel = imagem.getPixel(x, y);
          final valorBruto = switch (canal) {
            0 => pixel.r,
            1 => pixel.g,
            _ => pixel.b,
          };
          return valorBruto / 255.0;
        });
      });
    }),
  );
}

/// Desfaz a transformação de letterbox em uma caixa delimitadora: recebe uma
/// caixa em coordenadas do espaço do MODELO (0 a tamanhoAlvo, ex: 0-640) e
/// devolve a caixa equivalente em coordenadas de pixel da imagem ORIGINAL.
///
/// É basicamente [aplicarLetterbox] rodado ao contrário: primeiro remove o
/// deslocamento (padding) que foi somado, depois divide pela escala que foi
/// multiplicada. Sem esse passo, a caixa desenhada ficaria deslocada e com
/// tamanho errado sempre que a foto não for exatamente quadrada (ou seja,
/// quase sempre).
Rect converterCaixaParaImagemOriginal(Rect caixaModelo, ImagemLetterboxed info) {
  final x1 = (caixaModelo.left - info.deslocamentoX) / info.escala;
  final y1 = (caixaModelo.top - info.deslocamentoY) / info.escala;
  final x2 = (caixaModelo.right - info.deslocamentoX) / info.escala;
  final y2 = (caixaModelo.bottom - info.deslocamentoY) / info.escala;

  // Garante que a caixa não "vaze" para fora dos limites da foto original
  // (pode acontecer por pequenos erros de arredondamento nas bordas).
  return Rect.fromLTRB(
    x1.clamp(0, info.larguraOriginal.toDouble()),
    y1.clamp(0, info.alturaOriginal.toDouble()),
    x2.clamp(0, info.larguraOriginal.toDouble()),
    y2.clamp(0, info.alturaOriginal.toDouble()),
  );
}

/// Desenha um retângulo colorido sobre uma cópia da imagem original,
/// representando a "Etapa 2" do pipeline didático (imagem com a caixa
/// detectada). Devolve os bytes já codificados em PNG.
Uint8List desenharCaixaNaImagem(
  Uint8List bytesOriginais,
  Rect caixa, {
  img.Color? cor,
}) {
  final imagem = img.decodeImage(bytesOriginais)!;
  final corLinha = cor ?? img.ColorRgb8(46, 196, 182); // verde-menta do tema

  img.drawRect(
    imagem,
    x1: caixa.left.round(),
    y1: caixa.top.round(),
    x2: caixa.right.round(),
    y2: caixa.bottom.round(),
    color: corLinha,
    thickness: math.max(3, (imagem.width * 0.006).round()),
  );

  return Uint8List.fromList(img.encodePng(imagem));
}

/// Recorta a região da placa a partir da imagem original, aplicando uma
/// pequena margem extra ao redor da caixa detectada.
///
/// Por que adicionar margem? O YOLO às vezes desenha a caixa "coladinha" nos
/// caracteres da placa. Se recortarmos exatamente na borda da caixa, corremos
/// o risco de cortar a lateral de uma letra — o que prejudica o OCR na etapa
/// seguinte. Uma margem de ~8% para cada lado dá uma folga sem incluir tanto
/// fundo a ponto de atrapalhar o reconhecimento de texto.
Uint8List recortarRegiao(
  Uint8List bytesOriginais,
  Rect caixa, {
  double margemRelativa = 0.08,
}) {
  final imagem = img.decodeImage(bytesOriginais)!;

  final margemX = caixa.width * margemRelativa;
  final margemY = caixa.height * margemRelativa;

  final x1 = (caixa.left - margemX).clamp(0, imagem.width.toDouble());
  final y1 = (caixa.top - margemY).clamp(0, imagem.height.toDouble());
  final x2 = (caixa.right + margemX).clamp(0, imagem.width.toDouble());
  final y2 = (caixa.bottom + margemY).clamp(0, imagem.height.toDouble());

  final recorte = img.copyCrop(
    imagem,
    x: x1.round(),
    y: y1.round(),
    width: math.max(1, (x2 - x1).round()),
    height: math.max(1, (y2 - y1).round()),
  );

  return Uint8List.fromList(img.encodePng(recorte));
}
