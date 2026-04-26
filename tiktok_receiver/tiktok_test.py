#!/usr/bin/env python3
"""
Script de ejemplo para probar el endpoint POST de recibir TikTok.
Uso: python tiktok_test.py <url_tiktok>
"""

import requests
import json
import sys

BASE_URL = "http://localhost:8000"
ENDPOINT = f"{BASE_URL}/api/tiktok/recibir/"

def procesar_tiktok(url_tiktok):
    """
    Envía una URL de TikTok al endpoint para su procesamiento.
    """
    payload = {
        "url": url_tiktok,
        "titulo": "Video descargado desde script",
        "descripcion": "Procesado automáticamente"
    }
    
    print(f"📤 Enviando POST a {ENDPOINT}")
    print(f"📹 URL del TikTok: {url_tiktok}")
    print("-" * 80)
    
    try:
        response = requests.post(
            ENDPOINT,
            json=payload,
            timeout=120  # 2 minutos de timeout para yt-dlp
        )
        
        print(f"✅ Status Code: {response.status_code}")
        print("-" * 80)
        
        data = response.json()
        
        # Mostrar respuesta formateada
        print(json.dumps(data, indent=2, ensure_ascii=False))
        print("-" * 80)
        
        if data.get('success'):
            print("\n✅ Procesamiento exitoso!")
            if data.get('resultado_procesamiento'):
                print("\n📊 Metadata extraída:")
                metadata = data['resultado_procesamiento']
                for key, value in metadata.items():
                    if value is not None:
                        print(f"  • {key}: {value}")
        else:
            print("\n❌ Error en el procesamiento")
            
    except requests.exceptions.Timeout:
        print("❌ Timeout: La descarga tardó más de 2 minutos")
    except requests.exceptions.ConnectionError:
        print("❌ Error: No se puede conectar al servidor")
        print(f"   Asegúrate de que Django está corriendo en {BASE_URL}")
    except Exception as e:
        print(f"❌ Error: {str(e)}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Usar URL de ejemplo si no se proporciona argumento
        print("Uso: python tiktok_test.py <url_tiktok>")
        print("\nEjemplo:")
        print("python tiktok_test.py https://www.tiktok.com/@usuario/video/123456789")
        print("\nUsando URL de ejemplo...")
        url = "https://www.tiktok.com/@webcamsdemexico/video/7628412115493162258"
    else:
        url = sys.argv[1]
    
    procesar_tiktok(url)
