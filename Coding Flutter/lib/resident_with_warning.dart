import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ResidentWithWarningPage extends StatefulWidget {
  const ResidentWithWarningPage({super.key});

  @override
  State<ResidentWithWarningPage> createState() => _ResidentWithWarningPageState();
}

class _ResidentWithWarningPageState extends State<ResidentWithWarningPage> {
  String activeTab = "Active Warnings"; // Active tab

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow, // Yellow background for the header
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black), // Back button
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous page
          },
        ),
        title: const Text(
          'Residents with Warning',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.black, // Black background for the entire page
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add spacing between the title bar and tabs
            const SizedBox(height: 16),

            // Only Active Warnings Tab
            Container(
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        "Active Warnings",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        height: 2,
                        width: 120,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Residents with Warning List (filtered)
            Expanded(
              child: FutureBuilder<DatabaseEvent>(
                future: FirebaseDatabase.instance.ref('/').once(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading data: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text('No resident data available'));
                  }

                  final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

                  // Aggregate total waste thrown and latest initial height for each resident/bin
                  final Map<String, double> totalWasteMap = {};
                  final Map<String, double> latestInitialHeightMap = {};
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
                                          final initialHeight = double.tryParse(record['initial_height_cm']?.toString() ?? '0') ?? 0;
                                          totalWasteMap[bin] = (totalWasteMap[bin] ?? 0) + waste;
                                          // Store the latest initial height for each bin (if needed)
                                          if (initialHeight > 0) {
                                            latestInitialHeightMap[bin] = initialHeight;
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

                  // Filter bins with total waste thrown > 30% of their latest initial height
                  final filteredBins = totalWasteMap.entries
                      .where((e) =>
                          latestInitialHeightMap[e.key] != null &&
                          latestInitialHeightMap[e.key]! > 0 &&
                          (e.value / latestInitialHeightMap[e.key]!) * 100 > 30)
                      .toList();

                  if (filteredBins.isEmpty) {
                    return const Center(
                      child: Text(
                        'No residents exceed 30% waste thrown',
                        style: TextStyle(color: Colors.white), // Set font color to white
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredBins.length,
                    itemBuilder: (context, index) {
                      final bin = filteredBins[index].key;
                      final totalWaste = filteredBins[index].value;
                      return _buildResidentCard(
                        name: bin,
                        warningDetails: "Total waste thrown: ${totalWaste.toStringAsFixed(2)} cm",
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build resident cards
  Widget _buildResidentCard({
    required String name,
    required String warningDetails,
  }) {
    return Card(
      color: Colors.grey[900], // Dark grey card background
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
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    warningDetails,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}