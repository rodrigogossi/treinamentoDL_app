/// Este arquivo é responsável por extrair texto de uma imagem (o recorte da
/// placa) usando OCR on-device via Google ML Kit.
///
/// POR QUE GOOGLE ML KIT E NÃO EASYOCR/TESSERACT?
/// EasyOCR é uma biblioteca Python (PyTorch por baixo) sem binding oficial
/// para Flutter — "portar" seria reimplementar o modelo em outro runtime,
/// trabalho grande demais para o valor que agrega num app didático.
/// Tesseract tem plugins Flutter (`flutter_tesseract_ocr` e similares), mas
/// costuma exigir mais ajuste manual de pré-processamento (binarização,
/// contraste) para ler bem texto curto em fontes de placa veicular.
/// O `google_mlkit_text_recognition` roda 100% on-device (sem enviar a foto
/// para nenhum servidor — importante numa demo com fotos de placas reais),
/// tem plugin Flutter oficial mantido pelo Google, funciona bem "out of the
/// box" para texto em blocos curtos como placas, e não exige nenhuma
/// configuração extra de treinamento ou modelo adicional.
library;

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Resultado de uma chamada ao OCR: o texto bruto (como o ML Kit devolveu) e
/// o texto já normalizado para parecer uma placa.
class TextoReconhecido {
  const TextoReconhecido({required this.bruto, required this.normalizado});

  final String bruto;
  final String normalizado;
}

class ServicoOcr {
  final TextRecognizer _reconhecedor = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Roda o OCR sobre os bytes de uma imagem (o recorte da placa) e devolve
  /// o texto bruto + uma versão normalizada.
  ///
  /// O ML Kit espera um [InputImage], que normalmente é construído a partir
  /// de um caminho de arquivo. Por isso salvamos o recorte (que só existe em
  /// memória, como `Uint8List`) em um arquivo temporário antes de processar.
  Future<TextoReconhecido?> reconhecerTexto(List<int> bytesImagemRecorte) async {
    final diretorioTemp = await getTemporaryDirectory();
    final arquivoTemp = File(
      '${diretorioTemp.path}/recorte_placa_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await arquivoTemp.writeAsBytes(bytesImagemRecorte);

    try {
      final inputImage = InputImage.fromFilePath(arquivoTemp.path);
      final resultado = await _reconhecedor.processImage(inputImage);

      final textoBruto = resultado.text.trim();
      if (textoBruto.isEmpty) return null;

      return TextoReconhecido(
        bruto: textoBruto,
        normalizado: _normalizarTextoPlaca(textoBruto),
      );
    } finally {
      // Limpa o arquivo temporário — ele só existia para satisfazer a API
      // do ML Kit, não precisa ficar ocupando espaço no dispositivo.
      if (await arquivoTemp.exists()) {
        await arquivoTemp.delete();
      }
    }
  }

  /// Normaliza o texto bruto do OCR para o formato esperado de uma placa:
  /// maiúsculas, sem espaços/quebras de linha, apenas letras e números.
  ///
  /// Isso NÃO é um validador de formato de placa (Mercosul, antigo, etc) —
  /// é só uma limpeza simples para exibição. Numa aula, esse método é um bom
  /// gancho para discutir como o texto bruto do OCR quase sempre precisa de
  /// pós-processamento antes de virar um dado utilizável.
  String _normalizarTextoPlaca(String textoBruto) {
    final apenasAlfanumerico = textoBruto
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return apenasAlfanumerico;
  }

  /// Libera os recursos nativos do reconhecedor. Chame ao encerrar o app.
  void dispose() {
    _reconhecedor.close();
  }
}
