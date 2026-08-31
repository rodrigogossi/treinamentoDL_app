/// Este arquivo isola tudo relacionado à câmera física do dispositivo:
/// inicialização, ciclo de vida e captura de foto. A tela de captura
/// (`ui/tela_captura.dart`) usa esta classe sem precisar conhecer os
/// detalhes do pacote `camera` — se um dia trocarmos de pacote de câmera,
/// só este arquivo muda.
library;

import 'package:camera/camera.dart';

class ServicoCamera {
  CameraController? _controlador;

  /// Exposto para a UI poder montar o widget `CameraPreview(controlador)`.
  CameraController? get controlador => _controlador;

  bool get pronta => _controlador?.value.isInitialized ?? false;

  /// Detecta as câmeras físicas disponíveis, escolhe a traseira (a mais
  /// natural para fotografar uma placa de carro) e inicializa o preview.
  Future<void> iniciar() async {
    final camerasDisponiveis = await availableCameras();
    if (camerasDisponiveis.isEmpty) {
      throw StateError('Nenhuma câmera disponível neste dispositivo.');
    }

    final cameraTraseira = camerasDisponiveis.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => camerasDisponiveis.first,
    );

    _controlador = CameraController(
      cameraTraseira,
      ResolutionPreset.high,
      enableAudio: false, // não precisamos de áudio para fotos
    );

    await _controlador!.initialize();
  }

  /// Tira uma foto e devolve o caminho do arquivo temporário gerado pelo
  /// próprio pacote `camera`.
  Future<String> capturarFoto() async {
    final controlador = _controlador;
    if (controlador == null || !controlador.value.isInitialized) {
      throw StateError('Câmera não inicializada — chame iniciar() antes.');
    }
    final arquivo = await controlador.takePicture();
    return arquivo.path;
  }

  /// Libera a câmera. Essencial chamar ao sair da tela de captura, senão o
  /// app pode travar a câmera para outros apps (ou para o próprio app, se
  /// tentar reinicializar sem liberar a instância anterior).
  Future<void> encerrar() async {
    await _controlador?.dispose();
    _controlador = null;
  }
}
