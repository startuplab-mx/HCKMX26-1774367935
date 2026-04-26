from model import NarcoContentClassifier
import os

def main():
    print("==================================================")
    print(">>> INICIANDO ENTRENAMIENTO DEL MODELO DE ML <<<")
    print("==================================================")
    
    print("\n[1/3] Preparando la arquitectura del modelo...")
    clasificador = NarcoContentClassifier()
    dataset_csv = "dataset_10k.csv"
    
    if not os.path.exists(dataset_csv):
        print(f"\nError: No se encontró el archivo '{dataset_csv}'.")
        return
        
    print(f"\n[2/3] Leyendo '{dataset_csv}' y entrenando el modelo...")
    print("Esto puede tardar unos segundos, por favor espera...\n")
    
    clasificador.train_from_csv(dataset_csv)
    
    print("\n==================================================")
    print(">>> ENTRENAMIENTO COMPLETADO Y GUARDADO <<<")
    print("==================================================")


if __name__ == "__main__":
    main()
