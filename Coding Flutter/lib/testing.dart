import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestingPage extends StatelessWidget {
  const TestingPage({super.key});

  // Helper for Realtime DB waste data extraction
  List<Map<String, dynamic>> extractWasteEntries(Map<String, dynamic> data) {
    List<Map<String, dynamic>> entries = [];
    
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
                          if (record is Map) {
                            entries.add({
                              'bin': bin,
                              ...record,
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
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Waste & Gas Monitoring'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.delete), text: 'Waste Data'),
                  Tab(icon: Icon(Icons.air), text: 'Gas Readings'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // TAB 1: Realtime Database Waste Data
                FutureBuilder<DatabaseEvent>(
                  future: FirebaseDatabase.instance.ref('/').once(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading waste data: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                      return const Center(child: Text('No waste data available'));
                    }

                    final data = Map<String, dynamic>.from(
                        snapshot.data!.snapshot.value as Map);
                    final entries = extractWasteEntries(data);

                    if (entries.isEmpty) {
                      return const Center(child: Text('No waste entries found'));
                    }

                    return ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.delete, color: Colors.green),
                            title: Text('Bin ${entry['bin']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Time: ${entry['timestamp'] ?? 'Unknown'}'),
                                Text('Height: ${entry['final_height_cm'] ?? '?'} cm'),
                                Text('Waste: ${entry['waste_thrown_cm'] ?? '?'} cm'),
                              ],
                            ),
                            trailing: Chip(
                              label: Text(
                                '${_calculateFillLevel(entry['final_height_cm'], entry['initial_height_cm'])}%',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: _getFillColor(
                                _calculateFillLevel(entry['final_height_cm'], entry['initial_height_cm']),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // TAB 2: Firestore Gas Readings
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('data')
                      .doc('gas')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading gas data: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.air, size: 40, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No gas data available'),
                          TextButton(
                            onPressed: () => _createGasDocument(context),
                            child: const Text('Initialize Gas Sensor'),
                          ),
                        ],
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final reading = data['gas_reading'] ?? 0;
                    final timestamp = data['timestamp'] ?? 'Unknown';

                    return Center(
                      child: Card(
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.air,
                                size: 60,
                                color: _getGasLevelColor(reading),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Current Gas Level',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '$reading',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getGasLevelText(reading),
                                style: TextStyle(
                                  color: _getGasLevelColor(reading),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Last updated: $timestamp',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
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
      },
    );
  }

  // Helper to create gas document if missing
  Future<void> _createGasDocument(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('data').doc('gas').set({
        'gas_reading': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gas sensor initialized')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // Waste fill level calculation
  double _calculateFillLevel(finalHeight, initialHeight) {
    try {
      final fh = double.tryParse(finalHeight?.toString() ?? '0') ?? 0;
      final ih = double.tryParse(initialHeight?.toString() ?? '1') ?? 1;
      return (fh / ih * 100).clamp(0, 100);
    } catch (e) {
      return 0;
    }
  }

  Color _getFillColor(double percentage) {
    if (percentage < 30) return Colors.green;
    if (percentage < 70) return Colors.orange;
    return Colors.red;
  }

  // Gas level helpers
  String _getGasLevelText(int reading) {
    if (reading > 1500) return 'DANGER';
    if (reading > 1000) return 'HIGH';
    return 'NORMAL';
  }

  Color _getGasLevelColor(int reading) {
    if (reading > 1500) return Colors.red;
    if (reading > 1000) return Colors.orange;
    return Colors.green;
  }
}