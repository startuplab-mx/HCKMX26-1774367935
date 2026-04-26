## ¿Qué es el archivo `narco_model.pkl`?

Es el **modelo ya entrenado y compilado**. Aqui ya procesamos 10,000 registros sintéticos y aprendió todos los patrones de nuestro diccionario masivo de narcocultura.

En producción (y en el endpoint de la API) **NUNCA** llamen a `clasificador.train()`. Solo debemos cargar el `.pkl` a la memoria RAM. La carga toma una fracción de segundo y cada predicción posterior toma milisegundos.

---

## Implementación Paso a Paso en Django

### 1. Ubicación y Dependencias

Asegúrense de que el archivo `narco_model.pkl` y `model.py` estén accesibles para sus vistas de Django.
Verifiquen que el entorno virtual tenga las dependencias instaladas:

```bash
pip install pandas scikit-learn numpy joblib
```

### 2. Código a incluir en la Vista (View) o Servicio

Cuando construyan el endpoint (ej. `POST /api/clasificar/`), utilicen el siguiente bloque de código:

```python
import json
from ml_engine.model import NarcoContentClassifier

# ====================================================================
# A. INICIALIZACIÓN (Hacer esto idealmente al iniciar el server o app)
# ====================================================================
clasificador = NarcoContentClassifier()
clasificador.load_model('ml_engine/narco_model.pkl') # Ruta relativa al pkl

def clasificar_tiktok(request):
    """
    Ejemplo de vista/función que recibe el payload del Agente Traductor.
    """
    # 1. Obtenemos el diccionario/JSON que mandó el Traductor
    # payload_traductor = json.loads(request.body)
  
    # Supongamos que recibimos este diccionario:
    datos_recibidos = {
        "video": {"id": "123", "titulo": "Puro JGL"},
        "engagement": {"vistas": 150000, "likes": 20000},
        "contenido": {"hashtags": ["#chapizza"]},
        "audio": {"artist": "peso pluma"}
    }
  
    # 2. El modelo requiere recibir una LISTA de diccionarios, 
    # incluso si es un solo video, lo envolvemos en []
    lista_datos = [datos_recibidos]

    # 3. Hacemos la predicción mágica
    resultado_json_str = clasificador.predict_and_extract(lista_datos)
  
    # 4. 'resultado_json_str' ya es un JSON validado con todo:
    # - es_narcocultura (True/False)
    # - recursos_detectados (emojis, artistas, textos)
    # - metricas
  
    return resultado_json_str

```

1. **Instancia Global:** Intenten instanciar `NarcoContentClassifier()` y hacer `load_model()` fuera de la función de la vista (ej. en `apps.py` de Django). Así el disco duro no tiene que leer el archivo `.pkl` con cada request, haciéndolo 100x más rápido.


2. **Campos Faltantes:** No se preocupen si un TikTok viene sin descripción o sin métricas. La función interna `_flatten_metadata()` está blindada y pondrá campos vacíos en lugar de romper el servidor.
