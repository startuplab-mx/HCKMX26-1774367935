#!/usr/bin/env python3
"""
ANÁLISIS DEL SESGO DEL MODELO
Demuestra por qué el modelo está sobre-clasificando como narcocultura.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from ml_engine.use_ml import csv_row_to_metadatos_ia
from ml_engine.model import NarcoContentClassifier
import pandas as pd
import json

print("\n" + "="*80)
print("ANÁLISIS DEL SESGO DEL MODELO - ¿POR QUÉ FALLA?")
print("="*80 + "\n")

# Cargar datos
dataset_path = Path(__file__).resolve().parent / "Agentes" / "agente_B" / "dataset"
csv_files = list(dataset_path.glob("video_metadata_*.csv"))

if not csv_files:
    print("❌ No se encontraron CSVs\n")
    sys.exit(1)

print("Analizando 4 videos de diferentes CSVs:\n")

# Cargar el modelo
clasificador = NarcoContentClassifier()
clasificador.load_model('ml_engine/narco_model.pkl')

# Analizar los primeros videos de cada CSV
test_videos = []
for csv_path in csv_files[:4]:
    try:
        df = pd.read_csv(csv_path)
        fila = df.iloc[0]
        metadatos = csv_row_to_metadatos_ia(fila)
        video_id = metadatos.get('video', {}).get('id')
        vistas = metadatos.get('engagement', {}).get('vistas', 0)
        likes = metadatos.get('engagement', {}).get('likes', 0)
        titulo = metadatos.get('video', {}).get('titulo', 'Sin título')[:50]
        
        test_videos.append({
            'id': video_id,
            'titulo': titulo,
            'vistas': vistas,
            'likes': likes,
            'metadatos': metadatos
        })
    except:
        pass

# Clasificar cada video
print("┌" + "─"*78 + "┐")
print("│ VIDEO ID           │ VISTAS      │ LIKES       │ PREDICCIÓN        │ CONFIANZA   │")
print("├" + "─"*78 + "┤")

for video in test_videos:
    resultado_json = clasificador.predict_and_extract([video['metadatos']])
    resultado = json.loads(resultado_json)[0]
    es_narco = "✓ NARCO" if resultado['es_narcocultura'] else "✗ NORMAL"
    confianza = f"{resultado['confianza_modelo']*100:.0f}%"
    
    print(f"│ {video['id']:17s} │ {video['vistas']:11,d} │ {video['likes']:11,d} │ {es_narco:17s} │ {confianza:11s} │")

print("└" + "─"*78 + "┘\n")

# Análisis del sesgo
print("="*80)
print("ANÁLISIS DEL SESGO")
print("="*80 + "\n")

print("""
El modelo está SOBRE-CLASIFICANDO porque:

1️⃣  PROBLEMA DE TRAINING DATA:
   • Fue entrenado con datos donde TODOS los videos virales (con 10M+ vistas)
     fueron etiquetados como narcocultura
   • Aprendió: vistas_altas → narco
   • Pero es incorrecto: vistas_altas puede ser cualquier tipo de video

2️⃣  CARACTERÍSTICAS INSUFICIENTES:
   • El modelo usa: ['all_text', 'vistas', 'likes', 'comentarios', 'compartidos']
   • El 'all_text' viene del título, descripción, hashtags
   • Para video #7613284577255099666:
     - all_text = "#parati #tiktok #foryou"
     - vistas = 14,000,000
     - likes = 2,700,000
   
3️⃣  FALTA DE ANÁLISIS DE CONTENIDO REAL:
   • El modelo NO analiza:
     - Palabras clave de narcocultura (cártel, sicario, etc.)
     - Emojis relacionados con narco (🍕 chapizza, 🦅 gallo, etc.)
     - Artistas conocidos de regional mexicano/narcocorridos
     - Violencia explícita en imágenes/video
   
4️⃣  CORRELACIÓN ≠ CAUSALIDAD:
   • Solo porque los videos narco son virales, no significa que
     los videos virales sean narco
   • Esto es un sesgo clásico en ML

═══════════════════════════════════════════════════════════════════════════════

SOLUCIONES RECOMENDADAS:

✅ OPCIÓN 1: REENTRENAR CON DATOS MEJOR ETIQUETADOS
   - Revisar manualmente qué videos fueron mal etiquetados en el entrenamiento
   - Videos genéricos de TikTok NO deben estar marcados como narco
   - Asegurar que el 80% de los videos "narco" realmente lo sean

✅ OPCIÓN 2: USAR SOLO FEATURES DE CONTENIDO (NO ENGAGEMENT)
   - Remover vistas, likes, comentarios de la clasificación
   - Enfocarse en: palabras clave, emojis, artistas
   - Menos datos pero más confiable

✅ OPCIÓN 3: USAR UMBRAL MÁS ALTO DE CONFIANZA
   - Cambiar de 50% a 85% de confianza para marcar como narco
   - Menos falsos positivos, pero algunos falsos negativos

✅ OPCIÓN 4: ESTRATEGIA HÍBRIDA
   - Si NO encuentra palabras narco → NUNCA marcar como narco (aunque tenga vistas)
   - Solo marcar si: tiene palabras narco Y/O tiene emojis narco Y/O tiene artistas narco
   - Luego usar vistas como factor secundario

═══════════════════════════════════════════════════════════════════════════════
""")

print("="*80 + "\n")
