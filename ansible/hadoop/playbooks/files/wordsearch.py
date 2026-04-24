import pandas as pd
import sys

if len(sys.argv) < 3:
    print("Error: Faltan argumentos.")
    print("Uso: python3 wordsearch.py <ruta_fichero.parquet> <palabra>")
    sys.exit(1)

ruta_parquet = sys.argv[1]
palabra_buscada = sys.argv[2].lower() 

print(f"\n>>> Buscando '{palabra_buscada}' en {ruta_parquet}...")

try:
    # Leemos el Parquet (Pandas usa PyArrow por debajo)
    df = pd.read_parquet(ruta_parquet)

    # Filtramos el DataFrame
    resultado = df[df['word'] == palabra_buscada]

    print("-" * 80)
    if not resultado.empty:
        # Extraemos el valor de la columna 'count' de esa fila
        conteo = resultado['count'].values[0]
        print(f"🎯 ¡Encontrada! La palabra '{palabra_buscada}' aparece {conteo} veces.")
    else:
        print(f"⚠️ La palabra '{palabra_buscada}' no se encontró en el texto.")
    print("-" * 80)

except Exception as e:
    print(f"Error al leer el fichero: {e}")
