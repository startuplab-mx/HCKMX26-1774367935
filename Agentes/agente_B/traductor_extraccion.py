import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

import pandas as pd


TRAINING_FIELDS = [
    "video_id",
    "upload_date",
    "timestamp",
    "duration",
    "creator_channel",
    "creator_handle",
    "title",
    "description",
    "hashtags_list",
    "hashtags_count",
    "mentions_list",
    "mentions_count",
    "music_track",
    "music_artist",
    "music_artists",
    "view_count",
    "like_count",
    "comment_count",
    "repost_count",
    "save_count",
    "comments_sample",
    "comments_sample_count",
    "source_url",
]


def load_metadatos_json_from_file(input_path: Path) -> dict:
    """Carga el archivo JSON de metadatos (puede ser yt-dlp o metadatos_ia de views)"""
    if not input_path.exists() or not input_path.is_file():
        raise RuntimeError(f"El archivo de entrada no existe: {input_path}")

    try:
        raw_text = input_path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise RuntimeError(f"No se pudo leer el archivo de entrada: {exc}") from exc

    if not raw_text:
        raise RuntimeError("El archivo de entrada esta vacio.")

    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        # Intenta la primera línea por si es formato dump-json de yt-dlp
        first_line = next((line for line in raw_text.splitlines() if line.strip()), "")
        try:
            return json.loads(first_line)
        except json.JSONDecodeError as exc:
            raise RuntimeError("El archivo no contiene un JSON valido.") from exc


def _serialize_nested(value: Any) -> Any:
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    return value


def extract_hashtags(text: str) -> list[str]:
    return sorted({tag.lower() for tag in re.findall(r"#([\w_]+)", text)})


def extract_mentions(text: str) -> list[str]:
    return sorted({mention.lower() for mention in re.findall(r"@([A-Za-z0-9._]+)", text)})


def build_training_record(metadatos_ia: dict) -> dict:
    """
    Construye un registro de entrenamiento a partir del diccionario metadatos_ia
    que viene desde views.py con estructura normalizada.
    
    Mapeo de estructura metadatos_ia a TRAINING_FIELDS:
    - metadatos_ia['video'] -> video_id, title, description, duration, upload_date
    - metadatos_ia['creador'] -> creator_channel, creator_handle
    - metadatos_ia['engagement'] -> view_count, like_count, comment_count, repost_count, save_count
    - metadatos_ia['contenido'] -> hashtags_list, mentions_list
    - metadatos_ia['audio'] -> music_track, music_artist, music_artists
    - metadatos_ia['comentarios_muestra'] -> comments_sample
    """
    
    # Extraer información del video
    video_info = metadatos_ia.get("video", {})
    video_id = video_info.get("id")
    title = str(video_info.get("titulo", ""))
    description = str(video_info.get("descripcion", ""))
    duration = video_info.get("duracion_segundos")
    upload_date = video_info.get("fecha_publicacion")
    source_url = video_info.get("url") or metadatos_ia.get("video", {}).get("url")
    
    # Extraer información del creador
    creador_info = metadatos_ia.get("creador", {})
    creator_channel = creador_info.get("nombre_usuario")
    creator_handle = creador_info.get("nombre_usuario")
    
    # Extraer métricas de engagement
    engagement = metadatos_ia.get("engagement", {})
    view_count = engagement.get("vistas")
    like_count = engagement.get("likes")
    comment_count = engagement.get("comentarios_totales")
    repost_count = engagement.get("compartidos")
    save_count = engagement.get("save_count")
    
    # Extraer contenido (hashtags y menciones)
    contenido = metadatos_ia.get("contenido", {})
    hashtags = contenido.get("hashtags", [])
    mentions = contenido.get("menciones_usuario", [])
    
    # Extraer información de audio/música
    audio_info = metadatos_ia.get("audio") or {}
    music_track = audio_info.get("titulo") if isinstance(audio_info, dict) else None
    music_artist = audio_info.get("artista") if isinstance(audio_info, dict) else None
    music_artists = [music_artist] if (isinstance(audio_info, dict) and audio_info.get("artista")) else []
    
    # Procesar comentarios
    comentarios_muestra = metadatos_ia.get("comentarios_muestra", [])
    comments_text = []
    for comentario in comentarios_muestra:
        if isinstance(comentario, dict):
            contenido_comentario = comentario.get("contenido")
            if isinstance(contenido_comentario, str) and contenido_comentario.strip():
                comments_text.append(contenido_comentario.strip())
    
    comments_extracted_count = len(comments_text)
    
    return {
        "video_id": video_id,
        "upload_date": upload_date,
        "timestamp": None,
        "duration": duration,
        "creator_channel": creator_channel,
        "creator_handle": creator_handle,
        "title": title,
        "description": description,
        "hashtags_list": hashtags,
        "hashtags_count": len(hashtags),
        "mentions_list": mentions,
        "mentions_count": len(mentions),
        "music_track": music_track,
        "music_artist": music_artist,
        "music_artists": music_artists,
        "view_count": view_count,
        "like_count": like_count,
        "comment_count": comment_count,
        "repost_count": repost_count,
        "save_count": save_count,
        "comments_sample": comments_text,
        "comments_sample_count": comments_extracted_count,
        "source_url": source_url,
    }


def normalize_training_metadata(metadatos_ia: dict) -> pd.DataFrame:
    record = build_training_record(metadatos_ia)
    normalized = {key: _serialize_nested(value) for key, value in record.items()}
    return pd.DataFrame([normalized], columns=TRAINING_FIELDS)


def save_dataset(df: pd.DataFrame, output_csv: Path) -> None:
    output_csv.parent.mkdir(parents=True, exist_ok=True)

    if not output_csv.exists():
        df.to_csv(
            output_csv,
            mode="w",
            index=False,
            header=True,
            quoting=csv.QUOTE_ALL,
        )
        return

    # Merge old/new schemas to avoid data loss when new fields are added.
    existing_df = pd.read_csv(output_csv, dtype=str)
    existing_cols = list(existing_df.columns)
    new_cols = list(df.columns)
    all_cols = existing_cols + [col for col in new_cols if col not in existing_cols]

    existing_df = existing_df.reindex(columns=all_cols)
    df = df.reindex(columns=all_cols)
    combined = pd.concat([existing_df, df], ignore_index=True)

    combined.to_csv(
        output_csv,
        mode="w",
        index=False,
        header=True,
        quoting=csv.QUOTE_ALL,
    )


def main() -> int:
    """
    Agente B (Traductor): convierte JSON de metadatos TikTok a CSV estructurado.
    
    El diccionario metadatos_ia viene de views.py (tiktok_receiver) con estructura:
    - video: {id, titulo, descripcion, duracion_segundos, fecha_publicacion, url, ...}
    - creador: {nombre_usuario, id_creador, verificado}
    - engagement: {vistas, likes, comentarios_totales, compartidos}
    - contenido: {hashtags, menciones, menciones_usuario}
    - audio: {titulo, artista}
    - comentarios_muestra: []
    - metadatos_adicionales: {...}
    
    El agente B ya NO hace scrapping de TikTok, solo procesa el JSON que viene de views.py.
    """
    parser = argparse.ArgumentParser(
        description="Agente B (Traductor): convierte JSON de metadatos TikTok a CSV estructurado para dataset."
    )
    parser.add_argument(
        "--input-json",
        required=True,
        help="Ruta al JSON de entrada (metadatos_ia de views.py o salida JSON de yt-dlp).",
    )
    parser.add_argument(
        "--output",
        default=str(Path(__file__).resolve().parent / "dataset" / "video_metadata_new.csv"),
        help="Ruta del CSV de salida (por defecto: agente_B/dataset/video_metadata_new.csv)",
    )
    args = parser.parse_args()

    try:
        # Cargar el JSON de metadatos desde archivo
        metadatos_ia = load_metadatos_json_from_file(Path(args.input_json))
        
        # Convertir a DataFrame de entrenamiento
        training_df = normalize_training_metadata(metadatos_ia)
        
        # Guardar en CSV (append si existe, crear si no)
        save_dataset(training_df, Path(args.output))
        
    except Exception as exc:
        print(f"Fallo en Agente B: {exc}", file=sys.stderr)
        return 1

    print(f"Dataset CSV guardado correctamente en: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
