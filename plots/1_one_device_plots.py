import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import warnings
import os

warnings.filterwarnings("ignore", category=matplotlib.MatplotlibDeprecationWarning)

# --- GŁÓWNA KONFIGURACJA ---
# CSV_FILE_PATH = '1_benchmark_pixel.csv'
# DEVICE_MODEL = 'Pixel 8 Pro'
# OUTPUT_DIR = "2_wykresy_pixel"
CSV_FILE_PATH = '1_benchmark_g2_mini.csv'
DEVICE_MODEL = 'LG G2 mini'
OUTPUT_DIR = "2_wykresy_lg"

# -----------------------------

def load_and_clean_data(filepath):
    """Wczytuje i czyści dane z pliku CSV."""
    try:
        df = pd.read_csv(filepath, sep=';', skip_blank_lines=True)
        df.columns = df.columns.str.strip()
        implementation_raw = df['Implementation'].str.split('.').str[-1]
        implementation_map = {'ffi': 'FFI', 'platformChannel': 'Platform Channel', 'dart': 'Dart'}
        df['Implementation'] = implementation_raw.map(implementation_map)
        algorithm_raw = df['Algorithm'].str.split('.').str[-1]
        algorithm_map = {'aesGcm': 'AES-GCM 256', 'chaChaPoly': 'ChaCha20-Poly1305'}
        df['Algorithm'] = algorithm_raw.map(algorithm_map)
        df['DataSize_KB'] = (df['DataSize_B'] / 1024).astype(int)
        df['DataSize_MB'] = df['DataSize_B'] / 1024 / 1024
        df['WallTime_Avg_ms'] = df['WallTime_Sum_ms'] / df['Iterations']
        df['CPUTime_Avg_ms'] = df['CPUTime_ms'] / df['Iterations']
        print("✅ Dane wczytane i przetworzone pomyślnie.")
        return df
    except FileNotFoundError:
        print(f"❌ BŁĄD: Nie znaleziono pliku '{filepath}'.")
        return None


# ========== ZESTAW FUNKCJI DO TWORZENIA WYKRESÓW ==========

### ZMIANA: Modyfikacja funkcji, aby zapisywały I pokazywały pliki ###

def plot_throughput(df, algorithm_name, device_model):
    """1. Generuje, zapisuje i pokazuje wykres przepustowości (MB/s)."""
    print(f"-> Generowanie wykresu PRZEPUSTOWOŚCI dla: {algorithm_name}...")
    df_filtered = df[df['Algorithm'] == algorithm_name].copy()
    df_filtered['Throughput_MBs'] = df_filtered['DataSize_MB'] / (df_filtered['WallTime_Avg_ms'] / 1000)
    pivot = df_filtered.pivot_table(index='DataSize_KB', columns='Implementation', values='Throughput_MBs')[
        ['FFI', 'Platform Channel', 'Dart']]
    ax = pivot.plot(kind='bar', figsize=(14, 8), grid=True, rot=0)
    chart_title = f'Średnia przepustowość dla algorytmu: {algorithm_name}\nUrządzenie: {device_model}'
    ax.set_title(chart_title, fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel("Rozmiar danych (KB)")
    ax.set_ylabel("Przepustowość (MB/s)")
    plt.tight_layout()
    filename = os.path.join(OUTPUT_DIR, f"1_przepustowosc_{algorithm_name.lower()}.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()


def plot_overhead_vs_ffi(df, algorithm_name, device_model):
    """2. Generuje, zapisuje i pokazuje wykres narzutu procentowego względem FFI."""
    print(f"-> Generowanie wykresu NARZUTU WZGLĘDEM FFI dla: {algorithm_name}...")
    df_filtered = df[df['Algorithm'] == algorithm_name].copy()
    pivot_time = df_filtered.pivot_table(index='DataSize_KB', columns='Implementation', values='WallTime_Avg_ms')
    pivot_time['Overhead_PC_%'] = (pivot_time['Platform Channel'] / pivot_time['FFI'] - 1) * 100
    pivot_time['Overhead_Dart_%'] = (pivot_time['Dart'] / pivot_time['FFI'] - 1) * 100
    ax = pivot_time[['Overhead_PC_%', 'Overhead_Dart_%']].plot(kind='bar', figsize=(14, 8), grid=True, rot=0)
    chart_title = f'Procentowy narzut średniego czasu wykonania względem FFI ({algorithm_name})\nUrządzenie: {device_model}'
    ax.set_title(chart_title, fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel("Rozmiar danych (KB)")
    ax.set_ylabel("Narzut względem FFI (%)")
    plt.tight_layout()
    filename = os.path.join(OUTPUT_DIR, f"2_narzut_vs_ffi_{algorithm_name.lower()}.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()


def plot_cpu_efficiency(df, algorithm_name, device_model):
    """3. Generuje, zapisuje i pokazuje wykres efektywności CPU."""
    print(f"-> Generowanie wykresu EFEKTYWNOŚCI CPU dla: {algorithm_name}...")
    df_filtered = df[df['Algorithm'] == algorithm_name].copy()
    df_filtered['CPU_Efficiency_%'] = (df_filtered['CPUTime_Avg_ms'] / df_filtered['WallTime_Avg_ms']) * 100
    pivot = df_filtered.pivot_table(index='DataSize_KB', columns='Implementation', values='CPU_Efficiency_%')[
        ['FFI', 'Platform Channel', 'Dart']]
    ax = pivot.plot(kind='line', marker='o', figsize=(14, 8), grid=True)
    chart_title = f'Efektywność CPU ({algorithm_name})\nUrządzenie: {device_model}'
    ax.set_title(chart_title, fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel("Rozmiar danych (KB)")
    ax.set_ylabel("Efektywność CPU (%)")
    plt.tight_layout()
    filename = os.path.join(OUTPUT_DIR, f"3_efektywnosc_cpu_{algorithm_name.lower()}.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()


def plot_algorithm_comparison(df, implementation_name, device_model):
    """4. Generuje, zapisuje i pokazuje wykres porównujący algorytmy dla danej implementacji."""
    print(f"-> Generowanie wykresu PORÓWNANIA ALGORYTMÓW dla: {implementation_name}...")
    df_filtered = df[df['Implementation'] == implementation_name].copy()
    pivot = df_filtered.pivot_table(index='DataSize_KB', columns='Algorithm', values='WallTime_Avg_ms')
    ax = pivot.plot(kind='bar', figsize=(12, 7), grid=True, rot=0)
    chart_title = f'Porównanie algorytmów dla implementacji: {implementation_name.upper()}\nUrządzenie: {device_model}'
    ax.set_title(chart_title, fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel("Rozmiar danych [KB]")
    ax.set_ylabel("Średni czas operacji [ms]")
    plt.tight_layout()
    filename = os.path.join(OUTPUT_DIR, f"4_porownanie_algorytmow_{implementation_name.replace(' ', '_').lower()}.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()


# --- GŁÓWNA CZĘŚĆ SKRYPTU ---
if __name__ == "__main__":
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"📂 Utworzono katalog: {OUTPUT_DIR}")

    df_main = load_and_clean_data(CSV_FILE_PATH)
    if df_main is not None:
        unique_implementations = ['FFI', 'Platform Channel', 'Dart']
        unique_algorithms = df_main['Algorithm'].unique()
        for algo in unique_algorithms:
            plot_throughput(df_main, algo, DEVICE_MODEL)
            plot_overhead_vs_ffi(df_main, algo, DEVICE_MODEL)
            plot_cpu_efficiency(df_main, algo, DEVICE_MODEL)
        for impl in unique_implementations:
            plot_algorithm_comparison(df_main, impl, DEVICE_MODEL)
        print("\n✅ Wszystkie wykresy zostały wygenerowane.")