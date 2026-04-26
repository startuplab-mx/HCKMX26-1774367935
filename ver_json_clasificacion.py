#!/usr/bin/env python3
"""
Script para ver el JSON de clasificación en tiempo real
Lee los CSVs y clasifica, mostrando el resultado completo en consola
"""

import json
import sys
from pathlib import Path

# Agregar el proyecto al path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from ml_engine.use_ml import clasificar_tiktok

print("\n" + "🔍 "*30)
print("PRUEBA DE CLASIFICACIÓN ML - Ver JSON Completo")
print("🔍 "*30 + "\n")

print("📁 CSVs disponibles:")
dataset_path = Path(__file__).resolve().parent / "Agentes" / "agente_B" / "dataset"
csv_files = list(dataset_path.glob("video_metadata_*.csv"))
for i, csv in enumerate(csv_files, 1):
    file_size = csv.stat().st_size / 1024  # KB
    print(f"   {i}. {csv.name} ({file_size:.1f} KB)")

print("\n" + "▶️ "*30)
print("Ejecutando clasificar_tiktok()...")
print("▶️ "*30 + "\n")

resultado_json = clasificar_tiktok()

print("\n" + "="*100)
print("📊 JSON COMPLETO DE CLASIFICACIÓN")
print("="*100 + "\n")

try:
    resultado = json.loads(resultado_json)
    
    # Mostrar todo el JSON de forma bonita
    print(json.dumps(resultado, indent=2, ensure_ascii=False))
    
    print("\n" + "="*100)
    print("📈 ESTADÍSTICAS")
    print("="*100)
    
    if isinstance(resultado, list):
        print(f"\n✅ Total de videos clasificados: {len(resultado)}")
        
        if len(resultado) > 0:
            narco_count = sum(1 for v in resultado if v.get('es_narcocultura', False))
            legitimo_count = len(resultado) - narco_count
            
            print(f"   - Videos con narcocultura: {narco_count} ({100*narco_count/len(resultado):.1f}%)")
            print(f"   - Videos legítimos: {legitimo_count} ({100*legitimo_count/len(resultado):.1f}%)")
            
            print("\n📋 Detalles de cada video:")
            for i, video in enumerate(resultado, 1):
                print(f"\n   Video {i}:")
                print(f"      ID: {video.get('id_video', 'N/A')}")
                print(f"      Es narcocultura: {video.get('es_narcocultura', 'N/A')}")
                print(f"      Confianza: {video.get('confianza_modelo', 'N/A'):.4f}")
                
                if video.get('es_narcocultura'):
                    rd = video.get('recursos_detectados', {})
                    print(f"      Recursos detectados:")
                    if rd:
                        if rd.get('simbologias_y_textos'):
                            print(f"         - Símbolos/textos: {rd.get('simbologias_y_textos')}")
                        if rd.get('emojis'):
                            print(f"         - Emojis: {rd.get('emojis')}")
                        if rd.get('artistas'):
                            print(f"         - Artistas: {rd.get('artistas')}")
                
                mv = video.get('metricas_viralidad', {})
                if mv:
                    print(f"      Métricas de viralidad:")
                    print(f"         - Vistas: {mv.get('vistas', 0):,}")
                    print(f"         - Likes: {mv.get('likes', 0):,}")
                    print(f"         - Comentarios: {mv.get('comentarios_totales', 0):,}")
                    print(f"         - Compartidos: {mv.get('compartidos', 0):,}")
    
    print("\n" + "="*100)
    print("✅ CLASIFICACIÓN COMPLETADA EXITOSAMENTE")
    print("="*100 + "\n")
    
except json.JSONDecodeError as e:
    print(f"\n❌ ERROR: No se puede parsear el JSON")
    print(f"Error: {e}")
    print("\nContenido raw:")
    print(resultado_json)
except Exception as e:
    print(f"\n❌ ERROR: {type(e).__name__}: {str(e)}")
    import traceback
    traceback.print_exc()
