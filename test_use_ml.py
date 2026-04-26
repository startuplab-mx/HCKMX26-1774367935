#!/usr/bin/env python3
"""
Script de prueba para verificar que use_ml.py genera correctamente el JSON de clasificación
Validar formato según integracion.md: Array directo de predicciones
"""

import json
import sys
from pathlib import Path

# Agregar el proyecto al path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from ml_engine.use_ml import clasificar_tiktok

print("="*80)
print("PRUEBA DIRECTA DE use_ml.py")
print("Verificar formato: Array de predicciones (según integracion.md)")
print("="*80)
print()

# Llamar directamente a clasificar_tiktok()
print("🔄 Ejecutando clasificar_tiktok()...")
print()

resultado_json = clasificar_tiktok()

print()
print("="*80)
print("RESULTADO RECIBIDO")
print("="*80)
print()

# Parsear y mostrar el JSON
try:
    resultado = json.loads(resultado_json)
    
    # Mostrar con formato
    print(json.dumps(resultado, indent=2, ensure_ascii=False))
    
    print()
    print("="*80)
    print("VALIDACIÓN DEL FORMATO")
    print("="*80)
    print()
    
    # Validar que sea un array
    if not isinstance(resultado, list):
        print("❌ ERROR: El resultado NO es un array")
        print(f"   Tipo recibido: {type(resultado)}")
        sys.exit(1)
    
    print(f"✅ Resultado es un array con {len(resultado)} elemento(s)")
    print()
    
    if len(resultado) == 0:
        print("⚠️  ADVERTENCIA: Array vacío (probablemente no hay CSVs generados aún)")
        print("   Para generar CSVs: Haz un POST a /api/tiktok/recibir/")
    else:
        # Validar cada elemento del array
        primer_video = resultado[0]
        
        print("Validando primer video en el array...")
        print()
        
        checks = {
            "✅ Tiene 'id_video'": 'id_video' in primer_video,
            "✅ Tiene 'es_narcocultura'": 'es_narcocultura' in primer_video,
            "✅ Tiene 'confianza_modelo'": 'confianza_modelo' in primer_video,
            "✅ 'es_narcocultura' es bool": isinstance(primer_video.get('es_narcocultura'), bool),
            "✅ 'confianza_modelo' es float": isinstance(primer_video.get('confianza_modelo'), (float, int)),
            "✅ Tiene 'metricas_viralidad'": 'metricas_viralidad' in primer_video,
        }
        
        # Validar estructura de recursos_detectados
        if primer_video.get('es_narcocultura'):
            checks["✅ Si es narcocultura → tiene 'recursos_detectados'"] = 'recursos_detectados' in primer_video
            if 'recursos_detectados' in primer_video and primer_video['recursos_detectados']:
                rd = primer_video['recursos_detectados']
                checks["  ✅ recursos_detectados tiene estructura"] = (
                    isinstance(rd, dict) and 
                    'simbologias_y_textos' in rd and 
                    'emojis' in rd and 
                    'artistas' in rd
                )
        else:
            checks["✅ Si NO es narcocultura → 'recursos_detectados' es null"] = primer_video.get('recursos_detectados') is None
        
        # Validar metricas_viralidad
        if 'metricas_viralidad' in primer_video and primer_video['metricas_viralidad']:
            mv = primer_video['metricas_viralidad']
            checks["  ✅ metricas_viralidad tiene todos los campos"] = (
                'vistas' in mv and 'likes' in mv and 
                'comentarios_totales' in mv and 'compartidos' in mv
            )
        
        for check, resultado_check in checks.items():
            status = "✅" if resultado_check else "❌"
            print(f"{status} {check}")
    
    print()
    print("="*80)
    print("✅ VALIDACIÓN COMPLETADA")
    print("="*80)
    
except json.JSONDecodeError as e:
    print(f"❌ ERROR: No se puede parsear el JSON")
    print(f"Error: {e}")
    print()
    print("Contenido raw:")
    print(resultado_json)
    sys.exit(1)
except Exception as e:
    print(f"❌ ERROR: {type(e).__name__}: {str(e)}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

