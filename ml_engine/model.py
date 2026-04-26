import pandas as pd
import numpy as np
import json
import re
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib

# ====================================================================
# JSON Encoder para tipos numpy
# ====================================================================
class NumpyEncoder(json.JSONEncoder):
    """JSON Encoder que soporta tipos numpy automáticamente"""
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

# ====================================================================
NARCO_KEYWORDS = [
    # Cárteles, facciones y organizaciones
    "cng", "cjng", "cártel de jalisco nueva generación", "cartel de jalisco", "cuatro letras", "4 letras", 
    "cártel de sinaloa", "cartel de sinaloa", "cds", "cártel del golfo", "cartel del golfo", "cdg", 
    "los zetas", "zetas", "cdn", "cártel del noreste", "cártel de juárez", "ncdj", "cártel de tijuana", 
    "arellano félix", "la familia michoacana", "lfm", "los caballeros templarios", "cártel de santa rosa de lima", 
    "csrl", "guerreros unidos", "los rojos", "los viagras", "viagras", "cártel de colima", "cártel de oaxaca", 
    "la unión tepito", "unión tepito", "fuerza anti-unión", "los chapitos", "la chapizza", "chapizza", "pizza", 
    "la mayiza", "mayiza", "los rusos", "rusos", "los ninis", "ninis", "los chimales", "chimales", 
    "los ántrax", "antrax", "brazo armado", "grupo sombra", "gente nueva", "la línea", "la linea", 
    "los mexicles", "los aztecas", "los pelones", "la barredora", "barredora", "empresa", "la empresa", 
    "el cártel", "mafia", "sombreriza", "sombrero", "rs", "la maña", "maña",
    
    # Lideres, alias y figuras
    "el chapo", "chapo", "joaquín guzmán", "jgl", "el mayo", "mayo", "zambada", "mz", "el mencho", 
    "mencho", "nemesio oseguera", "señor de los gallos", "el señor de la montaña", "el guano", "ovídio", 
    "ovidio", "el ratón", "raton", "iván archivaldo", "jesús alfredo", "alfredillo", "el licenciado", 
    "dámaso", "el mini lic", "mini lic", "el azul", "juan josé esparragoza", "el señor de los cielos", 
    "amado carrillo", "rafael caro quintero", "caro quintero", "el narco de narcos", "don neto", 
    "el padrino", "félix gallardo", "osiel cárdenas", "el lazca", "z-1", "z-40", "el marro", "la tuta", 
    "el chayo", "los beltrán leyva", "el botas blancas", "arturo beltrán", "hector beltrán", "el jj", 
    "el chueco", "patrón", "el patron", "jefe de jefes", "el nini", "el piyi", "piyi", "701",
    
    # Armamento, equipo y vehículos
    "cuerno", "cuerno de chivo", "ak47", "ak-47", "ak 47", "r15", "r-15", "ar15", "ar-15", "m16", 
    "barret", "calibre 50", "cincuenta", "tostón", "toston", "m60", "p90", "fn p90", "mp5", "uzi", 
    "glock", "escuadra", "beretta", "colt", "38 super", "super 38", "9mm", "nueve milímetros", "magnum", 
    "revólver", "cuerno de disco", "lanzagranadas", "bazuca", "rpg", "chaleco", "pechera", "blindada", 
    "monstruo", "artillada", "troca", "mamalona", "raptor", "cheyenne", "sierra", "lobos", "tahoe", 
    "suburban", "radio", "frecuencia", "punta", "filo", "fierro", "cohete", "tubo", "plomo", "bala",
    
    # Jerga, verbos y estilo de vida
    "jale", "morrita", "morritas", "plebe", "plebes", "viejón", "viejon", "pariente", "compa", "compadre", 
    "al tiro", "al 100", "al millón", "al millon", "con huevos", "gallo", "buchón", "buchon", "buchona", 
    "buchones", "buchonas", "alucín", "alucin", "alucines", "bélico", "belico", "belicon", "bélicon", 
    "clika", "clica", "sicario", "pistolero", "gatillero", "matón", "halcón", "halcon", "puntero", 
    "manguera", "comando", "levantón", "levanton", "encajuelado", "encobijado", "pozolero", "pozole", 
    "cobro de piso", "extorsión", "secuestro", "topón", "topon", "enfrentamiento", "balacera", "tiroteo", 
    "plomazo", "ejecución", "ejecutado", "narcomanta", "manta", "narcomensaje", "plaza", 
    "calentando la plaza", "alinear", "alineado", "piso", "dar piso", "dar cran", "quebrar", "venadear", 
    "madriza", "tableada", "tablazo", "charola", "charolazo", "mañoso", "culiacanazo", "jueves negro", 
    "sinaloa", "culiacan", "cln", "tj", "tijuana", "jrz", "juarez", "tamaulipas", "michoacan", "jalisco", 
    "zapopan", "guanajuato", "zacatecas", "nuevo laredo", "reynosa", "matamoros", "frontera chica", 
    "pacífico", "triángulo dorado", "sierra", "lavado de dinero", "prestanombres", "lavador", "mula", "burrero",
    
    # Drogas y sustancias
    "perico", "lavada", "blanca", "nieve", "cristal", "crico", "foco", "hielo", "meth", "metanfetamina", 
    "fentanilo", "fenta", "tusi", "polvo rosa", "wato", "mota", "maría", "hierba", "toque", "churro", 
    "porro", "gallito", "bacha", "cocaína", "heroína", "chiva", "goma", "amapola", "marihuana", "tachas", 
    "éxtasis", "mdma", "pastillas", "roche", "clonazepam", "rivotril"
]

NARCO_EMOJIS = [
    # Símbolos directos y cárteles (Chapizza, Gallos, NG, etc)
    "🍕", "🍅", "🦅", "🐔", "🐓", "🦂", "🕸️", "🕷️", "🆖", "💀", "☠️", "🏴‍☠️", "👹", "👺", "😈", "👿", "👻",
    # Armas, violencia y muerte
    "🔫", "🔪", "🗡️", "⚔️", "🪓", "💣", "🧨", "🩸", "棺", "⚰️", "🪦", "🛡️", "🏹", "🩸",
    # Dinero, estatus y estilo de vida
    "💸", "💵", "💴", "💶", "💷", "💰", "💳", "💎", "👑", "🤑", "💯", "🍾", "🥂", "🍻", "🥃", "🧊", 
    " Rolex", "⌚", "🏎️", "🚁", "🛻", "🚙", "🚔", "🚨", "✈️", "🛥️", "🚤", "🤠", "😎", "🤫", "🤐",
    # Sustancias y consumo
    "🌿", "🚬", "❄️", "💊", "🍄", "⛄", "🌨️", "🍬", "🍭", "🧪", "💉", "💨", "👃",
    # Regional y animales frecuentemente usados
    "🇲🇽", "🇺🇸", "🇨🇴", "🐅", "🐆", "🦍", "🦏", "🐘", "🐂", "🐎", "🏇", "🐍", "🐊", "🦇", "🦉", "🐕",
    # Otros símbolos crípticos
    "🖤", "🧹", "📍", "🧿", "🎲", "🎰", "🔥", "⚡", "🛑", "🚫", "☢️", "☣️", "⚠️"
]

NARCO_ARTISTS = [
    # Nueva Ola (Corridos Tumbados / Bélicos / Alucines)
    "peso pluma", "natanael cano", "luis r conriquez", "fuerza regida", "junior h", "grupo arriesgado", 
    "lenin ramirez", "marca mp", "eslabon armado", "victor cibrian", "gabito ballesteros", "chuy montana", 
    "panter belico", "chiquito team band", "yarithza y su esencia", "yahritza y su esencia", "xavi", 
    "danny lux", "conneccion divina", "herencia de patrones", "legado 7", "arsenal efectivo", 
    "fuerza de tijuana", "los de la noria", "los perdidos de sinaloa", "los nuevos rebeldes", 
    "tito torbellino jr", "el fantasma", "los dos carnales", "kanales", "voz de mando", "enigma norteño", 
    "grupo marca registrada", "t3r elemento", "alta consigna", "jorge santa cruz", "diego sierra", 
    "virlan garcia", "cornelio vega jr", "polo gonzalez", "hermanos vega jr", "los chairez", 
    "los gemelos de sinaloa", "los dareyes de la sierra", "grupo frontera", "yahir saldivar",
    
    # Rap Bélico / Makabelico / Hip Hop relacionado
    "makabelico", "el makabelico", "comando exclusivo", "comando lr", "santa fe klan", "cartel de santa", 
    "babo", "millonario", "c-kan", "mc davo", "dharius", "geraa mx", "el de la guitarra", "aleman",
    
    # Clásicos / Exponentes Tradicionales de Narcocorridos
    "los tucanes de tijuana", "chalino sanchez", "el komander", "gerardo ortiz", "calibre 50", 
    "los alegres del barranco", "edicion especial", "ariel camacho", "valentín elizalde", "el gallo de oro", 
    "los tigres del norte", "los cadetes de linares", "ramón ayala", "cornelio reyna", "carlos y josé", 
    "los invasores de nuevo león", "los huracanes del norte", "los plebes del rancho", "ulises chaidez", 
    "tito torbellino", "los buitres de culiacán", "los inquietos del norte", "los cuates de sinaloa", 
    "los tigrillos", "los amables del norte", "los tiranos del norte", "los originales de san juan", 
    "los razos", "grupo cartél", "los capos de méxico", "exterminador", "grupo exterminador", 
    "los morros del norte", "los sierreños", "códice", "fidel rueda", "saúl el jaguar", "el bebeto", 
    "remmy valenzuela", "banda ms", "banda el recodo", "la arrolladora", "julión álvarez", "alfredo olivas", 
    "christian nodal", "carin león", "grupo firme", "eduin caz", "los titanes de durango", "buitres de culiacan", 
    "roberto tapia", "larry hernandez", "régulo caro", "crecer german", "martin castillo", 
    "los traviezos de la sierra", "adriel favela", "javier rosas", "tomas estrada", "omar ruiz", 
    "maximo grado", "revolver cannabis", "codigo fn", "grupo 360", "los nuevos ilegales", 
    "los chavalos de la perla", "los parras", "hijos de garcia", "noel torres", "nene torres", 
    "beto quintanilla", "los hermanos baldenegro", "dueto consentido", "chuy lizarraga", "el mimoso", 
    "luis angel el flaco", "pancho barraza"
]

class NarcoContentClassifier:
    def __init__(self):
        # Columnas numéricas extraídas del engagement
        self.numeric_features = ['vistas', 'likes', 'comentarios_totales', 'compartidos']
        
        # Pipeline de procesamiento de características
        self.preprocessor = ColumnTransformer(
            transformers=[
                ('text', TfidfVectorizer(max_features=5000), 'all_text'),
                ('num', StandardScaler(), self.numeric_features)
            ])
            
        # Pipeline principal con Random Forest
        self.pipeline = Pipeline([
            ('preprocessor', self.preprocessor),
            ('classifier', RandomForestClassifier(n_estimators=100, random_state=42, class_weight='balanced'))
        ])

    def _flatten_metadata(self, item, include_label=False):
        """
        Aplana la estructura anidada de metadatos_ia a un diccionario de 1 nivel 
        con características listas para el modelo.
        """
        # --- Extracción Segura de Engagement ---
        engagement = item.get('engagement') or {}
        vistas = int(engagement.get('vistas') or 0)
        likes = int(engagement.get('likes') or 0)
        comentarios_totales = int(engagement.get('comentarios_totales') or 0)
        compartidos = int(engagement.get('compartidos') or 0)
        
        # --- Extracción Segura de Texto ---
        video = item.get('video') or {}
        titulo = str(video.get('titulo') or "")
        descripcion = str(video.get('descripcion') or "")
        
        contenido = item.get('contenido') or {}
        hashtags = " ".join(contenido.get('hashtags') or [])
        menciones = " ".join(contenido.get('menciones') or [])
        
        audio = item.get('audio') or {}
        audio_text = str(audio) if isinstance(audio, dict) else str(audio or "")
        
        comentarios = item.get('comentarios_muestra') or []
        # Asumiendo que los comentarios pueden ser strings o diccionarios
        comentarios_text = " ".join([str(c) for c in comentarios]) if isinstance(comentarios, list) else str(comentarios)
        
        meta_adicional = item.get('metadatos_adicionales') or {}
        etiquetas = " ".join(meta_adicional.get('etiquetas_contenido') or [])
        
        # Combinamos todo el texto en una sola variable para el TF-IDF
        all_text = f"{titulo} {descripcion} {hashtags} {menciones} {audio_text} {comentarios_text} {etiquetas}".lower()
        
        flat_data = {
            'id': video.get('id', 'desconocido'),
            'vistas': vistas,
            'likes': likes,
            'comentarios_totales': comentarios_totales,
            'compartidos': compartidos,
            'all_text': all_text,
            'raw_item': item # Guardamos la ref al original para la extracción final
        }
        
        # Solo para el conjunto de entrenamiento/mock, podríamos traer la etiqueta en el json
        if include_label:
            flat_data['etiqueta'] = item.get('etiqueta', 0)
            
        return flat_data

    def _prepare_dataframe(self, data_list, is_training=False):
        """Convierte la lista de diccionarios JSON en un DataFrame de Pandas."""
        records = [self._flatten_metadata(item, include_label=is_training) for item in data_list]
        return pd.DataFrame(records)

    def train(self, data_list, save_path='narco_model.pkl'):
        """Entrena el modelo recibiendo una lista de diccionarios formato metadatos_ia."""
        print(f"Preparando {len(data_list)} registros para entrenamiento...")
        df = self._prepare_dataframe(data_list, is_training=True)
        
        X = df[['all_text', 'vistas', 'likes', 'comentarios_totales', 'compartidos']]
        y = df['etiqueta']
        
        # Si el dataset es muy pequeño (como en el ejemplo mock), no haremos split
        if len(df) > 10:
            X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        else:
            X_train, X_test, y_train, y_test = X, X, y, y
        
        print("Entrenando el modelo...")
        self.pipeline.fit(X_train, y_train)
        
        print("Evaluando el modelo:")
        y_pred = self.pipeline.predict(X_test)
        print(classification_report(y_test, y_pred, zero_division=0))
        
        joblib.dump(self.pipeline, save_path)
        print(f"Modelo guardado exitosamente en {save_path}")

    def train_from_csv(self, csv_path, save_path='narco_model.pkl'):
        """Entrena el modelo directamente desde un archivo CSV con 10,000 registros."""
        print(f"Cargando dataset desde {csv_path}...")
        df_raw = pd.read_csv(csv_path)
        
        # Limpiar y rellenar nulos solo en columnas de texto
        text_cols = ['titulo', 'descripcion', 'hashtags', 'menciones', 'audio', 'comentarios_muestra', 'etiquetas_contenido']
        for col in text_cols:
            if col in df_raw.columns:
                df_raw[col] = df_raw[col].fillna('')
        
        # Combinar columnas de texto simulando el aplanamiento
        df_raw['all_text'] = (
            df_raw['titulo'].astype(str) + " " + 
            df_raw['descripcion'].astype(str) + " " + 
            df_raw['hashtags'].astype(str) + " " + 
            df_raw['menciones'].astype(str) + " " + 
            df_raw['audio'].astype(str) + " " + 
            df_raw['comentarios_muestra'].astype(str) + " " + 
            df_raw['etiquetas_contenido'].astype(str)
        ).str.lower()
        
        for col in self.numeric_features:
            df_raw[col] = pd.to_numeric(df_raw[col], errors='coerce').fillna(0)
            
        X = df_raw[['all_text', 'vistas', 'likes', 'comentarios_totales', 'compartidos']]
        y = pd.to_numeric(df_raw['etiqueta'], errors='coerce').fillna(0)
        
        print("Dividiendo dataset en Train/Test...")
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        print("Entrenando el modelo RandomForest...")
        self.pipeline.fit(X_train, y_train)
        
        print("Evaluando el modelo:")
        y_pred = self.pipeline.predict(X_test)
        print(classification_report(y_test, y_pred, zero_division=0))
        
        joblib.dump(self.pipeline, save_path)
        print(f"Modelo guardado exitosamente en {save_path}")

    def load_model(self, model_path='narco_model.pkl'):
        """Carga un modelo previamente entrenado."""
        self.pipeline = joblib.load(model_path)
        print(f"Modelo cargado desde {model_path}")

    def _extract_resources(self, flat_row):
        """Extrae los recursos usados a partir del texto procesado."""
        all_text = flat_row['all_text']
        
        # Extraer usando regex para palabras completas (evitar que "pizza" coincida dentro de "apizzaco")
        found_keywords = [word for word in NARCO_KEYWORDS if re.search(rf'\b{word}\b', all_text)]
        found_emojis = [emoji for emoji in NARCO_EMOJIS if emoji in all_text]
        found_artists = [artist for artist in NARCO_ARTISTS if artist in all_text]
        
        return {
            "simbologias_y_textos": list(set(found_keywords)),
            "emojis": list(set(found_emojis)),
            "artistas": list(set(found_artists))
        }

    def _has_narco_indicators(self, flat_row):
        """
        ESTRATEGIA HÍBRIDA: Verifica si el contenido tiene INDICADORES REALES de narcocultura.
        
        Si NO hay palabras clave, emojis, o artistas narco → NO es narcocultura (falso positivo).
        Solo confía en la predicción del modelo SI hay contenido narco detectado.
        
        Args:
            flat_row: fila procesada del dataframe
            
        Returns:
            dict: {"has_narco": bool, "indicators": dict}
        """
        recursos = self._extract_resources(flat_row)
        
        # Contar indicadores encontrados
        num_keywords = len(recursos.get("simbologias_y_textos", []))
        num_emojis = len(recursos.get("emojis", []))
        num_artists = len(recursos.get("artistas", []))
        
        total_indicators = num_keywords + num_emojis + num_artists
        
        has_narco = total_indicators > 0
        
        return {
            "has_narco": has_narco,
            "indicators": recursos,
            "total_count": total_indicators
        }

    def predict_and_extract(self, data_list):
        """
        ESTRATEGIA HÍBRIDA:
        1. Si el video tiene palabras/emojis/artistas narco → confiar en la predicción del modelo
        2. Si NO tiene indicadores narco → marcar como NO narcocultura (evita falsos positivos)
        
        Recibe una lista de diccionarios (metadatos_ia), predice su clase 
        y devuelve un JSON con la estructura requerida.
        """
        df = self._prepare_dataframe(data_list)
        X = df[['all_text', 'vistas', 'likes', 'comentarios_totales', 'compartidos']]
        
        predictions = self.pipeline.predict(X)
        probabilities = self.pipeline.predict_proba(X)[:, 1] # Prob de clase 1
        
        results = []
        
        for idx, (is_narco, prob) in enumerate(zip(predictions, probabilities)):
            flat_row = df.iloc[idx]
            original_item = data_list[idx]
            video_id = original_item.get('video', {}).get('id', 'desconocido')
            
            # Aplicar lógica híbrida: verificar indicadores reales de narcocultura
            narco_check = self._has_narco_indicators(flat_row)
            has_narco_content = narco_check['has_narco']
            recursos = narco_check['indicators']
            
            # LÓGICA DE DECISIÓN:
            # Si NO tiene indicadores narco reales → marcar como False (no narco)
            # Si tiene indicadores narco → confiar en la predicción del modelo
            if not has_narco_content:
                # Sin palabras/emojis/artistas narco = NO es narcocultura
                results.append({
                    "id_video": video_id,
                    "es_narcocultura": False,
                    "confianza_modelo": 0.0,
                    "recursos_detectados": None
                })
            elif is_narco == 1:
                # Tiene indicadores narco Y la predicción dice narco
                results.append({
                    "id_video": video_id,
                    "es_narcocultura": True,
                    "confianza_modelo": round(float(prob), 4),
                    "recursos_detectados": recursos,
                    "metricas_viralidad": {
                        "vistas": flat_row['vistas'],
                        "likes": flat_row['likes'],
                        "comentarios_totales": flat_row['comentarios_totales'],
                        "compartidos": flat_row['compartidos']
                    }
                })
            else:
                # Tiene indicadores narco PERO la predicción dice que no es narco
                # Confiar en los indicadores reales (son mejor evidencia que el modelo)
                results.append({
                    "id_video": video_id,
                    "es_narcocultura": True,
                    "confianza_modelo": round(float(1 - prob), 4),  # Invertir confianza
                    "recursos_detectados": recursos,
                    "metricas_viralidad": {
                        "vistas": flat_row['vistas'],
                        "likes": flat_row['likes'],
                        "comentarios_totales": flat_row['comentarios_totales'],
                        "compartidos": flat_row['compartidos']
                    }
                })
                
        return json.dumps(results, indent=4, ensure_ascii=False, cls=NumpyEncoder)


# =========================================================
# BLOQUE DE PRUEBA Y USO
# =========================================================
if __name__ == "__main__":
    classifier = NarcoContentClassifier()
    
    # MOCK DATA: Simulando cómo se vería la lista de metadatos_ia para entrenar
    # NOTA: En entrenamiento necesitamos incluir una llave 'etiqueta' temporal
    mock_training_data = [
        {
            "etiqueta": 1,
            "video": {"id": "v1", "titulo": "Puro cartel", "descripcion": "Aqui andamos al millon 🦅 🔫"},
            "engagement": {"vistas": 150000, "likes": 25000, "comentarios_totales": 1200, "compartidos": 500},
            "contenido": {"hashtags": ["#alucin", "#belico"]},
            "comentarios_muestra": ["puro jgl", "fierro pariente"],
            "metadatos_adicionales": {"etiquetas_contenido": ["weapons"]}
        },
        {
            "etiqueta": 0,
            "video": {"id": "v2", "titulo": "Receta facil", "descripcion": "Pastel de chocolate para la familia"},
            "engagement": {"vistas": 5000, "likes": 200, "comentarios_totales": 15, "compartidos": 2},
            "contenido": {"hashtags": ["#receta", "#postre"]},
            "comentarios_muestra": ["se ve delicioso", "gracias por compartir"],
        },
        {
            "etiqueta": 1,
            "video": {"id": "v3", "titulo": "La chapizza", "descripcion": "Comiendo pizza 🍕 con los plebes"},
            "engagement": {"vistas": 300000, "likes": 50000, "comentarios_totales": 3000, "compartidos": 8000},
            "contenido": {"hashtags": ["#sinaloa", "#pizza"]},
            "comentarios_muestra": ["arriba la chapizza", "con huevos viejo"],
            "audio": {"artist": "peso pluma", "title": "corridos tumbados"}
        },
        {
            "etiqueta": 0,
            "video": {"id": "v4", "titulo": "Outfit para la escuela", "descripcion": "Cual me queda mejor?"},
            "engagement": {"vistas": 12000, "likes": 1500, "comentarios_totales": 30, "compartidos": 10},
            "contenido": {"hashtags": ["#fashion", "#grwm"]},
        }
    ]
    
    # 1. Entrenamos con el formato anidado
    classifier.train(mock_training_data, 'narco_model.pkl')
    
    # 2. Simulamos la llegada de un TikTok nuevo (tal cual lo manda el traductor)
    nuevo_tiktok = {
        'video': {
            'id': '7891234560',
            'titulo': 'Limpiando la plaza 🧹💸',
            'descripcion': 'La barredora no descansa, puro pa adelante',
        },
        'engagement': {
            'vistas': 55000,
            'likes': 12000,
            'comentarios_totales': 890,
            'compartidos': 300,
        },
        'contenido': {
            'hashtags': ['#barredora', '#empresa', '#belicon'],
            'menciones': []
        },
        'audio': {'artist': 'natanael cano', 'title': 'pacas de a kilo'},
        'comentarios_muestra': ['puro fuego', 'animo la barredora', 'saludos al patron'],
        # Simulamos que 'metadatos_adicionales' no viene en este TikTok
    }
    
    print("\n--- Predicción y Extracción del Agente ---")
    # predict_and_extract recibe una lista de diccionarios
    resultado_json = classifier.predict_and_extract([nuevo_tiktok])
    print(resultado_json)
