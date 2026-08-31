/// Este arquivo define [Deteccao], a estrutura de dados que representa UMA
/// caixa delimitadora encontrada pelo modelo YOLOv8n.
///
/// É o "contrato" entre a camada de detecção (`deteccao/`, que decodifica a
/// saída bruta do TFLite) e a camada de UI (`ui/`, que desenha a caixa e usa
/// a confiança para decidir a mensagem exibida ao usuário).
library;

import 'dart:ui';

/// Representa uma placa detectada em uma imagem: onde ela está (retângulo em
/// coordenadas de PIXEL da imagem original, não da imagem redimensionada
/// 640x640 usada internamente pelo modelo) e o quão confiante o modelo está
/// disso (0.0 a 1.0).
class Deteccao {
  const Deteccao({required this.caixa, required this.confianca});

  /// Retângulo delimitador em coordenadas de pixel da imagem ORIGINAL
  /// (já com a transformação inversa do letterbox aplicada — ver
  /// `deteccao/pos_processamento_yolo.dart`).
  final Rect caixa;

  /// Confiança do modelo para esta detecção, de 0.0 (nenhuma certeza) a
  /// 1.0 (certeza total). Como treinamos apenas 1 classe ("placa"), essa
  /// confiança já é, na prática, "o quão parecido com uma placa isso é".
  final double confianca;

  /// Confiança formatada como porcentagem, ex: "87%". Útil para exibir
  /// diretamente na UI sem repetir a conta em vários widgets.
  String get confiancaPercentual => '${(confianca * 100).toStringAsFixed(0)}%';

  @override
  String toString() =>
      'Deteccao(caixa: $caixa, confianca: $confiancaPercentual)';
}
