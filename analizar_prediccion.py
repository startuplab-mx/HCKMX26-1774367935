#!/usr/bin/env python3
"""
Script para analizar POR QUÉ el modelo clasifica un video de cierta forma.
Muestra todas las características que usa el modelo para la predicción.
"""

import json
import pandas as pd
import sys
from pathlib import Path

# Agregar el proyecto al path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from ml_engine.use_ml import csv_row_to_metadatos_ia
from ml_engine.model import NarcoContentClassifier

print("\n" + "="*80)
print("ANÁLISIS DE PREDICCIÓN - ¿Por qué el modelo clasifica así?")
print("="*80 + "\n")

# Cargar CSVs disponibles
dataset_path = Path(__file__).resolve().parent / "Agentes" / "agente_B" / "dataset"
csv_files = list(dataset_path.glob("video_metadata_*.csv"))

if not csv_files:
    print("❌ No se encontraron CSVs\n")
    sys.exit(1)

print(f"CSVs disponibles:")
for i, csv in enumerate(csv_files, 1):
    print(f"  {i}. {csv.name}")

# Si hay múltiples CSVs, permitir selección
if len(csv_files) > 1:
    print("\nUsando el primer CSV...")

csv_path = csv_files[0]
df = pd.read_csv(csv_path)

print(f"\nAnalizando: {csv_path.name}")
print(f"Filas disponibles: {len(df)}\n")

# Convertir primera fila
primera_fila = df.iloc[0]
metadatos = csv_row_to_metadatos_ia(primera_fila)

print("="*80)
print("CARACTERÍSTICAS DEL VIDEO")
print("="*80)

# Mostrar estructura de metadatos
print("\n📌 INFORMACIÓN BÁSICA:")
video_info = metadatos.get('video', {})
print(f"  ID Video: {video_info.get('id')}")
print(f"  Título: {video_info.get('titulo')}")
print(f"  Descripción: {video_info.get('descripcion')}")

print("\n🎵 MÚSICA:")
audio_info = metadatos.get('audio')
if audio_info:
    print(f"  Canción: {audio_info.get('titulo')}")
    print(f"  Artista: {audio_info.get('artista')}")
else:
    print(f"  (Sin música)")

print("\n👤 CREADOR:")
creator_info = metadatos.get('creador', {})
print(f"  Handle: {creator_info.get('handle')}")
print(f"  Seguidores: {creator_info.get('seguidores')}")

print("\n#️⃣ HASHTAGS:")
hashtags_info = metadatos.get('hashtags', {})
print(f"  Total: {hashtags_info.get('total')}")
print(f"  Lista: {hashtags_info.get('lista')}")

print("\n💬 MENCIONES:")
mentions_info = metadatos.get('menciones', {})
print(f"  Total: {mentions_info.get('total')}")
print(f"  Lista: {mentions_info.get('lista')}")

print("\n📊 ENGAGEMENT:")
engagement_info = metadatos.get('engagement', {})
print(f"  Vistas: {engagement_info.get('vistas')}")
print(f"  Likes: {engagement_info.get('likes')}")
print(f"  Comentarios: {engagement_info.get('comentarios_totales')}")
print(f"  Compartidos: {engagement_info.get('compartidos')}")
print(f"  Ratio Likes/Vistas: {round(engagement_info.get('likes', 0) / max(engagement_info.get('vistas', 1), 1), 4)}")

print("\n📅 TEMPORAL:")
temporal_info = metadatos.get('temporal', {})
print(f"  Fecha upload: {temporal_info.get('fecha_upload')}")

# Ahora cargar el modelo y hacer la predicción
print("\n" + "="*80)
print("PREDICCIÓN DEL MODELO")
print("="*80 + "\n")

clasificador = NarcoContentClassifier()
clasificador.load_model('ml_engine/narco_model.pkl')

resultado_json = clasificador.predict_and_extract([metadatos])
resultado = json.loads(resultado_json)[0]

print(f"ID Video: {resultado['id_video']}")
print(f"Es Narcocultura: {resultado['es_narcocultura']}")
print(f"Confianza: {resultado['confianza_modelo']} ({int(resultado['confianza_modelo']*100)}%)")
print(f"Recursos detectados: {resultado['recursos_detectados']}")

# Análisis
print("\n" + "="*80)
print("ANÁLISIS")
print("="*80 + "\n")

if resultado['es_narcocultura']:
    print("⚠️  El modelo MARCÓ ESTE VIDEO COMO NARCOCULTURA\n")
    print("Características que podrían influir:")
    
    # Analizar características sospechosas
    if engagement_info.get('vistas', 0) > 10_000_000:
        print(f"  • Vistas muy altas: {engagement_info.get('vistas')} (puede correlacionar con contenido viral)")
    
    if engagement_info.get('likes', 0) > 1_000_000:
        print(f"  • Likes muy altos: {engagement_info.get('likes')}")
    
    hashtag_list = hashtags_info.get('lista', [])
    if len(hashtag_list) > 0:
        print(f"  • Hashtags: {hashtag_list}")
    
    title = video_info.get('titulo', '').lower()
    suspicious_words = ['parati', 'foryou', 'viral', 'trending']
    suspicious_found = [w for w in suspicious_words if w in title]
    if suspicious_found:
        print(f"  • Palabras en título: {suspicious_found}")
    
    print(f"\n❓ POSIBLES RAZONES:")
    print(f"  1. El modelo fue entrenado con datos sesgados")
    print(f"  2. El modelo está sobre-clasificando (muchos falsos positivos)")
    print(f"  3. Las características seleccionadas no son discriminativas suficientes")
    
else:
    print("✅ El modelo NO marcó este video como narcocultura\n")

print("="*80 + "\n")
