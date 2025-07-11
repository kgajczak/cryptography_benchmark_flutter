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
          primarySwatch: Colors.teal,
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
  final int _maxHistoryLength = 300; // Increased history length for full test

  bool _isLoading = false; // Is the benchmark currently running?

  // Function to run a single benchmark based on dropdowns/text fields
  Future<void> _runSingleBenchmark() async {
    // Validate and parse user input
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
        _resultsHistory.insert(0, errorResult);
        if (_resultsHistory.length > _maxHistoryLength) {
          _resultsHistory.removeLast();
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
        _resultsHistory.insert(0, result);
        if (_resultsHistory.length > _maxHistoryLength) {
          _resultsHistory.removeLast();
        }
        _isLoading = false; // End loading state
      });
    }
  }

  // A simpler suite that runs all 6 implementation/algorithm combinations for a single data size.
  Future<void> _runSimpleSuite() async {
    // Validate and parse user input
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

    // Show a UI-blocking dialog
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot close the dialog
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Running simple suite..."),
              ],
            ),
          ),
        );
      },
    );

    // List of all combinations to test
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

    // Generate one set of random data for this suite
    final testData = _generateRandomData(dataSize);

    setState(() {
      _isLoading = true;
    });

    try {
      // Iterate through all tests
      for (final testCase in testSuite) {
        // Make sure the widget is still mounted
        if (!mounted) break;

        final result = await _benchmarkService.runBenchmark(
          implType: testCase['impl'],
          algoType: testCase['algo'],
          dataSize: dataSize,
          iterations: iterations,
          testData: testData,
        );

        // Add the result to history
        setState(() {
          _resultsHistory.insert(0, result);
          if (_resultsHistory.length > _maxHistoryLength) {
            _resultsHistory.removeLast();
          }
        });

        // 1-second delay between tests
        await Future.delayed(const Duration(seconds: 1));
      }
    } finally {
      // Close the dialog after all tests are finished
      if (mounted) {
        Navigator.of(context).pop();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- NEW FUNCTION TO RUN THE FULL PLANNED BENCHMARK ---
  Future<void> _runFullPlannedTest() async {
    setState(() {
      _isLoading = true;
    });

    // --- Research plan definition ---
    const List<ImplementationType> implementations = [
      ImplementationType.ffi,
      ImplementationType.platformChannel,
      ImplementationType.dart,
    ];
    const List<AlgorithmType> algorithms = [
      AlgorithmType.aesGcm,
      AlgorithmType.chaChaPoly,
    ];
    const List<int> dataSizes = [
      16384, // 16 KB
      65536, // 64 KB
      262144, // 256 KB
      1048576, // 1 MB
      4194304, // 4 MB
    ];
    const int repetitions = 1;
    final int iterationsPerRun =
        int.tryParse(_iterationsController.text) ?? 100;

    // --- Progress Dialog ---
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Running Planned Test Suite',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Loop order changed for data generation efficiency
      for (int i = 0; i < repetitions; i++) {
        for (final size in dataSizes) {
          // For a given data size, generate the test data once per repetition
          final testData = _generateRandomData(size);

          for (final impl in implementations) {
            for (final algo in algorithms) {
              if (!mounted) return; // Always check if the widget is mounted

              final result = await _benchmarkService.runBenchmark(
                implType: impl,
                algoType: algo,
                dataSize: size,
                iterations: iterationsPerRun,
                testData: testData,
              );

              if (mounted) {
                setState(() {
                  _resultsHistory.insert(0, result);
                  if (_resultsHistory.length > _maxHistoryLength) {
                    _resultsHistory.removeLast();
                  }
                });
              }

              // A short break to let the device "breathe" and cool down
              await Future.delayed(const Duration(seconds: 1));
            }
          }
        }
      }
    } finally {
      // --- Finalization and cleanup ---
      if (mounted) {
        Navigator.of(context).pop(); // Close the progress dialog
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Full planned test finished!"),
            duration: Duration(seconds: 3),
          ),
        );
      }
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
                  child: Text(type.name),
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
                  child: Text(type.name),
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Number of iterations input field
            TextField(
              controller: _iterationsController,
              decoration: const InputDecoration(
                labelText: 'Number of Iterations',
                hintText: 'e.g., 100, 1000',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),

            // --- Action Buttons ---
            ElevatedButton(
              onPressed: _isLoading ? null : _runSingleBenchmark,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16)),
              child: const Text('Run Single Benchmark'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _runSimpleSuite,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16)),
              child: const Text('Run Simple Suite (6 tests)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _runFullPlannedTest,
              style: ElevatedButton.styleFrom(
                  // backgroundColor: Colors.deepPurple,
                  // foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    // fontWeight: FontWeight.bold,
                  )),
              child: const Text('Run Full Planned Test'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _showResultDialog,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16)),
              child: const Text('Show Results as CSV'),
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
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                        fontFamily: 'monospace',
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
        final resultHistoryInTxt = _getResultsHistoryAsCsv();
        log(resultHistoryInTxt); // Log for easy copy-paste from debug console
        return Dialog.fullscreen(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(resultHistoryInTxt),
            ),
          ),
        );
      },
    );
  }

  String _getResultsHistoryAsCsv() {
    final buffer = StringBuffer();
    // Add header row for the CSV
    // [ENGLISH] Updated the CSV header to include the new columns.
    buffer.writeln(
        "Implementation;Algorithm;DataSize_B;Iterations;WallTime_Encrypt_ms;Stdev_Encrypt_ms;WallTime_Decrypt_ms;Stdev_Decrypt_ms;WallTime_Sum_ms;CPUTime_ms;RAM_Avg_MB;RAM_Peak_MB");

    // Reverse the list to show oldest results first in the export
    final reversedHistory = _resultsHistory.reversed;
    for (var element in reversedHistory) {
      // Assuming a `toCsvRow` method exists on BenchmarkResult.
      // This method should be implemented to format the data correctly.
      // Placeholder for CPU data which must be filled manually.
      buffer.write(element.toCsvRow());
    }
    return buffer.toString();
  }

  // Generate random data for tests
  Uint8List _generateRandomData(int sizeInBytes) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(sizeInBytes, (_) => random.nextInt(256)));
  }
}
