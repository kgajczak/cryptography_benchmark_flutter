// ignore_for_file: avoid_print // For logs from BenchmarkService

import 'dart:developer';
import 'dart:math' show Random;

import 'package:cryptography_benchmark_flutter/benchmark/benchmark_service.dart';
// Imports of our files
import 'package:cryptography_benchmark_flutter/crypto/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter

void main() {
  // Ensure that binding is initialized before using BenchmarkService,
  // because BenchmarkService generates keys in its constructor.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CryptoBenchmarkApp());
}

class CryptoBenchmarkApp extends StatelessWidget {
  const CryptoBenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cryptographic Benchmark',
      theme: ThemeData(
          primarySwatch: Colors.teal, // You can choose a different color
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
              inputDecorationTheme: InputDecorationTheme(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints.tight(
              const Size.fromHeight(50),
            ), // Setting Dropdown height
          ))),
      home: const BenchmarkPage(),
    );
  }
}

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  // Initialize the benchmark service.
  // Important: BenchmarkService generates keys in the constructor,
  // so it should be created only once or keys should be managed differently.
  final BenchmarkService _benchmarkService = BenchmarkService();

  // User interface state
  ImplementationType _selectedImplType = ImplementationType.dart;
  AlgorithmType _selectedAlgoType = AlgorithmType.aesGcm;
  final TextEditingController _dataSizeController =
      TextEditingController(text: '1024'); // Default 1KB
  final TextEditingController _iterationsController =
      TextEditingController(text: '100'); // Default 100 iterations

  // List to store the history of results
  final List<BenchmarkResult> _resultsHistory = [];
  final int _maxHistoryLength = 10; // Maximum number of stored results

  bool _isLoading = false; // Is the benchmark currently running?

  // Function to run the benchmark
  Future<void> _runBenchmark() async {
    // Validate and parse user input data
    final int? dataSize = int.tryParse(_dataSizeController.text);
    final int? iterations = int.tryParse(_iterationsController.text);

    if (dataSize == null ||
        dataSize <= 0 ||
        iterations == null ||
        iterations <= 0) {
      // Create an error result if the input data is invalid
      final errorResult = BenchmarkResult.error(
        implType: _selectedImplType,
        algoType: _selectedAlgoType,
        dataSize: dataSize ?? 0,
        iterations: iterations ?? 0,
        message:
            "Please provide valid, positive numbers for data size and number of iterations.",
      );
      // Update UI with the error
      setState(() {
        _resultsHistory.insert(
            0, errorResult); // Add error to the beginning of the history
        if (_resultsHistory.length > _maxHistoryLength) {
          _resultsHistory
              .removeLast(); // Remove the oldest result if history is full
        }
      });
      return;
    }

    // Set loading state before starting the benchmark
    setState(() {
      _isLoading = true;
    });

    BenchmarkResult result;
    try {
      // Run the actual benchmark
      result = await _benchmarkService.runBenchmark(
        implType: _selectedImplType,
        algoType: _selectedAlgoType,
        dataSize: dataSize,
        iterations: iterations,
      );
    } catch (e) {
      // Handle unexpected errors from the benchmark service itself
      result = BenchmarkResult.error(
        implType: _selectedImplType,
        algoType: _selectedAlgoType,
        dataSize: dataSize,
        iterations: iterations,
        message: "Unexpected error during benchmark: ${e.toString()}",
      );
    }

    // Update UI after the benchmark is finished
    // Check if the widget is still mounted (important for asynchronous operations)
    if (mounted) {
      setState(() {
        _resultsHistory.insert(
            0, result); // Add new result to the beginning of the history
        if (_resultsHistory.length > _maxHistoryLength) {
          _resultsHistory.removeLast(); // Maintain maximum history length
        }
        _isLoading = false; // End loading state
      });
    }
  }

  Future<void> _runFullBenchmark() async {
    // Walidacja i parsowanie danych wejściowych od użytkownika
    final int? dataSize = int.tryParse(_dataSizeController.text);
    final int? iterations = int.tryParse(_iterationsController.text);

    if (dataSize == null ||
        dataSize <= 0 ||
        iterations == null ||
        iterations <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid data.")),
      );
      return;
    }

    // Pokaż dialog blokujący UI
    showDialog(
      context: context,
      barrierDismissible: false, // Użytkownik nie może zamknąć dialogu
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Trwa pełny test..."),
              ],
            ),
          ),
        );
      },
    );

    // Lista wszystkich kombinacji do przetestowania
    const List<Map<String, dynamic>> testSuite = [
      {
        'impl': ImplementationType.dart,
        'algo': AlgorithmType.aesGcm,
      },
      {
        'impl': ImplementationType.platformChannel,
        'algo': AlgorithmType.aesGcm,
      },
      {
        'impl': ImplementationType.ffi,
        'algo': AlgorithmType.aesGcm,
      },
      {
        'impl': ImplementationType.dart,
        'algo': AlgorithmType.chaChaPoly,
      },
      {
        'impl': ImplementationType.platformChannel,
        'algo': AlgorithmType.chaChaPoly,
      },
      {
        'impl': ImplementationType.ffi,
        'algo': AlgorithmType.chaChaPoly,
      },
    ];

    final testData = _generateRandomData(dataSize);

    // Iteruj przez wszystkie testy
    for (final testCase in testSuite) {
      // Upewnij się, że UI jest nadal zamontowane
      if (!mounted) break;

      final result = await _benchmarkService.runBenchmark(
        implType: testCase['impl'],
        algoType: testCase['algo'],
        dataSize: dataSize,
        iterations: iterations,
        testData: testData,
      );

      // Dodaj wynik do historii
      setState(() {
        _resultsHistory.insert(0, result);
        if (_resultsHistory.length > _maxHistoryLength) {
          _resultsHistory.removeLast();
        }
      });

      // Odstęp 1 sekundy między testami
      await Future.delayed(const Duration(seconds: 1));
    }

    // Zamknij dialog po zakończeniu wszystkich testów
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Remember to dispose of controllers to avoid memory leaks
    _dataSizeController.dispose();
    _iterationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Cryptographic Benchmark'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // We use ListView so that all content is scrollable,
        // especially when the results history becomes long.
        child: ListView(
          children: [
            // --- Benchmark parameters selection section ---
            Text("Test Parameters",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            // Implementation type selection
            DropdownButtonFormField<ImplementationType>(
              value: _selectedImplType,
              decoration:
                  const InputDecoration(labelText: 'Implementation Type'),
              items: ImplementationType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                      type.name), // Displays enum name (e.g., "dart", "ffi")
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      // Disable during loading
                      if (value != null) {
                        setState(() {
                          _selectedImplType = value;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Algorithm selection
            DropdownButtonFormField<AlgorithmType>(
              value: _selectedAlgoType,
              decoration:
                  const InputDecoration(labelText: 'Cryptographic Algorithm'),
              items: AlgorithmType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name), // Displays enum name (e.g., "aesGcm")
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      // Disable during loading
                      if (value != null) {
                        setState(() {
                          _selectedAlgoType = value;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Data size input field
            TextField(
              controller: _dataSizeController,
              decoration: const InputDecoration(
                labelText: 'Data Size (bytes)',
                hintText: 'e.g., 1024, 16384, 1048576',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ], // Only digits
              enabled: !_isLoading, // Disable during loading
            ),
            const SizedBox(height: 16),

            // Number of iterations input field
            TextField(
              controller: _iterationsController,
              decoration: const InputDecoration(
                labelText: 'Number of Iterations',
                hintText: 'e.g., 100, 1000, 10000',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_isLoading, // Disable during loading
            ),
            const SizedBox(height: 24),

            // Button to run the benchmark
            ElevatedButton(
              // Disable button if benchmark is running
              onPressed: _isLoading ? null : _runBenchmark,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16)),
              child: const Text('Run Benchmark'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _runFullBenchmark,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16)),
              child: const Text('Run Complex Benchmark'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              // Disable button if benchmark is running
              onPressed: _isLoading ? null : _showResultDialog,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16)),
              child: const Text('Show results'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // --- Results history display section ---
            Text(
              'Results History (last ${_resultsHistory.length} of $_maxHistoryLength):',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // Display message if history is empty
            if (_resultsHistory.isEmpty && !_isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No results to display.'),
              ))
            else if (_isLoading && _resultsHistory.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Running the first test...'),
              )),

            // Results list
            ListView.builder(
              shrinkWrap: true, // So ListView only takes up necessary space
              physics:
                  const NeverScrollableScrollPhysics(), // Disable internal scrolling, as the whole page is a ListView
              itemCount: _resultsHistory.length,
              itemBuilder: (context, index) {
                final result = _resultsHistory[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  color: result.success
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      result.toString(),
                      style: TextStyle(
                        fontFamily: 'monospace', // Good font for technical data
                        color: result.success
                            ? Colors.black87
                            : Colors.red.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final resultHistoryInTxt = _getResultsHistory();
        log(resultHistoryInTxt);
        return Dialog.fullscreen(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText((resultHistoryInTxt)),
            ),
          ),
        );
      },
    );
  }

  String _getResultsHistory() {
    String resultHistoryInTxt = '';
    for (var element in _resultsHistory) {
      resultHistoryInTxt += element.toExportString();
    }
    return resultHistoryInTxt;
  }

  // Wygeneruj losowe dane do testów
  Uint8List _generateRandomData(int sizeInBytes) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(sizeInBytes, (_) => random.nextInt(256)));
  }
}
