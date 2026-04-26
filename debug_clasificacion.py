#!/usr/bin/env python3
"""
Script de DEBUG - Ver paso a paso qué está pasando
"""

import json
import pandas as pd
import sys
from pathlib import Path

# Agregar el proyecto al path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from ml_engine.use_ml import csv_row_to_metadatos_ia
from ml_engine.model import NarcoContentClassifier

print("\n" + "🐛 "*30)
print("DEBUG - Verificar Cada Paso de la Clasificación")
print("🐛 "*30 + "\n")

# Paso 1: Verificar que los CSVs existen
dataset_path = Path(__file__).resolve().parent / "Agentes" / "agente_B" / "dataset"
print(f"📁 Dataset path: {dataset_path}")
print(f"   Existe: {dataset_path.exists()}\n")

csv_files = list(dataset_path.glob("video_metadata_*.csv"))
print(f"📊 CSVs encontrados: {len(csv_files)}")
for csv in csv_files:
    print(f"   - {csv.name}")
print()

# Paso 2: Leer el CSV
if csv_files:
    csv_path = csv_files[0]
    print(f"📖 Leyendo CSV: {csv_path.name}")
    
    df = pd.read_csv(csv_path)
    print(f"   Filas en CSV: {len(df)}")
    print(f"   Columnas: {df.columns.tolist()}\n")
    
    # Mostrar primeras filas
    print(f"📋 Primeras 3 filas del CSV:")
    print(df.head(3).to_string())
    print()
    
    # Paso 3: Intentar convertir una fila a metadatos_ia
    print(f"🔄 Intentando convertir fila a metadatos_ia...")
    try:
        primera_fila = df.iloc[0]
        print(f"   Fila 1 (tipos):")
        for col in df.columns:
            val = primera_fila[col]
            print(f"      {col}: {type(val).__name__} = {repr(val)[:80]}")
        
        print()
        metadatos = csv_row_to_metadatos_ia(primera_fila)
        print(f"   ✅ Conversión exitosa!")
        print(f"   ID Video: {metadatos.get('video', {}).get('id')}")
        print(f"   Título: {metadatos.get('video', {}).get('titulo')[:50]}...")
        print(f"   Engagement: {metadatos.get('engagement')}\n")
        
        # Paso 4: Probar clasificación con 1 video
        print(f"🤖 Iniciando modelo ML...")
        clasificador = NarcoContentClassifier()
        clasificador.load_model('ml_engine/narco_model.pkl')
        print(f"   ✅ Modelo cargado\n")
        
        print(f"🔮 Clasificando 1 video...")
        resultado_json = clasificador.predict_and_extract([metadatos])
        resultado = json.loads(resultado_json)
        
        print(f"   ✅ Clasificación completada!")
        print(f"\n{'='*80}")
        print(f"RESULTADO:")
        print(f"{'='*80}")
        print(json.dumps(resultado, indent=2, ensure_ascii=False))
        print(f"{'='*80}\n")
        
    except Exception as e:
        print(f"   ❌ ERROR: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
else:
    print("❌ No se encontraron CSVs en la carpeta\n")
