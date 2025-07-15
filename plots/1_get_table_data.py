import pandas as pd
import os

# --- KONFIGURACJA ---
#
# 👇 TUTAJ WPISZ NAZWĘ SWOJEGO PLIKU Z DANYMI
#
NAZWA_PLIKU_WEJSCIOWEGO = '1_benchmark_pixel.csv'
#
# 👇 Nazwa, pod jaką zostanie zapisany plik z uśrednionymi wynikami
#
NAZWA_PLIKU_WYJSCIOWEGO = 'wyniki_usrednione_z_roznica.csv'
#
# 👇 Nazwa urządzenia, która pojawi się w finalnej tabeli
#
NAZWA_URZADZENIA = 'Google Pixel 8 Pro (ARMv9)'


#
# --------------------


def przetwarzaj_plik(filepath, device_name):
    """Główna funkcja, która wczytuje, przetwarza i zwraca uśrednione dane."""

    print(f"🔄 Wczytuję plik: {filepath}...")

    # Wczytanie danych z pliku CSV
    df = pd.read_csv(filepath, sep=';', skip_blank_lines=True)
    df.columns = df.columns.str.strip()

    print("⚙️  Przetwarzam dane...")

    # --- Krok 1: Mapowanie nazw ---
    implementation_raw = df['Implementation'].str.split('.').str[-1]
    implementation_map = {'ffi': 'FFI', 'platformChannel': 'Platform Channel', 'dart': 'Dart'}
    df['Implementation'] = implementation_raw.map(implementation_map)

    algorithm_raw = df['Algorithm'].str.split('.').str[-1]
    algorithm_map = {'aesGcm': 'AES-GCM 256', 'chaChaPoly': 'ChaCha20-Poly1305'}
    df['Algorithm'] = algorithm_raw.map(algorithm_map)

    # --- Krok 2: Obliczenie średniego czasu na operację ---
    df['Encrypt_Avg_ms'] = df['WallTime_Encrypt_ms'] / df['Iterations']
    df['Decrypt_Avg_ms'] = df['WallTime_Decrypt_ms'] / df['Iterations']

    # --- Krok 3: Uśrednienie wyników po wszystkich rozmiarach danych ---
    kolumny_do_grupowania = ['Algorithm', 'Implementation']
    kolumny_do_usrednienia = ['Encrypt_Avg_ms', 'Decrypt_Avg_ms']

    df_usrednione = df.groupby(kolumny_do_grupowania)[kolumny_do_usrednienia].mean().reset_index()

    ### ZMIANA 1: Dodanie nowej kolumny z procentową różnicą ###
    # Obliczamy procentową różnicę: ((szyfrowanie - deszyfrowanie) / szyfrowanie) * 100
    df_usrednione['Roznica_Szyfr_Deszyfr_%'] = ((df_usrednione['Encrypt_Avg_ms'] - df_usrednione['Decrypt_Avg_ms']) /
                                                df_usrednione['Encrypt_Avg_ms']) * 100

    # Dodajemy kolumnę z nazwą urządzenia na początku
    df_usrednione.insert(0, 'Device', device_name)

    print("✅ Przetwarzanie zakończone.")

    return df_usrednione


# --- GŁÓWNA CZĘŚĆ SKRYPTU ---
if __name__ == "__main__":
    if not os.path.exists(NAZWA_PLIKU_WEJSCIOWEGO):
        print(f"❌ BŁĄD: Nie znaleziono pliku '{NAZWA_PLIKU_WEJSCIOWEGO}'.")
        print("Upewnij się, że skrypt jest uruchamiany w tym samym folderze co plik z danymi.")
    else:
        finalna_tabela = przetwarzaj_plik(NAZWA_PLIKU_WEJSCIOWEGO, NAZWA_URZADZENIA)

        ### ZMIANA 2: Ręczne formatowanie kolumn przed zapisem ###
        # Formatujemy liczby, aby były bardziej czytelne w wynikowym pliku.
        finalna_tabela['Encrypt_Avg_ms'] = finalna_tabela['Encrypt_Avg_ms'].map('{:.4f}'.format)
        finalna_tabela['Decrypt_Avg_ms'] = finalna_tabela['Decrypt_Avg_ms'].map('{:.4f}'.format)
        finalna_tabela['Roznica_Szyfr_Deszyfr_%'] = finalna_tabela['Roznica_Szyfr_Deszyfr_%'].map('{:.2f}%'.format)

        try:
            # Zapis do pliku CSV (bez formatowania w locie, bo zrobiliśmy to już ręcznie)
            finalna_tabela.to_csv(
                NAZWA_PLIKU_WYJSCIOWEGO,
                sep=';',
                index=False
            )
            print(f"💾 Pomyślnie zapisano uśrednione wyniki do pliku: {NAZWA_PLIKU_WYJSCIOWEGO}")
        except Exception as e:
            print(f"❌ BŁĄD: Wystąpił problem podczas zapisu do pliku CSV: {e}")