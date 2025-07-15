import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import warnings
import os

warnings.filterwarnings("ignore", category=matplotlib.MatplotlibDeprecationWarning)

# --- GŁÓWNA KONFIGURACJA ---
FILES_TO_COMPARE = {
    'LG G2 mini (ARMv7)': '1_benchmark_g2_mini.csv',
    'Samsung S10 (ARMv8)': '1_benchmark_s10.csv',
    'Google Pixel 8 pro (ARMv9)': '1_benchmark_pixel.csv',
}
OUTPUT_DIR = "1_wykresy"

# -----------------------------

def load_and_combine_data(file_mapping):
    """Wczytuje i łączy dane ze wszystkich podanych plików."""
    all_dataframes = []
    print("--- Rozpoczynam wczytywanie i przetwarzanie plików ---")
    for device_name, filepath in file_mapping.items():
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
            df['Device'] = device_name
            df['WallTime_Avg_ms'] = df['WallTime_Sum_ms'] / df['Iterations']
            all_dataframes.append(df)
            print(f"✅ Pomyślnie wczytano: {filepath}")
        except FileNotFoundError:
            print(f"❌ OSTRZEŻENIE: Pominięto plik '{filepath}'.")
    if not all_dataframes: return None
    print("------------------------------------------------------\n")
    return pd.concat(all_dataframes, ignore_index=True)


# ========== ZESTAW FUNKCJI DO TWORZENIA WYKRESÓW ==========

def plot_speedup_vs_dart(df, data_size_kb):
    """1. Zapisuje i pokazuje wykres zysku wydajnościowego względem Darta."""
    print(f"-> Generowanie wykresu ZYSKU WYDAJNOŚCIOWEGO dla: {data_size_kb} KB...")
    df_filtered = df[df['DataSize_KB'] == data_size_kb]
    if df_filtered.empty: return
    pivot = df_filtered.pivot_table(index=['Device', 'Algorithm'], columns='Implementation', values='WallTime_Avg_ms')
    pivot['Zysk FFI'] = pivot['Dart'] / pivot['FFI']
    pivot['Zysk Platform Channel'] = pivot['Dart'] / pivot['Platform Channel']
    pivot_to_plot = pivot[['Zysk FFI', 'Zysk Platform Channel']]

    ### ZMIANA 1: Obrót etykiet na osi X o 45 stopni ###
    ax = pivot_to_plot.plot(kind='bar', figsize=(12, 8), grid=True, rot=45)

    ax.set_title(f'Średni zysk wydajnościowy względem Darta dla danych {data_size_kb} KB', fontsize=16,
                 fontweight='bold', pad=20)
    ax.set_xlabel("Urządzenie / Algorytm", fontsize=12, fontweight='bold')
    ax.set_ylabel("Krotność przyspieszenia [x]", fontsize=12, fontweight='bold')
    ax.legend(title='Metoda szybsza od Darta')
    for container in ax.containers:
        ax.bar_label(container, fmt='%.1fx', label_type='edge', padding=3, fontsize=9)
    ax.margins(y=0.1)

    ### ZMIANA 2: Wyrównanie obróconych etykiet do prawej krawędzi ###
    plt.xticks(ha='right')

    plt.tight_layout()
    filename = os.path.join(OUTPUT_DIR, f"1_zysk_wydajnosci_{data_size_kb}KB.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()


def plot_full_comparison(df, data_size_kb):
    """2. Zapisuje i pokazuje wykres pełnego porównania urządzeń, implementacji i algorytmów."""
    print(f"-> Generowanie PEŁNEGO PORÓWNANIA dla: {data_size_kb} KB...")
    df_filtered = df[df['DataSize_KB'] == data_size_kb]
    if df_filtered.empty: return
    pivot = df_filtered.pivot_table(index=['Device', 'Algorithm'], columns='Implementation', values='WallTime_Avg_ms')
    pivot = pivot[['FFI', 'Platform Channel', 'Dart']]
    ax = pivot.plot(kind='bar', figsize=(16, 9), grid=True, rot=45)
    ax.set_title(f'Pełne porównanie wydajności dla danych o rozmiarze: {data_size_kb} KB', fontsize=18,
                 fontweight='bold', pad=20)
    ax.set_xlabel("Urządzenie / Algorytm", fontsize=12, fontweight='bold')
    ax.set_ylabel("Średni czas operacji [ms]", fontsize=12, fontweight='bold')
    ax.legend(title='Implementacja')
    plt.xticks(ha='right')
    plt.tight_layout()
    filename = os.path.join(OUTPUT_DIR, f"2_pelne_porownanie_{data_size_kb}KB.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()


# <<< NOWA FUNKCJA GENERUJĄCA WYKRES UŚREDNIONY >>>
def plot_average_speedup_vs_dart(df):
    """3. Generuje jeden wykres uśredniający zysk wydajnościowy ze wszystkich rozmiarów danych."""
    print(f"\n-> Generowanie UŚREDNIONEGO wykresu ZYSKU WYDAJNOŚCIOWEGO dla wszystkich danych...")
    if df.empty: return

    # Użyj pivot_table do obliczenia średniego czasu dla każdej kombinacji, agregując wszystkie rozmiary danych
    # aggfunc='mean' jest domyślne, ale dla jasności można je dodać
    pivot = df.pivot_table(index=['Device', 'Algorithm'], columns='Implementation', values='WallTime_Avg_ms',
                           aggfunc=np.mean)

    # Oblicz zysk wydajnościowy na podstawie uśrednionych wartości
    pivot['Zysk FFI'] = pivot['Dart'] / pivot['FFI']
    pivot['Zysk Platform Channel'] = pivot['Dart'] / pivot['Platform Channel']
    pivot_to_plot = pivot[['Zysk FFI', 'Zysk Platform Channel']]

    ax = pivot_to_plot.plot(kind='bar', figsize=(12, 8), grid=True, rot=45)

    ax.set_title(f'Uśredniony zysk wydajnościowy względem Darta (dla wszystkich danych)', fontsize=16,
                 fontweight='bold', pad=20)
    ax.set_xlabel("Urządzenie / Algorytm", fontsize=12, fontweight='bold')
    ax.set_ylabel("Krotność przyspieszenia [x]", fontsize=12, fontweight='bold')
    ax.legend(title='Metoda szybsza od Darta')

    for container in ax.containers:
        ax.bar_label(container, fmt='%.1fx', label_type='edge', padding=3, fontsize=9)

    ax.margins(y=0.1)
    plt.xticks(ha='right')
    plt.tight_layout()

    # Zapisz wykres do pliku z odpowiednią nazwą
    filename = os.path.join(OUTPUT_DIR, f"1_zysk_wydajnosci_UŚREDNIONY.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()


# <<< NOWA FUNKCJA GENERUJĄCA WYKRES UŚREDNIONY >>>
def plot_average_speedup_vs_dart(df):
    """3. Generuje jeden wykres uśredniający zysk wydajnościowy ze wszystkich rozmiarów danych."""
    print(f"\n-> Generowanie UŚREDNIONEGO wykresu ZYSKU WYDAJNOŚCIOWEGO dla wszystkich danych...")
    if df.empty: return

    # Użyj pivot_table do obliczenia średniego czasu dla każdej kombinacji, agregując wszystkie rozmiary danych
    # aggfunc='mean' jest domyślne, ale dla jasności można je dodać
    pivot = df.pivot_table(index=['Device', 'Algorithm'], columns='Implementation', values='WallTime_Avg_ms',
                           aggfunc=np.mean)

    # Oblicz zysk wydajnościowy na podstawie uśrednionych wartości
    pivot['Zysk FFI'] = pivot['Dart'] / pivot['FFI']
    pivot['Zysk Platform Channel'] = pivot['Dart'] / pivot['Platform Channel']
    pivot_to_plot = pivot[['Zysk FFI', 'Zysk Platform Channel']]

    ax = pivot_to_plot.plot(kind='bar', figsize=(12, 8), grid=True, rot=45)

    ax.set_title(f'Uśredniony zysk wydajnościowy względem Darta (dla wszystkich danych)', fontsize=16,
                 fontweight='bold', pad=20)
    ax.set_xlabel("Urządzenie / Algorytm", fontsize=12, fontweight='bold')
    ax.set_ylabel("Krotność przyspieszenia [x]", fontsize=12, fontweight='bold')
    ax.legend(title='Metoda szybsza od Darta')

    for container in ax.containers:
        ax.bar_label(container, fmt='%.1fx', label_type='edge', padding=3, fontsize=9)

    ax.margins(y=0.1)
    plt.xticks(ha='right')
    plt.tight_layout()

    # Zapisz wykres do pliku z odpowiednią nazwą
    filename = os.path.join(OUTPUT_DIR, f"1_zysk_wydajnosci_UŚREDNIONY.png")
    plt.savefig(filename, dpi=150)
    print(f"   -> Zapisano: {filename}")
    plt.show()

# --- GŁÓWNA CZĘŚĆ SKRYPTU ---
if __name__ == "__main__":
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"📂 Utworzono katalog: {OUTPUT_DIR}")

    combined_df = load_and_combine_data(FILES_TO_COMPARE)
    if combined_df is not None:
        print("--- Rozpoczynam generowanie wykresów ---")
        unique_sizes = sorted(combined_df['DataSize_KB'].unique())
        for size in unique_sizes:
            plot_speedup_vs_dart(combined_df, size)
            plot_full_comparison(combined_df, size)
            plot_average_speedup_vs_dart(combined_df)
        print("\n✅ Wszystkie wykresy zostały wygenerowane.")