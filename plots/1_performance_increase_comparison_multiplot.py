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
    """Wczytuje, czyści i łączy dane ze wszystkich podanych plików."""
    all_dataframes = []
    print("--- Rozpoczynam wczytywanie i przetwarzanie plików ---")
    for device_name, filepath in file_mapping.items():
        try:
            df = pd.read_csv(filepath, sep=';', skip_blank_lines=True)
            df.columns = df.columns.str.strip()
            implementation_raw = df['Implementation'].str.split('.').str[-1].str.lower().str.strip()
            implementation_map = {'ffi': 'FFI', 'platformchannel': 'Platform Channel', 'dart': 'Dart'}
            df['Implementation'] = implementation_raw.map(implementation_map)
            algorithm_raw = df['Algorithm'].str.split('.').str[-1].str.lower().str.strip()
            algorithm_map = {'aesgcm': 'AES-GCM 256', 'chachapoly': 'ChaCha20-Poly1305'}
            df['Algorithm'] = algorithm_raw.map(algorithm_map)
            df['DataSize_KB'] = (df['DataSize_B'] / 1024).astype(int)
            df['Device'] = device_name
            df['WallTime_Avg_s'] = (df['WallTime_Sum_ms'] / df['Iterations']) / 1000
            all_dataframes.append(df)
            print(f"✅ Pomyślnie wczytano: {filepath}")
        except FileNotFoundError:
            print(f"❌ OSTRZEŻENIE: Pominięto plik '{filepath}'.")
    if not all_dataframes: return None
    print("------------------------------------------------------\n")
    return pd.concat(all_dataframes, ignore_index=True)


def plot_summary_chart(df, output_dir):
    """Generuje wykres liniowy z uśrednionymi czasami dla wszystkich rozmiarów danych."""
    print("\n--- Generowanie wykresu z ogólną średnią ---")

    # 1. Oblicz średni czas dla każdej unikalnej kombinacji, ignorując rozmiar danych
    summary_df = df.groupby(['Device', 'Implementation', 'Algorithm'])['WallTime_Avg_s'].mean().reset_index()

    # 2. Ustaw kolejność na osi X
    implementation_order = ['FFI', 'Platform Channel', 'Dart']
    summary_df['Implementation'] = pd.Categorical(summary_df['Implementation'], categories=implementation_order,
                                                  ordered=True)
    summary_df = summary_df.sort_values('Implementation')

    # 3. Przygotuj dane do wykresu liniowego (tak jak na siatce)
    summary_df['Series'] = summary_df['Device'] + ' - ' + summary_df['Algorithm']

    # 4. Stwórz tabelę przestawną dla wykresu liniowego
    pivot_line = summary_df.pivot_table(
        index='Implementation',
        columns='Series',
        values='WallTime_Avg_s'
    )

    # 5. Rysuj wykres
    fig, ax = plt.subplots(figsize=(16, 9))
    pivot_line.plot(kind='line', marker='o', ax=ax, grid=True)

    # 6. Formatowanie
    ax.set_title('Uśredniona wydajność dla wszystkich rozmiarów danych', fontsize=18, fontweight='bold', pad=20)
    ax.set_xlabel("Implementacja", fontsize=12, fontweight='bold')

    ### ZMIANA: Ustawienie skali logarytmicznej i aktualizacja etykiety osi Y ###
    ax.set_ylabel("Uśredniony czas wykonania [s] (skala logarytmiczna)", fontsize=12, fontweight='bold')
    ax.set_yscale('log')

    ax.legend(title='Urządzenie - Algorytm')
    plt.tight_layout()

    # 7. Zapis i pokazanie
    filename = os.path.join(output_dir, "porownanie_urzadzen_srednia_ogolna.png")
    plt.savefig(filename, dpi=150)
    print(f"\n✅ Wykres z ogólną średnią został zapisany w pliku: {filename}")
    plt.show()


# --- GŁÓWNA CZĘŚĆ SKRYPTU ---
if __name__ == "__main__":
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"📂 Utworzono katalog: {OUTPUT_DIR}")

    combined_df = load_and_combine_data(FILES_TO_COMPARE)

    # --- PIERWSZY WYKRES (SIATKA) ---
    if combined_df is not None:
        print("--- Generowanie siatki wykresów porównawczych ---")
        unique_sizes = sorted(combined_df['DataSize_KB'].unique())
        implementation_order = ['FFI', 'Platform Channel', 'Dart']
        combined_df['Implementation'] = pd.Categorical(combined_df['Implementation'], categories=implementation_order,
                                                       ordered=True)
        n_cols = len(unique_sizes)
        fig, axes = plt.subplots(nrows=1, ncols=n_cols, figsize=(6 * n_cols, 8), sharey=False)
        fig.suptitle('Porównanie wydajności urządzeń dla różnych implementacji', fontsize=20, fontweight='bold')

        for col, size in enumerate(unique_sizes):
            ax = axes[col] if n_cols > 1 else axes
            df_task = combined_df[combined_df['DataSize_KB'] == size]
            if not df_task.empty:
                df_task['Series'] = df_task['Device'] + ' - ' + df_task['Algorithm']
                pivot = df_task.pivot_table(index='Implementation', columns='Series', values='WallTime_Avg_s')
                pivot.plot(kind='line', marker='o', ax=ax, grid=True, legend=False)
            ax.set_title(f'{size} KB', fontsize=14)
            ax.set_xlabel('')
            ax.tick_params(axis='x', rotation=45)
            ax.ticklabel_format(style='plain', axis='y')

        fig.text(0.5, 0.02, 'Implementacja', ha='center', va='center', fontsize=14, fontweight='bold')
        axes[0].set_ylabel("Średni czas wykonania [s]", fontsize=12, fontweight='bold')
        handles, labels = ax.get_legend_handles_labels()
        fig.legend(handles, labels, title='Urządzenie - Algorytm', loc='upper center', bbox_to_anchor=(0.5, 0.925),
                   ncol=6)
        plt.tight_layout(rect=[0.04, 0.05, 1, 0.88])
        filename = os.path.join(OUTPUT_DIR, "porownanie_urzadzen.png")
        plt.savefig(filename, dpi=150)
        print(f"\n✅ Wykres porównawczy został zapisany w pliku: {filename}")
        plt.show()

    # --- DRUGI WYKRES (PODSUMOWUJĄCY) ---
    if combined_df is not None:
        plot_summary_chart(combined_df, OUTPUT_DIR)