import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple


def extract_numeric_scores(payload: Any) -> List[float]:
    scores: List[float] = []

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                key_lower = str(key).lower()
                if key_lower in {"score", "probabilidad", "probability", "confidence"}:
                    if isinstance(value, (int, float)):
                        scores.append(float(value))
                    elif isinstance(value, str):
                        try:
                            scores.append(float(value))
                        except ValueError:
                            pass
                walk(value)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(payload)
    return scores


def detect_level_from_text(payload: Any) -> str:
    text = json.dumps(payload, ensure_ascii=False).lower()

    high_terms = ["alto", "high", "severo", "severe", "critico", "critical", "peligro"]
    medium_terms = ["medio", "moderado", "medium", "warning", "advertencia"]
    low_terms = ["bajo", "low", "seguro", "safe"]

    if any(term in text for term in high_terms):
        return "alto"
    if any(term in text for term in medium_terms):
        return "medio"
    if any(term in text for term in low_terms):
        return "bajo"
    return "desconocido"


def infer_risk_level(payload: Any) -> str:
    text_level = detect_level_from_text(payload)
    scores = extract_numeric_scores(payload)

    score_level = "desconocido"
    if scores:
        top_score = max(scores)
        if top_score >= 0.75:
            score_level = "alto"
        elif top_score >= 0.40:
            score_level = "medio"
        else:
            score_level = "bajo"

    priority = {"alto": 3, "medio": 2, "bajo": 1, "desconocido": 0}
    return text_level if priority[text_level] >= priority[score_level] else score_level


def collect_detected_risks(payload: Any) -> List[str]:
    detected: List[str] = []
    candidate_keys = {
        "riesgo_detectado",
        "riesgos",
        "categorias",
        "categorias_riesgo",
        "labels",
        "label",
        "risk_labels",
    }

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                key_lower = str(key).lower()
                if key_lower in candidate_keys:
                    if isinstance(value, str):
                        detected.append(value)
                    elif isinstance(value, list):
                        for item in value:
                            if isinstance(item, str):
                                detected.append(item)
                            elif isinstance(item, dict):
                                for k in ("tipo", "categoria", "label", "name"):
                                    if k in item and isinstance(item[k], str):
                                        detected.append(item[k])
                    elif isinstance(value, dict):
                        for k in ("tipo", "categoria", "label", "name"):
                            if k in value and isinstance(value[k], str):
                                detected.append(value[k])
                walk(value)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(payload)

    # Remove duplicates preserving order.
    unique: List[str] = []
    seen = set()
    for item in detected:
        clean_item = item.strip()
        if clean_item and clean_item.lower() not in seen:
            seen.add(clean_item.lower())
            unique.append(clean_item)

    return unique


def build_recommendation(risk_level: str, risks: List[str]) -> Tuple[str, str, str]:
    risks_text = ", ".join(risks) if risks else "sin categorias explicitas"

    if risk_level == "alto":
        summary = f"Se detecta riesgo ALTO ({risks_text})."
        recommendation = (
            "Bloquear o pausar la reproduccion de este contenido y sugerir una alternativa apta para menores."
        )
        buddy_adjustment = (
            "Buddy debe ajustarse a modo PROTECTOR: tono serio y mensaje preventivo claro para el nino."
        )
    elif risk_level == "medio":
        summary = f"Se detecta riesgo MEDIO ({risks_text})."
        recommendation = (
            "Permitir solo con advertencia y supervision, reforzando reglas de seguridad digital."
        )
        buddy_adjustment = (
            "Buddy debe ajustarse a modo CAUTO: mantener tono amable, con aviso preventivo y guia breve."
        )
    elif risk_level == "bajo":
        summary = f"Se detecta riesgo BAJO ({risks_text})."
        recommendation = "Contenido generalmente apto, mantener monitoreo ligero."
        buddy_adjustment = (
            "Buddy debe ajustarse a modo POSITIVO: tono alegre y recordatorio corto de uso responsable."
        )
    else:
        summary = "No fue posible determinar con claridad el nivel de riesgo."
        recommendation = (
            "Solicitar una nueva clasificacion o aplicar regla conservadora con advertencia preventiva."
        )
        buddy_adjustment = (
            "Buddy debe ajustarse a modo NEUTRAL-PREVENTIVO: mensaje precautorio sin alarmar."
        )

    return summary, recommendation, buddy_adjustment


def generate_report(payload: Dict[str, Any]) -> str:
    # Si payload es lista, analizar todos los videos
    if isinstance(payload, list):
        total = len(payload)
        narco_videos = [v for v in payload if v.get("es_narcocultura") is True]
        normales = [v for v in payload if not v.get("es_narcocultura")]
        narco_count = len(narco_videos)
        normal_count = len(normales)
        conf_narco = [v.get("confianza_modelo", 0) for v in narco_videos]
        conf_normal = [v.get("confianza_modelo", 0) for v in normales]
        avg_conf_narco = sum(conf_narco)/narco_count if narco_count else 0
        avg_conf_normal = sum(conf_normal)/normal_count if normal_count else 0
        # Diagnóstico global
        if narco_count == 0:
            nivel = "bajo"
            resumen = f"No se detectó contenido de narcocultura en {total} videos analizados."
            recomendacion = "Permitir el contenido, mantener monitoreo ligero."
            buddy = "Buddy debe estar en modo POSITIVO: tono alegre y recordatorio de uso responsable."
        elif narco_count == total:
            nivel = "alto"
            resumen = f"Todos los videos ({total}) presentan indicios de narcocultura."
            recomendacion = "Bloquear o pausar la reproducción y sugerir alternativas seguras."
            buddy = "Buddy debe estar en modo PROTECTOR: mensaje preventivo claro y serio."
        else:
            nivel = "medio"
            resumen = f"{narco_count} de {total} videos presentan indicios de narcocultura."
            recomendacion = "Permitir solo con advertencia y supervisión."
            buddy = "Buddy debe estar en modo CAUTO: aviso preventivo y guía breve."
        # Métricas
        metrics = f"Videos narco: {narco_count}/{total} ({narco_count/total*100:.1f}%) | Confianza promedio narco: {avg_conf_narco:.2f} | normal: {avg_conf_normal:.2f}"
        # Ejemplo de riesgos detectados
        riesgos = []
        for v in narco_videos:
            recursos = v.get("recursos_detectados")
            if recursos:
                for k, items in recursos.items():
                    if items:
                        riesgos.extend(items)
        riesgos = list(sorted(set(riesgos)))
        report = [
            f"Nivel de riesgo: {nivel}",
            f"Riesgos detectados: {', '.join(riesgos) if riesgos else 'No especificados'}",
            metrics,
            f"Recomendación: {recomendacion}",
            f"Ajuste Buddy: {buddy}",
            f"Resumen: {resumen}"
        ]
        return "\n".join(report)
    # Si es dict, usar lógica original
    risk_level = infer_risk_level(payload)
    risks = collect_detected_risks(payload)
    summary, recommendation, buddy_adjustment = build_recommendation(risk_level, risks)
    report = [
        f"Nivel de riesgo: {risk_level}",
        f"Riesgos detectados: {', '.join(risks) if risks else 'No especificados'}",
        f"Recomendación: {recommendation}",
        f"Ajuste Buddy: {buddy_adjustment}",
        f"Resumen: {summary}"
    ]
    return "\n".join(report)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Agente D (Interprete): genera diagnostico y ajuste pedagogico para Buddy."
    )
    parser.add_argument("input_json", help="Ruta al JSON de clasificacion previa")
    parser.add_argument(
        "--output",
        default="",
        help="Ruta opcional para guardar el reporte de texto",
    )
    args = parser.parse_args()

    input_path = Path(args.input_json)
    if not input_path.exists() or not input_path.is_file():
        print("Error: el archivo JSON de entrada no existe.", file=sys.stderr)
        return 1

    try:
        payload = json.loads(input_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Error: JSON invalido: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"Error al leer el archivo JSON: {exc}", file=sys.stderr)
        return 1

    report = generate_report(payload)
    print(report)

    # Siempre guardar en Agentes/agente_D/diagnostico_output.txt
    default_output_path = Path(__file__).parent / "diagnostico_output.txt"
    try:
        default_output_path.write_text(report, encoding="utf-8")
    except OSError as exc:
        print(f"Error al guardar el reporte por defecto: {exc}", file=sys.stderr)

    # Si el usuario especifica otra ruta, también guardar ahí
    if args.output:
        output_path = Path(args.output)
        try:
            output_path.write_text(report, encoding="utf-8")
        except OSError as exc:
            print(f"Error al guardar el reporte: {exc}", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    try:
        exit_code = main()
        if exit_code != 0:
            print(f"[AgenteD] Terminó con error (exit code {exit_code})", file=sys.stderr)
    except Exception as e:
        print(f"[AgenteD] Error inesperado: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
print("DEBUG: interprete_diagnostico.py ejecutado")
