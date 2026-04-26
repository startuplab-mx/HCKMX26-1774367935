from django.shortcuts import render
from django.http import JsonResponse, HttpResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
import json
import subprocess
import tempfile
from pathlib import Path
from .models import TikTokURL
from ml_engine.use_ml import clasificar_tiktok, NumpyEncoder


def extraer_metadata_tiktok(url):
    """
    Ejecuta yt-dlp para extraer metadata del TikTok sin generar archivos.
    Extrae solo los metadatos importantes para que un agente de IA
    pueda inferir el tipo de video.
    
    Args:
        url: URL del TikTok
        
    Returns:
        dict: JSON con metadata estructurada del video, o error si hay problema
    """
    try:
        # Ejecutar yt-dlp con flags para obtener metadata en JSON
        # --dump-json: imprime JSON a stdout sin crear archivos
        # --get-comments: obtiene los comentarios para análisis
        comando = [
            'python3', '-m', 'yt_dlp',
            '--dump-json',
            '--get-comments',
            url
        ]
        
        # Ejecutar comando y capturar output
        resultado = subprocess.run(
            comando,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        # Si hay error, registrarlo
        if resultado.returncode != 0:
            return {
                'error': True,
                'stderr': resultado.stderr,
                'stdout': resultado.stdout
            }
        
        # Parsear el JSON completo de la salida
        metadata_completo = json.loads(resultado.stdout)
        
        # Extraer metadatos importantes para clasificación de video
        metadata_procesada = extraer_metadatos_importantes(metadata_completo)
        
        return {
            'error': False,
            'data': metadata_procesada,
            'raw': metadata_completo  # JSON completo para referencia
        }
        
    except subprocess.TimeoutExpired:
        return {
            'error': True,
            'mensaje': 'Timeout: la extracción de datos tardó demasiado'
        }
    except json.JSONDecodeError as e:
        return {
            'error': True,
            'mensaje': f'Error al parsear JSON: {str(e)}'
        }
    except Exception as e:
        return {
            'error': True,
            'mensaje': f'Error ejecutando yt-dlp: {str(e)}'
        }


def extraer_metadatos_importantes(metadata_completo):
    """
    Extrae los metadatos importantes del JSON completo de yt-dlp
    para que un agente de IA pueda inferir el tipo de video.
    
    Metadatos incluidos:
    - Información básica del video
    - Engagement (vistas, likes, comentarios)
    - Información del creador
    - Contenido (título, descripción, hashtags)
    - Comentarios (para análisis de sentimiento y tema)
    - Información de audio/música
    
    Args:
        metadata_completo: JSON completo de yt-dlp
        
    Returns:
        dict: Metadatos estructurados para análisis de IA
    """
    
    # Extraer hashtags del título y descripción
    def extraer_hashtags(texto):
        if not texto:
            return []
        import re
        return re.findall(r'#\w+', texto.lower())
    
    # Extraer información de audio/música
    def extraer_info_audio(metadata):
        info_audio = {}
        if 'audio' in metadata and metadata['audio']:
            for track in metadata['audio']:
                if isinstance(track, dict):
                    if 'title' in track:
                        info_audio['titulo'] = track['title']
                    if 'artist' in track:
                        info_audio['artista'] = track['artist']
        return info_audio if info_audio else None
    
    # Procesar primeros N comentarios para análisis
    def procesar_comentarios(comentarios, limite=5):
        if not comentarios:
            return []
        
        comentarios_procesados = []
        for i, comentario in enumerate(comentarios[:limite]):
            if isinstance(comentario, dict):
                comentarios_procesados.append({
                    'autor': comentario.get('author_id', 'desconocido'),
                    'contenido': comentario.get('text', ''),
                    'likes': comentario.get('like_count', 0),
                    'timestamp': comentario.get('time_text', '')
                })
        return comentarios_procesados
    
    # Metadatos procesados para el agente de IA
    metadatos_ia = {
        # Información básica del video
        'video': {
            'id': metadata_completo.get('id'),
            'url': metadata_completo.get('url'),
            'titulo': metadata_completo.get('title', ''),
            'descripcion': metadata_completo.get('description', ''),
            'duracion_segundos': metadata_completo.get('duration'),
            'fecha_publicacion': metadata_completo.get('upload_date'),
            'thumbnail': metadata_completo.get('thumbnail'),
        },
        
        # Información del creador
        'creador': {
            'nombre_usuario': metadata_completo.get('uploader'),
            'id_creador': metadata_completo.get('uploader_id'),
            'verificado': metadata_completo.get('uploader_verify', False),
        },
        
        # Engagement metrics (métricas de interacción)
        'engagement': {
            'vistas': metadata_completo.get('view_count', 0),
            'likes': metadata_completo.get('like_count', 0),
            'comentarios_totales': metadata_completo.get('comment_count', 0),
            'compartidos': metadata_completo.get('share_count', 0),
        },
        
        # Contenido para análisis
        'contenido': {
            'hashtags': extraer_hashtags(
                f"{metadata_completo.get('title', '')} {metadata_completo.get('description', '')}"
            ),
            'menciones': extraer_menciones(
                f"{metadata_completo.get('title', '')} {metadata_completo.get('description', '')}"
            ),
            'menciones_usuario': extraer_menciones_usuario(
                f"{metadata_completo.get('title', '')} {metadata_completo.get('description', '')}"
            ),
        },
        
        # Información de audio/música
        'audio': extraer_info_audio(metadata_completo),
        
        # Comentarios para análisis de tema
        'comentarios_muestra': procesar_comentarios(
            metadata_completo.get('comments', []),
            limite=5
        ),
        
        # Campos adicionales útiles para clasificación
        'metadatos_adicionales': {
            'es_video': not metadata_completo.get('is_live', False),
            'es_directo': metadata_completo.get('is_live', False),
            'es_publico': metadata_completo.get('availability', 'public') == 'public',
            'idioma': metadata_completo.get('language'),
            'etiquetas_contenido': metadata_completo.get('tags', []),
        }
    }
    
    return metadatos_ia


def extraer_menciones(texto):
    """Extrae menciones (@usuario) del texto"""
    if not texto:
        return []
    import re
    return re.findall(r'@\w+', texto.lower())


def extraer_menciones_usuario(texto):
    """Extrae menciones de usuario más detalladas"""
    if not texto:
        return []
    import re
    menciones = re.findall(r'@(\w+)', texto.lower())
    return menciones


def guardar_metadatos_json(metadatos_ia: dict) -> Path:
    """
    Guarda el diccionario metadatos_ia en un archivo JSON.
    
    Args:
        metadatos_ia: Diccionario con estructura normalizada
        
    Returns:
        Path: Ruta al archivo JSON creado
    """
    try:
        # Crear directorio para almacenar metadatos si no existe
        metadata_dir = Path(__file__).resolve().parent.parent / "Agentes" / "agente_B" / "raw"
        metadata_dir.mkdir(parents=True, exist_ok=True)
        
        # Generar nombre único basado en video_id
        video_id = metadatos_ia.get("video", {}).get("id", "unknown")
        json_file = metadata_dir / f"metadatos_ia_{video_id}.json"
        
        # Guardar el JSON
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(metadatos_ia, f, ensure_ascii=False, indent=2)
        
        return json_file
    except Exception as e:
        raise RuntimeError(f"Error al guardar metadatos JSON: {str(e)}")


def ejecutar_agente_b(json_input: Path, csv_output: Path) -> dict:
    """
    Ejecuta el Agente B (Traductor) para convertir JSON a CSV.
    
    Args:
        json_input: Ruta al archivo JSON de metadatos_ia
        csv_output: Ruta donde guardar el CSV de salida
        
    Returns:
        dict: Resultado de ejecución con status y rutas
    """
    try:
        # Ruta al script del Agente B
        agente_b_script = Path(__file__).resolve().parent.parent / "Agentes" / "agente_B" / "traductor_extraccion.py"
        
        if not agente_b_script.exists():
            raise RuntimeError(f"Script del Agente B no encontrado en: {agente_b_script}")
        
        # Comando para ejecutar el Agente B
        comando = [
            'python3',
            str(agente_b_script),
            '--input-json', str(json_input),
            '--output', str(csv_output)
        ]
        
        # Ejecutar el Agente B
        resultado = subprocess.run(
            comando,
            capture_output=True,
            text=True,
            timeout=120
        )
        
        if resultado.returncode != 0:
            stderr = resultado.stderr.strip() if resultado.stderr else "Error desconocido"
            raise RuntimeError(f"Error al ejecutar Agente B: {stderr}")
        
        # Verificar que el CSV fue creado
        if not csv_output.exists():
            raise RuntimeError("El Agente B no generó el archivo CSV esperado")
        
        return {
            'error': False,
            'csv_path': str(csv_output),
            'stdout': resultado.stdout
        }
        
    except subprocess.TimeoutExpired:
        return {
            'error': True,
            'mensaje': 'Timeout: El Agente B tardó demasiado'
        }
    except Exception as e:
        return {
            'error': True,
            'mensaje': f"Error ejecutando Agente B: {str(e)}"
        }


@csrf_exempt
@require_http_methods(["POST"])
def recibir_tiktok(request):
    """
    Endpoint para recibir URLs de TikTok y procesar el flujo completo:
    POST request → extraer metadatos_ia → agente B → generar CSV
    
    Método: POST
    Body JSON:
    {
        "url": "https://www.tiktok.com/...",
        "titulo": "Título opcional",
        "descripcion": "Descripción opcional"
    }
    
    Flujo:
    1. Recibe la URL del TikTok
    2. Ejecuta yt-dlp para obtener metadata completa
    3. Procesa y extrae metadatos importantes para análisis de IA (metadatos_ia)
    4. Guarda metadatos_ia en archivo JSON (Agentes/agente_B/raw/)
    5. Ejecuta Agente B para convertir JSON a CSV (Agentes/agente_B/dataset/)
    6. Devuelve ruta del CSV generado
    
    Response:
    {
        "success": true/false,
        "mensaje": "Mensaje descriptivo",
        "csv_path": "ruta/al/csv/generado.csv",
        "metadatos": {...}  // Optional: metadatos_ia extraídos
    }
    """
    try:
        data = json.loads(request.body)
        url = data.get('url', '').strip()
        titulo = data.get('titulo', '').strip()
        descripcion = data.get('descripcion', '').strip()

        # Validar que la URL esté presente
        if not url:
            return JsonResponse({
                'success': False,
                'mensaje': 'URL de TikTok requerida'
            }, status=400)

        # Validar que sea un link válido de TikTok
        if 'tiktok.com' not in url.lower():
            return JsonResponse({
                'success': False,
                'mensaje': 'Debe ser un link válido de TikTok (debe contener tiktok.com)'
            }, status=400)

        # Registrar la URL en BD
        tiktok_obj, created = TikTokURL.objects.get_or_create(
            url=url,
            defaults={
                'titulo': titulo if titulo else None,
                'descripcion': descripcion if descripcion else None
            }
        )

        # Si no era nuevo, actualizar campos opcionales si se proporcionan
        if not created:
            if titulo:
                tiktok_obj.titulo = titulo
            if descripcion:
                tiktok_obj.descripcion = descripcion
            tiktok_obj.save()

        # Paso 1: Extraer metadata usando yt-dlp
        resultado_metadata = extraer_metadata_tiktok(url)
        
        if resultado_metadata.get('error'):
            return JsonResponse({
                'success': False,
                'mensaje': f"Error al procesar el TikTok: {resultado_metadata.get('mensaje', 'Error desconocido')}",
                'error_detail': resultado_metadata
            }, status=400)
        
        # Paso 2: Obtener metadatos_ia ya procesados
        metadatos_ia = resultado_metadata['data']
        
        # Paso 3: Guardar metadatos_ia en archivo JSON temporal
        try:
            json_input_path = guardar_metadatos_json(metadatos_ia)
            print(f"✓ Metadatos guardados en: {json_input_path}")
        except RuntimeError as e:
            return JsonResponse({
                'success': False,
                'mensaje': f"Error al guardar metadatos: {str(e)}"
            }, status=500)
        
        # Paso 4: Ejecutar Agente B para generar CSV
        video_id = metadatos_ia.get("video", {}).get("id", "unknown")
        csv_output_path = Path(__file__).resolve().parent.parent / "Agentes" / "agente_B" / "dataset" / f"video_metadata_{video_id}.csv"
        
        resultado_agente_b = ejecutar_agente_b(json_input_path, csv_output_path)
        
        if resultado_agente_b.get('error'):
            return JsonResponse({
                'success': False,
                'mensaje': f"Error en Agente B: {resultado_agente_b.get('mensaje', 'Error desconocido')}"
            }, status=500)
        
        csv_path = resultado_agente_b.get('csv_path')
        print(f"✓ CSV generado en: {csv_path}")
        
        # Paso 5: Ejecutar clasificación ML (Módulo D)
        print("\n[PIPELINE] Ejecutando clasificación ML...")
        resultado_ml_json = clasificar_tiktok(csv_path=csv_path)
        resultado_ml_array = json.loads(resultado_ml_json)

        # Imprimir el JSON de clasificación para máxima visibilidad
        print("\n[RESULTADO] JSON de clasificación:")
        print(json.dumps(resultado_ml_array, indent=2, ensure_ascii=False))
        print()

        first_item = resultado_ml_array[0] if resultado_ml_array else {}
        metricas = first_item.get('metricas_viralidad', {})
        respuesta_filtrada = {
            'vistas': metricas.get('vistas', 0) if metricas else first_item.get('vistas', 0),
            'likes': metricas.get('likes', 0) if metricas else first_item.get('likes', 0),
            'es_narcocultura': first_item.get('es_narcocultura', False)
        }

        return HttpResponse(
            json.dumps(respuesta_filtrada, ensure_ascii=False, cls=NumpyEncoder),
            content_type='application/json',
            status=200
        )

    except json.JSONDecodeError:
        return JsonResponse({
            'success': False,
            'mensaje': 'JSON inválido en el body de la solicitud'
        }, status=400)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'mensaje': f'Error en el servidor: {str(e)}'
        }, status=500)