from django.db import models


class TikTokURL(models.Model):
    """Modelo para almacenar URLs de TikTok recibidas"""
    url = models.URLField(unique=True)
    titulo = models.CharField(max_length=500, blank=True, null=True)
    descripcion = models.TextField(blank=True, null=True)
    fecha_recibida = models.DateTimeField(auto_now_add=True)
    fecha_actualizada = models.DateTimeField(auto_now=True)
    procesado = models.BooleanField(default=False)
    resultado_procesamiento = models.JSONField(blank=True, null=True)

    class Meta:
        ordering = ['-fecha_recibida']
        verbose_name = 'TikTok URL'
        verbose_name_plural = 'TikTok URLs'

    def __str__(self):
        return f"TikTok - {self.url[:50]} ({self.fecha_recibida.strftime('%Y-%m-%d %H:%M')})"
