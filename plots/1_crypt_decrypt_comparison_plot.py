import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np
import warnings
import os

# Ignoruj ostrzeżenia o przestarzałych funkcjach
warnings.filterwarnings("ignore", category=matplotlib.MatplotlibDeprecationWarning)

# --- GŁÓWNA KONFIGURACJA ---
FILES_TO_COMPARE = {
    'Google Pixel 8 pro': '1_benchmark_pixel.csv',
}
OUTPUT_DIR = "2_wykresy_pixel"


# -----------------------------

def load_and_combine_data(file_mapping):
    """Wczytuje i łączy dane, obliczając średnie czasy operacji."""
    all_dataframes = []
    print("--- Rozpoczynam wczytywanie i przetwarzanie plików ---")
    for device_name, filepath in file_mapping.items():
        try:
            df = pd.read_csv(filepath, sep=';', skip_blank_lines=True)
            df.columns = df.columns.str.strip()

            # Mapowanie implementacji
            implementation_raw = df['Implementation'].str.split('.').str[-1]
            implementation_map = {'ffi': 'FFI', 'platformChannel': 'Platform Channel', 'dart': 'Dart'}
            df['Implementation'] = implementation_raw.map(implementation_map)

            # Mapowanie algorytmów
            algorithm_raw = df['Algorithm'].str.split('.').str[-1]
            algorithm_map = {'aesGcm': 'AES-GCM 256', 'chaChaPoly': 'ChaCha20-Poly1305'}
            df['Algorithm'] = algorithm_raw.map(algorithm_map)

            df['DataSize_KB'] = (df['DataSize_B'] / 1024).astype(int)
            df['Device'] = device_name

            # Obliczenie średnich czasów dla szyfrowania i deszyfrowania
            df['Encrypt_Avg_ms'] = df['WallTime_Encrypt_ms'] / df['Iterations']
            df['Decrypt_Avg_ms'] = df['WallTime_Decrypt_ms'] / df['Iterations']

            all_dataframes.append(df)
            print(f"✅ Pomyślnie wczytano: {filepath}")
        except FileNotFoundError:
            print(f"❌ OSTRZEŻENIE: Pominięto plik '{filepath}'.")
    if not all_dataframes: return None
    print("------------------------------------------------------\n")
    return pd.concat(all_dataframes, ignore_index=True)


# ========== POPRAWIONA FUNKCJA DO TWORZENIA WYKRESU ==========

def plot_simplified_comparison(df):
    """
    Generuje jeden zbiorczy wykres porównujący czasy szyfrowania i deszyfrowania
    z dwiema, czytelnymi legendami.
    """
    print(f"-> Generowanie zbiorczego wykresu Szyfrowanie vs Deszyfrowanie...")

    fig, ax = plt.subplots(figsize=(16, 9))

    # Sortowanie numeryczne, aby kategorie na osi X były we właściwej kolejności.
    df = df.sort_values('DataSize_KB')
    # Konwersja na typ tekstowy, aby Matplotlib potraktował oś X jako kategoryczną.
    df['DataSize_KB'] = df['DataSize_KB'].astype(str)

    df['Series'] = df['Algorithm'] + ' - ' + df['Implementation']

    unique_series = sorted(df['Series'].unique())

    for series_name in unique_series:
        df_series = df[df['Series'] == series_name]
        if df_series.empty:
            continue

        line, = ax.plot(df_series['DataSize_KB'], df_series['Encrypt_Avg_ms'], marker='o', linestyle='-',
                        label=series_name)
        color = line.get_color()
        ax.plot(df_series['DataSize_KB'], df_series['Decrypt_Avg_ms'], marker='x', linestyle='--', color=color)

    # Ustawianie tytułów i etykiet
    chart_title = 'Porównanie wydajności operacji szyfrowania i deszyfrowania'
    ax.set_title(chart_title, fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel("Rozmiar danych (KB)", fontsize=12)
    ax.set_ylabel("Średni czas operacji (ms)", fontsize=12)
    ax.grid(True)
    plt.xticks(rotation=45, ha='right')

    # Tworzenie dwóch oddzielnych legend
    handles, labels = ax.get_legend_handles_labels()

    main_legend = ax.legend(handles, labels, title='Algorytm - Implementacja', bbox_to_anchor=(1.04, 1),
                            loc="upper left")

    legend_elements = [
        Line2D([0], [0], color='black', lw=2, linestyle='-', label='Szyfrowanie'),
        Line2D([0], [0], color='black', lw=2, linestyle='--', marker='x', label='Deszyfrowanie'),
    ]
    ax.legend(handles=legend_elements, loc='upper left')

    ax.add_artist(main_legend)

    fig.subplots_adjust(right=0.7)

    # Zapis i wyświetlenie
    filename = os.path.join(OUTPUT_DIR, "zbiorcze_szyfr_vs_deszyfr_kategoryczny.png")

    ### ZMIANA: Dodanie parametru `bbox_extra_artists`, aby zapisać zewnętrzną legendę ###
    plt.savefig(filename, dpi=150, bbox_extra_artists=(main_legend,), bbox_inches='tight')

    print(f"   -> Zapisano: {filename}")
    plt.show()


# --- GŁÓWNA CZĘŚĆ SKRYPTU ---
if __name__ == "__main__":
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"📂 Utworzono katalog: {OUTPUT_DIR}")

    df_main = load_and_combine_data(FILES_TO_COMPARE)

    if df_main is not None:
        plot_simplified_comparison(df_main)
        print("\n✅ Wykres został wygenerowany.")