/// Este arquivo define [ResultadoLeitura], a estrutura que agrega TODAS as
/// etapas do pipeline de ALPR para uma única foto processada.
///
/// É o objeto que:
/// 1. Alimenta o "Modo Explicação" (cada campo abaixo corresponde a uma das
///    etapas mostradas lado a lado na tela de resultado).
/// 2. É guardado na lista de histórico em memória (`estado_app.dart`).
library;

import 'dart:typed_data';

import 'deteccao.dart';

/// Guarda o resultado completo de uma execução do pipeline:
/// captura -> detecção -> recorte -> OCR -> texto final.
///
/// Cada campo corresponde a uma "etapa" didática. Isso é intencional: o
/// "Modo Explicação" (ver `ui/tela_resultado.dart`) simplesmente itera sobre
/// os campos deste objeto para montar a visualização passo a passo.
class ResultadoLeitura {
  ResultadoLeitura({
    required this.imagemOriginal,
    required this.imagemComCaixa,
    required this.imagemRecortada,
    required this.deteccao,
    required this.textoBruto,
    required this.textoFinal,
    required this.momento,
  });

  /// Etapa 1: a foto exatamente como veio da câmera/galeria, sem nenhum
  /// processamento.
  final Uint8List imagemOriginal;

  /// Etapa 2: a mesma imagem, agora com a caixa delimitadora desenhada por
  /// cima (gerada em `ui/widgets/pintor_caixa_deteccao.dart`).
  final Uint8List imagemComCaixa;

  /// Etapa 3: apenas o recorte da região da placa, já isolado do resto da
  /// imagem — é isso que é enviado para o OCR.
  final Uint8List? imagemRecortada;

  /// A detecção que originou o recorte acima (caixa + confiança). Pode ser
  /// nula quando o modelo não encontrou nenhuma placa na imagem.
  final Deteccao? deteccao;

  /// Etapa 4: texto exatamente como o ML Kit devolveu, sem nenhuma limpeza
  /// (pode conter espaços, quebras de linha ou caracteres confundidos).
  final String? textoBruto;

  /// Etapa 5: texto final, já normalizado (maiúsculas, sem espaços/símbolos
  /// estranhos) — o que de fato mostramos como "a placa lida".
  final String? textoFinal;

  /// Quando esta leitura foi feita. Usado para ordenar/exibir o histórico.
  final DateTime momento;

  /// Indica se o pipeline conseguiu ler algum texto no final. Usado pela UI
  /// para decidir entre o estado "sucesso" (verde, som/vibração) e o estado
  /// "nenhuma placa encontrada" (laranja, mensagem simpática).
  bool get sucesso => textoFinal != null && textoFinal!.isNotEmpty;
}
