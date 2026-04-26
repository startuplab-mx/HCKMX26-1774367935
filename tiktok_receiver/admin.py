from django.contrib import admin
from .models import TikTokURL


@admin.register(TikTokURL)
class TikTokURLAdmin(admin.ModelAdmin):
    list_display = ('id', 'url_truncado', 'titulo', 'fecha_recibida', 'procesado')
    list_filter = ('fecha_recibida', 'procesado', 'fecha_actualizada')
    search_fields = ('url', 'titulo', 'descripcion')
    readonly_fields = ('fecha_recibida', 'fecha_actualizada')
    fieldsets = (
        ('Información del Link', {
            'fields': ('url', 'titulo', 'descripcion')
        }),
        ('Estado de Procesamiento', {
            'fields': ('procesado', 'resultado_procesamiento')
        }),
        ('Fechas', {
            'fields': ('fecha_recibida', 'fecha_actualizada')
        }),
    )

    def url_truncado(self, obj):
        """Muestra la URL truncada en el listado"""
        return obj.url[:50] + '...' if len(obj.url) > 50 else obj.url
    url_truncado.short_description = 'URL'
