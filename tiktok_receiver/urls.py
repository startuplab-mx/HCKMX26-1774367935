from django.urls import path
from . import views

app_name = 'tiktok_receiver'

urlpatterns = [
    # Endpoint principal
    path('recibir/', views.recibir_tiktok, name='recibir_tiktok'),
]
