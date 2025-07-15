import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import warnings
import os

# Ignoruj ostrzeżenia o przestarzałych funkcjach
warnings.filterwarnings("ignore", category=matplotlib.MatplotlibDeprecationWarning)

# --- GŁÓWNA KONFIGURACJA ---
#
# 👇 ZMIEŃ TĘ LINIĘ, aby wczytać inny plik
# CSV_FILE_PATH = '1_benchmark_pixel.csv'
# DEVICE_MODEL = 'Google Pixel 8 Pro'
# OUTPUT_DIR = "2_wykresy_pixel"
# 👇 ZMIEŃ TĘ LINIĘ, aby wczytać inny plik
CSV_FILE_PATH = '1_benchmark_g2_mini.csv'
DEVICE_MODEL = 'LG G2 mini'
OUTPUT_DIR = "2_wykresy_lg"


# -----------------------------

def load_and_clean_data(filepath):
    """Wczytuje i czyści dane z pliku CSV, zachowując potrzebne kolumny."""
    try:
        df = pd.read_csv(filepath, sep=';', skip_blank_lines=True)
        df.columns = df.columns.str.strip()

        # Mapowanie implementacji
        implementation_raw = df['Implementation'].str.split('.').str[-1]
        implementation_map = {
            'ffi': 'FFI',
            'platformChannel': 'Platform Channel',
            'dart': 'Dart'
        }
        df['Implementation'] = implementation_raw.map(implementation_map)

        # Mapowanie algorytmów
        algorithm_raw = df['Algorithm'].str.split('.').str[-1]
        algorithm_map = {
            'aesGcm': 'AES-GCM 256',
            'chaChaPoly': 'ChaCha20-Poly1305'
        }
        df['Algorithm'] = algorithm_raw.map(algorithm_map)

        df['DataSize_KB'] = (df['DataSize_B'] / 1024).astype(int)

        print("✅ Dane wczytane i przetworzone pomyślnie.")
        return df
    except FileNotFoundError:
        print(f"❌ BŁĄD: Nie znaleziono pliku '{filepath}'.")
        return None


# ========== NOWA FUNKCJA DO TWORZENIA WYKRESU PAMIĘCI ==========

def plot_ram_combined(df, algorithm_name, device_model):
    """
    Generuje, zapisuje i pokazuje połączony wykres zużycia pamięci RAM
    (linia dla średniej, 'x' dla wartości szczytowej).
    """
    print(f"-> Generowanie połączonego wykresu RAM dla: {algorithm_name}...")

    # Filtrowanie danych dla konkretnego algorytmu
    df_filtered = df[df['Algorithm'] == algorithm_name].copy()
    if df_filtered.empty:
        print(f"   -> Brak danych dla algorytmu {algorithm_name}. Pomijam.")
        return

    # Przygotowanie figury i osi
    fig, ax = plt.subplots(figsize=(14, 8))

    # Tabela i wykres liniowy dla średniego zużycia RAM
    pivot_avg = df_filtered.pivot_table(index='DataSize_KB', columns='Implementation', values='RAM_Avg_MB')
    pivot_avg = pivot_avg[['FFI', 'Platform Channel', 'Dart']]
    pivot_avg.plot(kind='line', marker='o', ax=ax, grid=True)

    # Pobranie kolorów z właśnie narysowanych linii
    line_colors = {line.get_label(): line.get_color() for line in ax.get_lines()}

    # Tabela dla szczytowego zużycia RAM
    pivot_peak = df_filtered.pivot_table(index='DataSize_KB', columns='Implementation', values='RAM_Peak_MB')
    pivot_peak = pivot_peak[['FFI', 'Platform Channel', 'Dart']]

    ### ZMIANA 1: Znacznik punktów zmieniony na 'x' ###
    for impl in pivot_peak.columns:
        ax.scatter(pivot_peak.index, pivot_peak[impl], color=line_colors[impl], marker='x', s=100, alpha=0.9, zorder=3,
                   linewidths=1.5)

    ### ZMIANA 2: Aktualizacja tytułu wykresu ###
    chart_title = f'Średnie (linia) i Szczytowe (x) użycie RAM dla: {algorithm_name}\nUrządzenie: {device_model}'
    ax.set_title(chart_title, fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel("Rozmiar danych (KB)", fontsize=12)
    ax.set_ylabel("Użycie pamięci RAM (MB)", fontsize=12)

    ax.legend(title='Implementacja (Średnia)')

    plt.tight_layout()

    # Zapis i wyświetlenie
    safe_algo_name = algorithm_name.replace(' ', '_').lower()
    filename = os.path.join(OUTPUT_DIR, f"ram_combined_{safe_algo_name}.png")
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
        unique_algorithms = df_main['Algorithm'].unique()

        print("\n--- Rozpoczynam generowanie wykresów zużycia pamięci RAM ---")

        for algo in unique_algorithms:
            plot_ram_combined(df_main, algo, DEVICE_MODEL)

        print("\n✅ Wszystkie wykresy pamięci RAM zostały wygenerowane.")