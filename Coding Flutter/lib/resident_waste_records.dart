import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Add this import at the top

class ResidentWasteRecordsPage extends StatefulWidget {
  const ResidentWasteRecordsPage({super.key});

  @override
  State<ResidentWasteRecordsPage> createState() => _ResidentWasteRecordsPageState();
}

class _ResidentWasteRecordsPageState extends State<ResidentWasteRecordsPage> {
  String activeTab = "Resident List"; // Active tab

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Resident Waste Records',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Tabs Section
            Container(
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        activeTab = "Resident List";
                      });
                    },
                    child: Column(
                      children: [
                        Text(
                          "Resident List",
                          style: TextStyle(
                            color: activeTab == "Resident List" ? Colors.blue : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (activeTab == "Resident List")
                          Container(
                            height: 2,
                            width: 100,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        activeTab = "History";
                      });
                    },
                    child: Column(
                      children: [
                        Text(
                          "History",
                          style: TextStyle(
                            color: activeTab == "History" ? Colors.blue : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (activeTab == "History")
                          Container(
                            height: 2,
                            width: 100,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content based on activeTab
            Expanded(
              child: activeTab == "Resident List"
                  ? const _ResidentListWidget()
                  : const _WasteHistoryWidget(),
            ),
          ],
        ),
      ),
    );
  }
}

// Resident List Widget with aggregation from Realtime Database
class _ResidentListWidget extends StatelessWidget {
  const _ResidentListWidget();

  // Helper for Realtime DB waste data extraction and aggregation
  Map<String, Map<String, dynamic>> aggregateResidentData(Map<String, dynamic> data) {
    // Map<bin, {totalCount, totalWaste, lastTimestamp}>
    final Map<String, Map<String, dynamic>> result = {};
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
                            final waste = double.tryParse(record['waste_thrown_cm']?.toString() ?? '0') ?? 0;
                            final timestamp = record['timestamp'];
                            if (!result.containsKey(bin)) {
                              result[bin] = {
                                'totalCount': 0,
                                'totalWaste': 0.0,
                                'lastTimestamp': null,
                              };
                            }
                            result[bin]!['totalCount'] += 1;
                            result[bin]!['totalWaste'] += waste;
                            // Update lastTimestamp if newer
                            if (timestamp != null) {
                              final prev = result[bin]!['lastTimestamp'];
                              if (prev == null ||
                                  DateTime.tryParse(timestamp)?.isAfter(DateTime.tryParse(prev) ?? DateTime(1970)) == true) {
                                result[bin]!['lastTimestamp'] = timestamp;
                              }
                            }
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
    return result;
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Unknown';
      if (timestamp is DateTime) {
        return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
      }
      if (timestamp is String) {
        final dt = DateTime.tryParse(timestamp);
        if (dt != null) {
          return DateFormat('yyyy-MM-dd HH:mm').format(dt);
        }
      }
      return timestamp.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('/').once(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading resident data: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('No resident data available'));
        }

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final residentData = aggregateResidentData(data);

        if (residentData.isEmpty) {
          return const Center(child: Text('No resident entries found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: residentData.length,
          itemBuilder: (context, index) {
            final bin = residentData.keys.elementAt(index);
            final info = residentData[bin]!;
            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 16.0),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.grey,
                      radius: 30,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bin,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Total thrown: ${info['totalCount']}",
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            "Total waste thrown: ${info['totalWaste'].toStringAsFixed(2)} cm",
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            "Last time throw: ${_formatTimestamp(info['lastTimestamp'])}",
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Waste History Widget (from TestingPage waste tab)
class _WasteHistoryWidget extends StatelessWidget {
  const _WasteHistoryWidget();

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

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Unknown';
      // If timestamp is already a DateTime
      if (timestamp is DateTime) {
        return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
      }
      // If timestamp is a string in ISO8601 format
      if (timestamp is String) {
        final dt = DateTime.tryParse(timestamp);
        if (dt != null) {
          return DateFormat('yyyy-MM-dd HH:mm').format(dt);
        }
      }
      return timestamp.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseEvent>(
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

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final entries = extractWasteEntries(data);

        if (entries.isEmpty) {
          return const Center(child: Text('No waste entries found'));
        }

        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              color: Colors.grey[900], // Dark card background
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.delete, color: Colors.green),
                title: Text(
                  entry['bin'].toString(), // Only resident/bin name, no "Bin" prefix
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time: ${_formatTimestamp(entry['timestamp'])}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Waste Thrown (cm): ${entry['waste_thrown_cm'] ?? '?'}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                // No trailing chip
              ),
            );
          },
        );
      },
    );
  }
}