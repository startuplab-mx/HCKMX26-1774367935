from django.test import TestCase, Client
from django.urls import reverse
from unittest.mock import patch
import json


class TikTokReceiverTests(TestCase):
    """Tests para el endpoint de recibir TikTok"""

    def setUp(self):
        self.client = Client()
        self.url_recibir = reverse('tiktok_receiver:recibir_tiktok')
        
        # Metadata simulada de yt-dlp
        self.metadata_simulada = {
            'error': False,
            'data': {
                'id': '7628412115493162258',
                'title': 'Test TikTok Video',
                'uploader': '@testuser',
                'upload_date': '20240101',
                'duration': 15,
                'view_count': 1000,
                'like_count': 500,
                'comment_count': 100
            }
        }

    @patch('tiktok_receiver.views.extraer_metadata_tiktok')
    def test_recibir_tiktok_valido(self, mock_extraer):
        """Test para recibir un TikTok válido y obtener metadatos procesados para IA"""
        # Mockear la función de yt-dlp con metadatos procesados
        metadatos_procesados = {
            'error': False,
            'data': {
                'video': {
                    'id': '7628412115493162258',
                    'titulo': 'Test TikTok Video',
                    'duracion_segundos': 15,
                },
                'creador': {
                    'nombre_usuario': '@testuser',
                },
                'engagement': {
                    'vistas': 1000,
                    'likes': 500,
                    'comentarios_totales': 100,
                },
                'contenido': {
                    'hashtags': ['#test', '#video'],
                },
            }
        }
        mock_extraer.return_value = metadatos_procesados
        
        data = {
            'url': 'https://www.tiktok.com/@usuario/video/123456789',
            'titulo': 'Video Test',
            'descripcion': 'Descripción de prueba'
        }
        response = self.client.post(
            self.url_recibir,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 200)
        response_data = response.json()
        self.assertTrue(response_data['success'])
        # Verificar que los metadatos están presentes
        self.assertIn('metadatos', response_data)
        self.assertIsNotNone(response_data.get('metadatos'))
        # Verificar estructura de metadatos
        self.assertIn('video', response_data['metadatos'])
        self.assertIn('creador', response_data['metadatos'])
        self.assertIn('engagement', response_data['metadatos'])

    def test_recibir_tiktok_sin_url(self):
        """Test para recibir un TikTok sin URL"""
        data = {'titulo': 'Video sin URL'}
        response = self.client.post(
            self.url_recibir,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.json()['success'])

    def test_recibir_url_invalida(self):
        """Test para recibir una URL que no es de TikTok"""
        data = {'url': 'https://www.youtube.com/watch?v=123'}
        response = self.client.post(
            self.url_recibir,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.json()['success'])

    @patch('tiktok_receiver.views.extraer_metadata_tiktok')
    def test_recibir_tiktok_con_error_ytdlp(self, mock_extraer):
        """Test para recibir un TikTok cuando yt-dlp falla"""
        # Mockear un error de yt-dlp
        mock_extraer.return_value = {
            'error': True,
            'mensaje': 'Error descargando video'
        }
        
        data = {
            'url': 'https://www.tiktok.com/@usuario/video/invalid'
        }
        response = self.client.post(
            self.url_recibir,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)
        response_data = response.json()
        self.assertFalse(response_data['success'])
        self.assertIn('Error al procesar', response_data['mensaje'])



