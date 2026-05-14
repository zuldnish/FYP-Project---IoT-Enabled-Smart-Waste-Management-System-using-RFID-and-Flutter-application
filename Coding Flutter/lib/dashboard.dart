import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resident_waste_records.dart';
import 'resident_with_warning.dart';
import 'testing.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // Helper to get the latest garbage level percentage from Realtime DB
  Future<double?> getLatestGarbageLevel() async {
    try {
      await Firebase.initializeApp();
      final snapshot = await FirebaseDatabase.instance.ref('/').once();

      if (snapshot.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      List<Map<String, dynamic>> allEntries = [];

      data.forEach((bin, dateData) {
        if (dateData is Map) {
          dateData.forEach((date, monthData) {
            if (monthData is Map) {
              monthData.forEach((month, dayData) {
                if (dayData is Map) {
                  dayData.forEach((day, hourData) {
                    if (hourData is Map) {
                      hourData.forEach((hour, minuteData) {
                        if (minuteData is Map) {
                          minuteData.forEach((minuteRange, record) {
                            if (record is Map && record['final_height_percent'] != null) {
                              allEntries.add({
                                'timestamp': record['timestamp'],
                                'final_height_percent': double.tryParse(record['final_height_percent'].toString()) ?? 0,
                              });
                            }
                          });
                        }
                      });
                    }
                  });
                }
              });
            }
          });
        }
      });

      if (allEntries.isEmpty) return null;

      // Sort by timestamp (newest first)
      allEntries.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));

      // Get the latest entry's final_height_percent
      final latest = allEntries.first;
      return latest['final_height_percent'] as double;
    } catch (e) {
      return null;
    }
  }

  // Helper to get the latest gas reading from Firestore
  Future<Map<String, dynamic>?> getLatestGasReading() async {
    try {
      await Firebase.initializeApp();
      final doc = await FirebaseFirestore.instance
          .collection('data')
          .doc('gas')
          .get();
      
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Add a key to force refresh of FutureBuilders
  Key _refreshKey = UniqueKey();

  void _refreshData() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Wardiere Inc.',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          key: _refreshKey, // This will force the FutureBuilders to rebuild
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Garbage Level Card with real data
              FutureBuilder<double?>(
                future: getLatestGarbageLevel(),
                builder: (context, snapshot) {
                  final percentage = snapshot.data ?? 0.0;
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;
                  final hasError = snapshot.hasError || (snapshot.connectionState == ConnectionState.done && !snapshot.hasData);

                  Color levelColor;
                  if (percentage < 30) {
                    levelColor = Colors.green;
                  } else if (percentage < 70) {
                    levelColor = Colors.orange;
                  } else {
                    levelColor = Colors.red;
                  }

                  return Card(
                    color: Colors.grey[900],
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.recycling, size: 40, color: Colors.green),
                          const Text(
                            'Garbage Level',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          if (isLoading)
                            const CircularProgressIndicator()
                          else if (hasError)
                            const Text(
                              'Error loading data',
                              style: TextStyle(color: Colors.red),
                            )
                          else
                            Text(
                              '${percentage.toStringAsFixed(1)}% Full',
                              style: TextStyle(
                                color: levelColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (!isLoading && !hasError)
                            LinearProgressIndicator(
                              value: percentage / 100,
                              color: levelColor,
                              backgroundColor: Colors.grey[800],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Gas Level Card (replaces CO₂ Level)
              FutureBuilder<Map<String, dynamic>?>(
                future: getLatestGasReading(),
                builder: (context, snapshot) {
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;
                  final hasError = snapshot.hasError;
                  final gasReading = snapshot.data?['gas_reading'] ?? 0;

                  // Calculate percentage
                  final double percentage = (gasReading is num)
                      ? ((gasReading / 3000) * 100).clamp(0, 100).toDouble()
                      : 0.0;

                  // Color coding based on percentage (like garbage level)
                  Color levelColor;
                  if (percentage < 30) {
                    levelColor = Colors.green;
                  } else if (percentage < 70) {
                    levelColor = Colors.orange;
                  } else {
                    levelColor = Colors.red;
                  }

                  return Card(
                    color: Colors.grey[900],
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.air, size: 40, color: levelColor),
                          const Text(
                            'Gas Level',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          if (isLoading)
                            const CircularProgressIndicator()
                          else if (hasError)
                            const Text(
                              'Error loading gas data',
                              style: TextStyle(color: Colors.red),
                            )
                          else
                            Text(
                              '$gasReading',
                              style: TextStyle(
                                color: levelColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (!isLoading && !hasError)
                            LinearProgressIndicator(
                              value: percentage / 100,
                              color: levelColor,
                              backgroundColor: Colors.grey[800],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // View Resident Waste Records Button (unchanged)
              SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.grey[900],
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ResidentWasteRecordsPage(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: const [
                          Icon(Icons.group, size: 40, color: Colors.blue),
                          SizedBox(width: 16),
                          Text(
                            'View Resident Waste Records',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // View Resident with Warning Button (unchanged)
              SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.grey[900],
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ResidentWithWarningPage(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: const [
                          Icon(Icons.warning, size: 40, color: Colors.orange),
                          SizedBox(width: 16),
                          Text(
                            'View Resident with Warning',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TestingPage(),
                ),
              );
            },
            child: const Text(
              'Go to Testing',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}