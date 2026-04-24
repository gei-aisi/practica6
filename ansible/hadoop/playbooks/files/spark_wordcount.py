from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, split, col, lower, regexp_replace
import matplotlib.pyplot as plt
import sys
import os
import time
import socket

if len(sys.argv) < 3:
    print("Error: Faltan argumentos.")
    print("Uso: spark-submit script.py <ruta_entrada_hdfs> <ruta_salida_hdfs>")
    sys.exit(1)

input_path = sys.argv[1]
output_path = sys.argv[2]
base_name = os.path.basename(input_path).split('.')[0]
spark = SparkSession.builder.appName(f"SparkWordCount_{base_name}").getOrCreate()
spark.sparkContext.setLogLevel("ERROR")

try:
    print("\n" + "="*50)
    print(f"Iniciando procesamiento: {input_path}")
    
    # --- INICIO DEL TIEMPO ---
    start_time = time.time()

    # Leer el fichero
    df = spark.read.text(input_path)

    # Procesamiento (Limpieza y filtrado)
    stop_words = ["sus", "o", "al", "con", "lo", "le", "me", "mi", "su", "de", 
                  "la", "que", "el", "en", "y", "a", "los", "del", "se", "las", 
                  "por", "un", "una", "es", "no", "más", "como", "dijo", "su",
                  "si", "ni", "sin", "tan", "ha", "para"]

    words = df.select(
        explode(
            split(regexp_replace(lower(col("value")), r'[^\w\s]', ''), r'\s+')
        ).alias("word")
    ).filter(col("word") != "")

    resultado = words.filter(~col("word").isin(stop_words)) \
                     .groupBy("word") \
                     .count() \
                     .withColumn("count", (col("count") / 400).cast("int")) \
                     .orderBy(col("count").desc())

    # Ejecutar y guardar (Acciones que disparan el trabajo en los Workers)
    # Importante: Spark es "lazy", si no hacemos una acción, el cronómetro no medirá nada real
    resultado.write.mode("overwrite").parquet(output_path)
    
    # --- FIN DEL TIEMPO ---
    end_time = time.time()
    
    duration = end_time - start_time

    # Resultados
    print("="*50)
    print("¡Proceso completado!")
    print(f"Tiempo de procesamiento: {duration:.2f} segundos")
    print(f"Salida: {output_path}")
    print("="*50 + "\n")
    print(f"Top 10 palabras:")
    resultado.show(10)
    print("="*50)

    # --- GENERACIÓN DEL GRÁFICO ---
    print("Generando gráfico del Top 20...")    
    # Pasamos solo las 20 primeras filas a la memoria local de Python (Pandas)
    top_20 = resultado.limit(20).toPandas()
    hostname_actual = socket.gethostname()
    plt.figure(figsize=(12, 7))
    plt.bar(top_20['word'], top_20['count'], color='skyblue')
    plt.xlabel('Palabra')
    plt.ylabel('Frecuencia')
    plt.title(f'Top 20 en {base_name}  (filtradas) \n(Generado por: {hostname_actual})')
    plt.xticks(rotation=45)
    plt.tight_layout() # Evita que las palabras largas de abajo se corten en la imagen

    # Guardar en la máquina local (Master)
    ruta_imagen = f'/home/hadoop/grafico_{base_name}.png'
    plt.savefig(ruta_imagen)
    print(f"¡Gráfico generado en {ruta_imagen} por {hostname_actual}!")
    print("="*50)
    
except Exception as e:
    print(f"Error: {e}")

finally:
    spark.stop()

