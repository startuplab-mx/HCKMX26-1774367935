import json
import pandas as pd
from pathlib import Path
from ml_engine.model import NarcoContentClassifier
import numpy as np


class NumpyEncoder(json.JSONEncoder):
    """JSON Encoder para tipos numpy"""
    def default(self, obj):
        if isinstance(obj, (np.integer, np.int64, np.int32)):
            return int(obj)
        elif isinstance(obj, (np.floating, np.float64, np.float32)):
            return float(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        elif isinstance(obj, np.bool_):
            return bool(obj)
        return super().default(obj)


def deep_convert_numpy(obj):
    """
    Recorre recursivamente toda estructura (dict/list) y convierte tipos numpy
    a tipos Python nativos. Crítico para JSON serialization.
    """
    if isinstance(obj, dict):
        return {k: deep_convert_numpy(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [deep_convert_numpy(item) for item in obj]
    elif isinstance(obj, (np.integer, np.int64, np.int32)):
        return int(obj)
    elif isinstance(obj, (np.floating, np.float64, np.float32)):
        return float(obj)
    elif isinstance(obj, np.bool_):
        return bool(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    else:
        return obj


# ====================================================================
# A. INICIALIZACIÓN GLOBAL (Cargar modelo al iniciar la app)
# ====================================================================
clasificador = NarcoContentClassifier()
try:
    clasificador.load_model('ml_engine/narco_model.pkl')
    print("✓ Modelo ML cargado correctamente")
except FileNotFoundError:
    print("⚠ Advertencia: narco_model.pkl no encontrado. El modelo debe entrenarse primero.")
    clasificador = None


def csv_row_to_metadatos_ia(row):
    """
    Convierte una fila del CSV (formato TRAINING_FIELDS flat) nuevamente a la estructura
    metadatos_ia anidada para que sea compatible con el clasificador.
    
    Args:
        row: pandas Series (fila del CSV)
    
    Returns:
        dict: Diccionario con estructura metadatos_ia anidada
    """
    
    # Función auxiliar para parsejar JSON strings o listas
    def parse_json_field(value):
        if pd.isna(value) or value == '':
            return []
        if isinstance(value, str):
            try:
                return json.loads(value)
            except:
                return [value] if value else []
        return value if isinstance(value, list) else []
    
    # Extraer y normalizar hashtags y menciones (vienen como JSON strings)
    hashtags = parse_json_field(row.get('hashtags_list', '[]'))
    mentions = parse_json_field(row.get('mentions_list', '[]'))
    comments = parse_json_field(row.get('comments_sample', '[]'))
    artists = parse_json_field(row.get('music_artists', '[]'))
    
    # Convertir menciones a menciones_usuario (remover @)
    mentions_usuario = [m.replace('@', '').lower() for m in mentions if isinstance(m, str)]
    
    # Reconstruir la estructura metadatos_ia
    metadatos_ia = {
        "video": {
            "id": str(row.get('video_id', 'desconocido')),
            "titulo": str(row.get('title', '')),
            "descripcion": str(row.get('description', '')),
            "duracion_segundos": int(row.get('duration', 0)) if pd.notna(row.get('duration', 0)) else 0,
            "fecha_publicacion": str(row.get('upload_date', '')),
            "url": str(row.get('source_url', ''))
        },
        
        "creador": {
            "nombre_usuario": str(row.get('creator_handle', '')),
            "id_creador": None,
            "verificado": False
        },
        
        "engagement": {
            "vistas": int(row.get('view_count', 0)) if pd.notna(row.get('view_count', 0)) else 0,
            "likes": int(row.get('like_count', 0)) if pd.notna(row.get('like_count', 0)) else 0,
            "comentarios_totales": int(row.get('comment_count', 0)) if pd.notna(row.get('comment_count', 0)) else 0,
            "compartidos": int(row.get('repost_count', 0)) if pd.notna(row.get('repost_count', 0)) else 0
        },
        
        "contenido": {
            "hashtags": hashtags,
            "menciones": mentions,
            "menciones_usuario": mentions_usuario
        },
        
        "audio": {
            "titulo": str(row.get('music_track', '')) if pd.notna(row.get('music_track', '')) else None,
            "artista": str(row.get('music_artist', '')) if pd.notna(row.get('music_artist', '')) else None
        } if pd.notna(row.get('music_artist', '')) or pd.notna(row.get('music_track', '')) else None,
        
        "comentarios_muestra": [
            {"contenido": str(c), "autor": "unknown", "likes": 0}
            for c in comments if isinstance(c, str) and c
        ] if isinstance(comments, list) else [],
        
        "metadatos_adicionales": {
            "es_video": True,
            "es_directo": False,
            "es_publico": True
        }
    }
    
    return metadatos_ia


def cargar_csvs_agente_b():
    """
    Carga todos los CSVs generados por el Agente B desde Agentes/agente_B/dataset/
    
    Returns:
        list: Lista de DataFrames con los CSVs encontrados
    """
    dataset_path = Path(__file__).resolve().parent.parent / "Agentes" / "agente_B" / "dataset"
    
    if not dataset_path.exists():
        return []
    
    csv_files = list(dataset_path.glob("video_metadata_*.csv"))
    
    if not csv_files:
        return []
    
    dataframes = []
    for csv_file in csv_files:
        try:
            df = pd.read_csv(csv_file)
            dataframes.append(df)
        except Exception as e:
            continue
    
    return dataframes


def clasificar_tiktok(csv_path=None):
    """
    Función principal que:
    1. Lee UN CSV específico (o el más reciente si no se especifica)
    2. Convierte filas a estructura metadatos_ia
    3. Clasifica cada video con el modelo ML
    4. Devuelve la LISTA DE PREDICCIONES directamente (formato integracion.md)
    
    Args:
        csv_path: str o Path al archivo CSV específico a clasificar.
                  Si no se proporciona, se busca el CSV más reciente.
    
    Returns:
        str: JSON con array de predicciones del modelo
    """
    
    if clasificador is None:
        return json.dumps({
            "error": True,
            "mensaje": "Modelo ML no cargado. Entrena primero con train_model()"
        }, ensure_ascii=False, cls=NumpyEncoder)
    
    # Paso 1: Determinar qué CSV clasificar
    if csv_path is None:
        # Si no se especifica, buscar el CSV más reciente
        dataset_path = Path(__file__).resolve().parent.parent / "Agentes" / "agente_B" / "dataset"
        csv_files = list(dataset_path.glob("video_metadata_*.csv"))
        
        if not csv_files:
            return json.dumps([], ensure_ascii=False, cls=NumpyEncoder)
        
        # Usar el CSV más reciente
        csv_path = max(csv_files, key=lambda p: p.stat().st_mtime)
    else:
        csv_path = Path(csv_path)
    
    if not csv_path.exists():
        return json.dumps([], ensure_ascii=False, cls=NumpyEncoder)
    
    print(f"[ML] Clasificando CSV: {csv_path.name}")
    
    # Paso 2: Leer el CSV
    try:
        df = pd.read_csv(csv_path)
        print(f"[ML] Filas encontradas: {len(df)}")
    except Exception as e:
        print(f"[ML] Error leyendo CSV: {e}")
        return json.dumps([], ensure_ascii=False, cls=NumpyEncoder)
    
    # Paso 3: Convertir filas a metadatos_ia
    all_metadatos = []
    for _, row in df.iterrows():
        try:
            metadatos = csv_row_to_metadatos_ia(row)
            all_metadatos.append(metadatos)
        except Exception as e:
            continue
    
    if not all_metadatos:
        return json.dumps([], ensure_ascii=False, cls=NumpyEncoder)
    
    print(f"[ML] {len(all_metadatos)} video(s) convertidos")
    
    # Paso 4: Clasificar con el modelo (devuelve str JSON)
    resultado_json_str = clasificador.predict_and_extract(all_metadatos)
    
    # Paso 5: Parsear y limpiar tipos numpy
    resultado = json.loads(resultado_json_str)
    resultado_limpio = deep_convert_numpy(resultado)
    
    # Imprimir resultado para debugging
    print("\n" + "="*80)
    print("RESULTADO CLASIFICACIÓN ML")
    print("="*80)
    print(json.dumps(resultado_limpio, indent=2, ensure_ascii=False))
    print("="*80 + "\n")
    
    # Devolver directamente la lista de predicciones (formato integracion.md)
    return json.dumps(resultado_limpio, ensure_ascii=False, cls=NumpyEncoder)


def clasificar_csv_especifico(csv_path):
    """
    Clasifica un archivo CSV específico (EN MEMORIA, sin guardar en disco).
    Devuelve directamente la lista de predicciones (formato integracion.md).
    
    Args:
        csv_path: str o Path al archivo CSV
    
    Returns:
        str: JSON con array de predicciones
    """
    if clasificador is None:
        return json.dumps({
            "error": True,
            "mensaje": "Modelo ML no cargado"
        }, ensure_ascii=False, cls=NumpyEncoder)
    
    csv_path = Path(csv_path)
    
    if not csv_path.exists():
        return json.dumps({
            "error": True,
            "mensaje": f"Archivo no encontrado: {csv_path}"
        }, ensure_ascii=False, cls=NumpyEncoder)
    
    try:
        df = pd.read_csv(csv_path)
        
        # Convertir filas a metadatos_ia
        all_metadatos = []
        for _, row in df.iterrows():
            metadatos = csv_row_to_metadatos_ia(row)
            all_metadatos.append(metadatos)
        
        # Clasificar
        resultado_json_str = clasificador.predict_and_extract(all_metadatos)
        resultado = json.loads(resultado_json_str)
        resultado_limpio = deep_convert_numpy(resultado)
        
        # Imprimir resultado para debugging
        print("\n" + "="*80)
        print(f"🎯 RESULTADO CLASIFICACIÓN ML - {csv_path.name}")
        print("="*80)
        print(json.dumps(resultado_limpio, indent=2, ensure_ascii=False, cls=NumpyEncoder))
        print("="*80 + "\n")
        
        # Guardar resultado en archivo para inspección
        resultado_path = Path(__file__).resolve().parent / f"clasificacion_resultado_{csv_path.stem}.json"
        with open(resultado_path, 'w', encoding='utf-8') as f:
            f.write(json.dumps(resultado_limpio, indent=2, ensure_ascii=False, cls=NumpyEncoder))
        print(f"✓ Resultado guardado en: {resultado_path}\n")
        
        # Devolver directamente la lista de predicciones
        return json.dumps(resultado_limpio, ensure_ascii=False, cls=NumpyEncoder)
        
    except Exception as e:
        return json.dumps({
            "error": True,
            "mensaje": f"Error procesando CSV: {str(e)}"
        }, ensure_ascii=False, cls=NumpyEncoder)

