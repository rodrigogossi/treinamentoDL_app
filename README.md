# Leitor de Placas com IA — repositório do minicurso

Material de apoio para um minicurso introdutório de Visão Computacional:
um app Flutter didático que demonstra, ao vivo, um pipeline completo de
ALPR (Automatic License Plate Recognition) rodando 100% no celular.

## Estrutura do repositório

```
.
├── best.pt                  # modelo YOLOv8n treinado (formato Ultralytics/PyTorch)
├── exportar_modelo/         # script Python que converte best.pt -> .tflite
└── treinamento_app/         # o app Flutter em si
```

- **[`exportar_modelo/`](exportar_modelo/)** — script isolado (fora do
  Flutter) que exporta o modelo treinado para o formato TFLite consumido
  pelo app. Só é necessário rodar de novo se você treinar um modelo novo.
- **[`treinamento_app/`](treinamento_app/)** — o app em si. Comece pelo
  [`treinamento_app/README.md`](treinamento_app/README.md): ele documenta a
  arquitetura, como rodar o projeto, como o pipeline de detecção + OCR
  funciona por dentro, e traz um roteiro sugerido para a aula.
