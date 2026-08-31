#!/usr/bin/env python3
"""
Converte o modelo YOLOv8n treinado (best.pt) para o formato TFLite, usado
pelo app Flutter em treinamento_app/assets/models/.

Este script fica FORA da pasta do app de propósito: exportar o modelo é uma
tarefa de Python/Ultralytics, separada do projeto Flutter — não precisa (e
não deveria) rodar dentro dele.

O QUE ESTE SCRIPT FAZ: só isso — carrega o best.pt e exporta para TFLite.
Ele NÃO copia o resultado para dentro do app; depois de rodar, copie o
arquivo gerado manualmente para:

    treinamento_app/assets/models/best_float32.tflite

COMO RODAR:
    python3.11 -m venv venv_export
    source venv_export/bin/activate      # Windows: venv_export\\Scripts\\activate
    pip install -r requirements.txt
    python exportar_modelo.py

REQUISITO — Python 3.10 ou mais recente:
A partir do Ultralytics 8.4, a exportação para TFLite depende do pacote
`litert-torch`, que exige Python 3.10+. Em um Python 3.9 (comum em
instalações padrão de macOS/Linux mais antigas), a exportação falha com
"ModuleNotFoundError: No module named 'litert_torch'". Se isso acontecer,
crie o ambiente virtual com uma versão mais nova do Python (ex:
`brew install python@3.11` no macOS, depois `python3.11 -m venv venv_export`).
"""

from ultralytics import YOLO

# Caminho do modelo treinado. Por padrão, espera o best.pt na pasta acima
# desta (onde ele já está neste projeto). Ajuste se o seu arquivo estiver
# em outro lugar.
CAMINHO_MODELO_TREINADO = "../best.pt"

# Tamanho de entrada do modelo (largura = altura, em pixels). ESTE VALOR
# PRECISA bater exatamente com `tamanhoEntrada` em
# treinamento_app/lib/deteccao/detector_yolo.dart — se um dia mudar aqui,
# mude lá também.
TAMANHO_ENTRADA = 640

modelo = YOLO(CAMINHO_MODELO_TREINADO)

# `imgsz` é a resolução de entrada da rede (ver comentário acima). O
# Ultralytics imprime, no final, o caminho exato do arquivo (ou pasta)
# gerado — copie esse resultado para
# treinamento_app/assets/models/best_float32.tflite.
modelo.export(format="tflite", imgsz=TAMANHO_ENTRADA)
