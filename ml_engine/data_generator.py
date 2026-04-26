import random
import pandas as pd
import uuid

# Importar los diccionarios masivos desde el modelo
try:
    from model import NARCO_KEYWORDS, NARCO_EMOJIS, NARCO_ARTISTS
except ImportError:
    print("Asegúrate de ejecutar este script dentro de la carpeta ml_engine")
    exit(1)

# Diccionarios para contenido "Normal" (Negativo - Etiqueta 0)
NORMAL_KEYWORDS = [
    "receta", "maquillaje", "escuela", "tarea", "perrito", "gato", "mascota", "viaje", 
    "vacaciones", "familia", "amigos", "fiesta", "cumpleaños", "outfit", "grwm", 
    "comedia", "broma", "challenge", "baile", "trend", "gym", "rutina", "skincare", 
    "comida", "restaurante", "cine", "pelicula", "serie", "anime", "videojuego", 
    "gamer", "stream", "humor", "risas", "amor", "novio", "novia", "crush", "haul",
    "compras", "unboxing", "review", "tutorial", "tips", "hacks", "vlog", "diario",
    "ropa", "moda", "aesthetic", "coquette", "aesthetic", "chill", "relax", "estudio",
    "universidad", "prepa", "trabajo", "oficina", "jefe", "compañeros", "viernes", "lunes"
]
NORMAL_EMOJIS = [
    "😊", "😂", "🥰", "😍", "🥺", "😭", "✨", "❤️", "💖", "💕", "💅", "💄", "👗", "🐶", "🐱", 
    "🍕", "🍔", "🍟", "🍣", "🍦", "☕", "🎮", "📚", "✈️", "🏖️", "🎉", "🎂", "💪", "🏋️‍♀️", 
    "🎧", "🎬", "📱", "💻", "🧸", "🎀", "☀️", "🌙", "🌻", "🌸"
]
NORMAL_ARTISTS = [
    "taylor swift", "bad bunny", "karol g", "duki", "bizarrap", "feid", "young miko", 
    "rosalia", "rauw alejandro", "shakira", "bts", "blackpink", "harry styles", 
    "the weeknd", "ariana grande", "luis miguel", "morat", "sebastián yatra", "camilo",
    "kenia os", "danna paola", "belinda", "maluma", "j balvin"
]

def generate_text(keywords, emojis, is_narco=False):
    """Genera descripciones y títulos combinando palabras al azar."""
    num_words = random.randint(3, 8)
    words = random.sample(keywords, min(num_words, len(keywords)))
    
    # Añadir algunas palabras conectoras básicas para darle un poco de estructura
    connectors = ["aqui", "con", "el", "la", "los", "las", "puro", "siempre", "hoy", "un", "una"]
    text_parts = []
    for w in words:
        if random.random() > 0.5:
            text_parts.append(random.choice(connectors))
        text_parts.append(w)
        
    num_emojis = random.randint(0, 3)
    emojis_str = " ".join(random.sample(emojis, min(num_emojis, len(emojis))))
    
    text = " ".join(text_parts) + " " + emojis_str
    return text.strip()

def generate_hashtags(keywords):
    num_tags = random.randint(1, 5)
    tags = random.sample(keywords, min(num_tags, len(keywords)))
    return " ".join([f"#{t.replace(' ', '')}" for t in tags])

def generate_dataset(num_records=10000):
    records = []
    
    print(f"Generando {num_records} registros sintéticos...")
    for i in range(num_records):
        is_narco = random.choice([True, False])
        
        # Seleccionar fuentes de datos según la etiqueta
        if is_narco:
            kw = NARCO_KEYWORDS
            em = NARCO_EMOJIS
            ar = NARCO_ARTISTS
            label = 1
        else:
            kw = NORMAL_KEYWORDS
            em = NORMAL_EMOJIS
            ar = NORMAL_ARTISTS
            label = 0
            
        # Generar texto
        titulo = generate_text(kw, em, is_narco)
        descripcion = generate_text(kw, em, is_narco)
        hashtags = generate_hashtags(kw)
        
        # Audio
        artist = random.choice(ar) if random.random() > 0.3 else ""
        
        # Comentarios
        comentarios = []
        num_comments = random.randint(0, 4)
        for _ in range(num_comments):
            comentarios.append(generate_text(kw, em, is_narco))
        comentarios_str = " | ".join(comentarios)
        
        # Engagement (asumimos que el contenido polémico/narco puede tener ligeramente más viralidad, pero lo mantenemos mixto)
        if is_narco and random.random() > 0.5:
            vistas = random.randint(10000, 5000000)
        else:
            vistas = random.randint(100, 1000000)
            
        likes = int(vistas * random.uniform(0.05, 0.2))
        comentarios_totales = int(likes * random.uniform(0.01, 0.1))
        compartidos = int(likes * random.uniform(0.02, 0.15))
        
        record = {
            "id": str(uuid.uuid4())[:8],
            "titulo": titulo,
            "descripcion": descripcion,
            "hashtags": hashtags,
            "menciones": "",  # Simplificamos dejándolo vacío
            "audio": artist,
            "comentarios_muestra": comentarios_str,
            "etiquetas_contenido": "", 
            "vistas": vistas,
            "likes": likes,
            "comentarios_totales": comentarios_totales,
            "compartidos": compartidos,
            "etiqueta": label
        }
        records.append(record)
        
        if (i+1) % 2000 == 0:
            print(f"{i+1} registros creados...")
            
    df = pd.DataFrame(records)
    output_file = "dataset_10k.csv"
    df.to_csv(output_file, index=False, encoding='utf-8')
    print(f"\n¡Dataset generado exitosamente! Guardado en: {output_file}")
    print(f"Total registros: {len(df)}")
    print(f"Positivos (Narcocultura): {len(df[df['etiqueta'] == 1])}")
    print(f"Negativos (Normal): {len(df[df['etiqueta'] == 0])}")

if __name__ == "__main__":
    generate_dataset(10000)
