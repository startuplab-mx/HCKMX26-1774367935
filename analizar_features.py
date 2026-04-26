#!/usr/bin/env python3
"""
Script para analizar la importancia de características en el modelo RandomForest.
Muestra qué características tienen más peso en la clasificación.
"""

import numpy as np
import pickle
from pathlib import Path

print("\n" + "="*80)
print("IMPORTANCIA DE CARACTERÍSTICAS - RandomForest")
print("="*80 + "\n")

# Cargar el modelo
model_path = Path(__file__).resolve().parent / "ml_engine" / "narco_model.pkl"

try:
    with open(model_path, 'rb') as f:
        classifier = pickle.load(f)
    
    # El modelo es un RandomForestClassifier wrapped by NarcoContentClassifier
    # Necesitamos acceder a clf.rf (el RandomForest interno)
    
    if hasattr(classifier, 'rf'):
        rf_model = classifier.rf
        print("✓ Modelo RandomForest encontrado\n")
        
        # Obtener importancia de características
        feature_importance = rf_model.feature_importances_
        feature_names = classifier.feature_names if hasattr(classifier, 'feature_names') else None
        
        if feature_names is None:
            # Si no tenemos nombres, usamos los índices
            feature_names = [f"feature_{i}" for i in range(len(feature_importance))]
        
        # Crear lista de (nombre, importancia) y ordenar por importancia
        features_sorted = sorted(
            zip(feature_names, feature_importance),
            key=lambda x: x[1],
            reverse=True
        )
        
        print("{"*5 + " TOP 20 CARACTERÍSTICAS MÁS IMPORTANTES " + "}"*5 + "\n")
        
        for i, (name, importance) in enumerate(features_sorted[:20], 1):
            bar_length = int(importance * 50)
            bar = "█" * bar_length
            percentage = f"{importance*100:.2f}%"
            print(f"{i:2d}. {name:40s} {bar:50s} {percentage}")
        
        print("\n" + "="*80)
        print("ANÁLISIS")
        print("="*80 + "\n")
        
        # Calcular cuántas características aportan el 80% de la importancia
        cumsum = np.cumsum([imp for _, imp in features_sorted])
        n_features_80 = np.argmax(cumsum >= 0.8) + 1
        
        print(f"Características que explican el 80% de la decisión: {n_features_80}")
        print(f"\nTop {n_features_80} características:")
        for i, (name, importance) in enumerate(features_sorted[:n_features_80], 1):
            print(f"  {i}. {name}: {importance*100:.2f}%")
        
        # Mostrar estadísticas
        print(f"\nEstadísticas:")
        print(f"  Total de características: {len(feature_importance)}")
        print(f"  Importancia máxima: {np.max(feature_importance)*100:.2f}%")
        print(f"  Importancia mínima: {np.min(feature_importance)*100:.2f}%")
        print(f"  Promedio: {np.mean(feature_importance)*100:.2f}%")
        
    else:
        print("❌ No se encontró rf (RandomForest) en el clasificador")
        print("Propiedades del clasificador:")
        print(dir(classifier))
        
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "="*80 + "\n")
