// // import 'package:flutter/material.dart';
// // import 'package:intl/intl.dart';
// // import '../models/location_modules.dart';
// // import '../services/location_services.dart';

// // class AddNewLocationPage extends StatefulWidget {
// //   final LocationService locationService;

// //   const AddNewLocationPage({super.key, required this.locationService});

// //   @override
// //   State<AddNewLocationPage> createState() => _AddNewLocationPageState();
// // }

// // class _AddNewLocationPageState extends State<AddNewLocationPage> {
// //   final DateFormat dateFormat = DateFormat('dd MMM yyyy');

// //   // Form key
// //   final _formKey = GlobalKey<FormState>();

// //   // Controllers
// //   final TextEditingController siteNameController = TextEditingController();
// //   final TextEditingController nickNameController = TextEditingController();
// //   final TextEditingController purposeController = TextEditingController();
// //   // Add these controllers at the top with others
// //   final TextEditingController latitudeController = TextEditingController();
// //   final TextEditingController longitudeController = TextEditingController();
// //   final TextEditingController contactPersonName = TextEditingController();
// //   final TextEditingController contactPersonNumber = TextEditingController();

// //   final TextEditingController candidateLimitController =
// //       TextEditingController();
// //   final TextEditingController startDateController = TextEditingController();
// //   final TextEditingController endDateController = TextEditingController();

// //   // Selected dates
// //   DateTime? startDate;
// //   DateTime? endDate;

// //   @override
// //   void initState() {
// //     super.initState();

// //     // Add default locations for testing
// //     if (widget.locationService.locations.isEmpty) {
// //       widget.locationService.addLocation(
// //         LocationManager(
// //           locationName: 'Site Alphaaaaaaaaaaaaa',
// //           nickName: 'Alpha',
// //           latitude: 12.9716,
// //           longitude: 77.5946,
// //           startDate: DateTime.now(),
// //           endDate: DateTime.now().add(const Duration(days: 30)),
// //           reason: 'Default site',
// //           candidateLimit: 50,
// //           contactPersonName: "nila",
// //           contactPersonNumber: "987654321",
// //         ),
// //       );
// //       widget.locationService.addLocation(
// //         LocationManager(
// //           locationName: 'Site Beta',
// //           nickName: 'Beta',
// //           latitude: 13.0827,
// //           longitude: 80.2707,
// //           startDate: DateTime.now(),
// //           endDate: DateTime.now().add(const Duration(days: 30)),
// //           reason: 'Default site',
// //           candidateLimit: 30,
// //           contactPersonName: "Anbu",
// //           contactPersonNumber: "987654321",
// //         ),
// //       );
// //     }
// //   }

// //   /// Pick a date
// //   Future<void> _pickDate({required bool isStart}) async {
// //     final initialDate = isStart
// //         ? startDate ?? DateTime.now()
// //         : endDate ?? startDate ?? DateTime.now();
// //     final firstDate = isStart ? DateTime(2020) : startDate ?? DateTime(2020);
// //     final lastDate = DateTime(2100);

// //     final picked = await showDatePicker(
// //       context: context,
// //       initialDate: initialDate,
// //       firstDate: firstDate,
// //       lastDate: lastDate,
// //     );

// //     if (picked == null) return;

// //     setState(() {
// //       if (isStart) {
// //         startDate = picked;
// //         startDateController.text = dateFormat.format(picked);
// //         // Reset end date if before new start date
// //         if (endDate != null && endDate!.isBefore(picked)) {
// //           endDate = null;
// //           endDateController.clear();
// //         }
// //       } else {
// //         endDate = picked;
// //         endDateController.text = dateFormat.format(picked);
// //       }
// //     });
// //   }

// //   /// Save new location
// //   void _saveLocation() {
// //     if (!_formKey.currentState!.validate()) return;

// //     if (startDate == null || endDate == null) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Please select start and end date")),
// //       );
// //       return;
// //     }

// //     final newLocation = LocationManager(
// //       locationName: siteNameController.text,
// //       nickName: nickNameController.text,
// //       latitude: latitudeController.text.isEmpty
// //           ? 0
// //           : double.tryParse(latitudeController.text)!,
// //       longitude: longitudeController.text.isEmpty
// //           ? 0
// //           : double.tryParse(longitudeController.text)!,
// //       startDate: startDate!,
// //       endDate: endDate!,
// //       reason: purposeController.text.isEmpty ? null : purposeController.text,
// //       candidateLimit: candidateLimitController.text.isEmpty
// //           ? null
// //           : int.tryParse(candidateLimitController.text),
// //       contactPersonName: contactPersonName.text.isEmpty
// //           ? null
// //           : contactPersonName.text,
// //       contactPersonNumber: contactPersonNumber.text.isEmpty
// //           ? null
// //           : contactPersonNumber.text,
// //     );

// //     widget.locationService.addLocation(newLocation);
// //     setState(() {});

// //     // Close dialog and show confirmation
// //     Navigator.pop(context);
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       const SnackBar(content: Text('Location added successfully')),
// //     );

// //     // Clear form
// //     siteNameController.clear();
// //     nickNameController.clear();
// //     purposeController.clear();
// //     candidateLimitController.clear();
// //     latitudeController.clear();
// //     longitudeController.clear();
// //     contactPersonName.clear();
// //     contactPersonNumber.clear();
// //     startDateController.clear();
// //     endDateController.clear();
// //     startDate = null;
// //     endDate = null;
// //   }

// //   /// Open dialog to add location
// //   void _openAddLocationDialog() {
// //     showDialog(
// //       context: context,
// //       builder: (_) => AlertDialog(
// //         title: const Text('Add New Location'),

// //         content: SizedBox(
// //           width: 400,
// //           child: SingleChildScrollView(
// //             child: Form(
// //               key: _formKey,
// //               child: Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   // Site Name
// //                   const SizedBox(height: 12),
// //                   TextFormField(
// //                     controller: siteNameController,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Site Name *',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     validator: (v) =>
// //                         v == null || v.isEmpty ? 'Required' : null,
// //                   ),
// //                   const SizedBox(height: 12),

// //                   // Nick Name
// //                   TextFormField(
// //                     controller: nickNameController,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Nick Name *',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     validator: (v) =>
// //                         v == null || v.isEmpty ? 'Required' : null,
// //                   ),
// //                   const SizedBox(height: 12),

// //                   // Latitude
// //                   TextFormField(
// //                     controller: latitudeController,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Latitude *',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     keyboardType: const TextInputType.numberWithOptions(
// //                       decimal: true,
// //                     ),
// //                     validator: (v) => v == null || v.isEmpty
// //                         ? 'Latitude required'
// //                         : double.tryParse(v) == null
// //                         ? 'Enter a valid number'
// //                         : null,
// //                   ),
// //                   const SizedBox(height: 12),

// //                   // Longitude
// //                   TextFormField(
// //                     controller: longitudeController,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Longitude *',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     keyboardType: const TextInputType.numberWithOptions(
// //                       decimal: true,
// //                     ),
// //                     validator: (v) => v == null || v.isEmpty
// //                         ? 'Longitude required'
// //                         : double.tryParse(v) == null
// //                         ? 'Enter a valid number'
// //                         : null,
// //                   ),
// //                   const SizedBox(height: 12),

// //                   TextFormField(
// //                     controller: contactPersonName,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Contact Person Name *',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     validator: (v) =>
// //                         v == null || v.isEmpty ? 'Required' : null,
// //                   ),
// //                   const SizedBox(height: 12),

// //                   TextFormField(
// //                     controller: contactPersonNumber,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Contact Person Number *',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     keyboardType: const TextInputType.numberWithOptions(
// //                       decimal: true,
// //                     ),
// //                     validator: (v) => v == null || v.isEmpty
// //                         ? 'Contact Person Number required'
// //                         : double.tryParse(v) == null
// //                         ? 'Enter a valid number'
// //                         : null,
// //                   ),
// //                   const SizedBox(height: 12),

// //                   // Start Date
// //                   GestureDetector(
// //                     onTap: () => _pickDate(isStart: true),
// //                     child: AbsorbPointer(
// //                       child: TextFormField(
// //                         controller: startDateController,
// //                         decoration: InputDecoration(
// //                           labelText: 'Start Date *',
// //                           border: const OutlineInputBorder(),
// //                           suffixIcon: const Icon(Icons.calendar_today),
// //                         ),
// //                         validator: (v) =>
// //                             startDate == null ? 'Start date required' : null,
// //                       ),
// //                     ),
// //                   ),
// //                   const SizedBox(height: 12),

// //                   // End Date
// //                   GestureDetector(
// //                     onTap: () {
// //                       if (startDate == null) {
// //                         ScaffoldMessenger.of(context).showSnackBar(
// //                           const SnackBar(
// //                             content: Text('Please select start date first'),
// //                           ),
// //                         );
// //                         return;
// //                       }
// //                       _pickDate(isStart: false);
// //                     },
// //                     child: AbsorbPointer(
// //                       child: TextFormField(
// //                         controller: endDateController,
// //                         decoration: InputDecoration(
// //                           labelText: 'End Date *',
// //                           border: const OutlineInputBorder(),
// //                           suffixIcon: const Icon(Icons.calendar_today),
// //                         ),
// //                         validator: (v) =>
// //                             endDate == null ? 'End date required' : null,
// //                       ),
// //                     ),
// //                   ),
// //                   const SizedBox(height: 12),

// //                   // Purpose
// //                   TextFormField(
// //                     controller: purposeController,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Purpose',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     maxLines: 2,
// //                   ),
// //                   const SizedBox(height: 12),

// //                   // Candidate Limit
// //                   TextFormField(
// //                     controller: candidateLimitController,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Candidate Limit',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                     keyboardType: TextInputType.number,
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(context),
// //             child: const Text('Cancel'),
// //           ),
// //           ElevatedButton(onPressed: _saveLocation, child: const Text('Save')),
// //         ],
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final locations = widget.locationService.locations;

// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Assign Locations')),
// //       body: locations.isEmpty
// //           ? const Center(child: Text('No locations available'))
// //           : ListView.builder(
// //               padding: const EdgeInsets.all(16),
// //               itemCount: locations.length,
// //               itemBuilder: (context, index) {
// //                 final loc = locations[index];
// //                 return Card(
// //                   margin: const EdgeInsets.symmetric(vertical: 8),
// //                   child: ListTile(
// //                     title: Text(loc.nickName ?? 'No Nickname'),
// //                     subtitle: Text(
// //                       '${loc.locationName}\n ${dateFormat.format(loc.startDate)} - ${dateFormat.format(loc.endDate)} \n Lat: ${loc.latitude}, long: ${loc.longitude} \n Contact Person Name: ${loc.contactPersonName} \n Contact Number: ${loc.contactPersonNumber}',
// //                     ),
// //                     isThreeLine: true,
// //                   ),
// //                 );
// //               },
// //             ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: _openAddLocationDialog,
// //         tooltip: 'Add New Location',
// //         child: const Icon(Icons.add),
// //       ),
// //     );
// //   }
// // }

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter/services.dart';
// import '../models/location_modules.dart';
// import '../services/location_services.dart';

// class AddNewLocationPage extends StatefulWidget {
//   final LocationService locationService;

//   const AddNewLocationPage({super.key, required this.locationService});

//   @override
//   State<AddNewLocationPage> createState() => _AddNewLocationPageState();
// }

// class _AddNewLocationPageState extends State<AddNewLocationPage> {
//   final DateFormat dateFormat = DateFormat('dd MMM yyyy');
//   final _formKey = GlobalKey<FormState>();

//   final TextEditingController nickNameController = TextEditingController();
//   final TextEditingController latitudeController = TextEditingController();
//   final TextEditingController longitudeController = TextEditingController();
//   final TextEditingController contactPersonName = TextEditingController();
//   final TextEditingController contactPersonNumber = TextEditingController();
//   final TextEditingController startDateController = TextEditingController();
//   final TextEditingController endDateController = TextEditingController();

//   DateTime? startDate;
//   DateTime? endDate;

//   late Future<List<LocationManager>> locationsFuture;

//   @override
//   void initState() {
//     super.initState();
//     locationsFuture = widget.locationService.fetchLocations();
//   }

//   Future<void> _pickDate({required bool isStart}) async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2100),
//     );

//     if (picked == null) return;

//     setState(() {
//       if (isStart) {
//         startDate = picked;
//         startDateController.text = dateFormat.format(picked);

//         // If endDate is before startDate, reset it
//         if (endDate != null && endDate!.isBefore(startDate!)) {
//           endDate = null;
//           endDateController.text = '';
//         }
//       } else {
//         endDate = picked;
//         endDateController.text = dateFormat.format(picked);
//       }
//     });
//   }

//   Future<void> _saveLocation() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (startDate == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Select start date")));
//       return;
//     }

//     double lat = double.parse(latitudeController.text);
//     double lng = double.parse(longitudeController.text);

//     await widget.locationService.addLocationToDb(
//       nickName: nickNameController.text.trim(),
//       latitude: lat,
//       longitude: lng,
//       startDate: startDate!,
//       endDate: endDate, // nullable
//       contactPersonName: contactPersonName.text.trim().isEmpty
//           ? null
//           : contactPersonName.text.trim(),
//       contactPersonNumber: contactPersonNumber.text.trim().isEmpty
//           ? null
//           : contactPersonNumber.text.trim(),
//     );

//     if (!mounted) return;

//     Navigator.pop(context);

//     setState(() {
//       locationsFuture = widget.locationService.fetchLocations();
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Location added successfully")),
//     );
//   }

//   void _openAddLocationDialog() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Add New Location'),
//         content: SizedBox(
//           width: 400,
//           child: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Nick Name
//                   TextFormField(
//                     controller: nickNameController,
//                     decoration: const InputDecoration(labelText: 'Nick Name'),
//                     inputFormatters: [
//                       FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
//                     ],
//                     validator: (v) =>
//                         v == null || v.isEmpty ? "Required" : null,
//                   ),
//                   const SizedBox(height: 10),

//                   // Latitude
//                   TextFormField(
//                     controller: latitudeController,
//                     decoration: const InputDecoration(labelText: 'Latitude'),
//                     keyboardType: const TextInputType.numberWithOptions(
//                       decimal: true,
//                     ),
//                     inputFormatters: [
//                       FilteringTextInputFormatter.allow(
//                         RegExp(r'^-?\d{0,2}(\.\d{0,6})?$'),
//                       ),
//                     ],
//                     validator: (v) {
//                       if (v == null || v.isEmpty) return "Required";
//                       final val = double.tryParse(v);
//                       if (val == null) return "Invalid number";
//                       if (val < -90 || val > 90) {
//                         return "Latitude must be between -90 and 90";
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 10),

//                   // Longitude
//                   TextFormField(
//                     controller: longitudeController,
//                     decoration: const InputDecoration(labelText: 'Longitude'),
//                     keyboardType: const TextInputType.numberWithOptions(
//                       decimal: true,
//                     ),
//                     inputFormatters: [
//                       FilteringTextInputFormatter.allow(
//                         RegExp(r'^-?\d{0,3}(\.\d{0,6})?$'),
//                       ),
//                     ],
//                     validator: (v) {
//                       if (v == null || v.isEmpty) return "Required";
//                       final val = double.tryParse(v);
//                       if (val == null) return "Invalid number";
//                       if (val < -180 || val > 180) {
//                         return "Longitude must be between -180 and 180";
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 10),

//                   // Contact Name
//                   TextFormField(
//                     controller: contactPersonName,
//                     decoration: const InputDecoration(
//                       labelText: 'Contact Name',
//                     ),
//                     inputFormatters: [
//                       FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
//                     ],
//                   ),
//                   const SizedBox(height: 10),

//                   // Contact Number
//                   TextFormField(
//                     controller: contactPersonNumber,
//                     decoration: const InputDecoration(
//                       labelText: 'Contact Number',
//                     ),
//                     keyboardType: TextInputType.phone,
//                     maxLength: 10,
//                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                     validator: (v) {
//                       if (v == null || v.isEmpty) return null;
//                       if (v.length != 10) return "Enter 10 digit number";
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 10),

//                   // Start Date
//                   TextFormField(
//                     controller: startDateController,
//                     readOnly: true,
//                     onTap: () => _pickDate(isStart: true),
//                     decoration: const InputDecoration(labelText: 'Start Date'),
//                     validator: (_) =>
//                         startDate == null ? "Select start date" : null,
//                   ),
//                   const SizedBox(height: 10),

//                   // End Date (optional)
//                   TextFormField(
//                     controller: endDateController,
//                     readOnly: true,
//                     onTap: () => _pickDate(isStart: false),
//                     decoration: const InputDecoration(labelText: 'End Date'),
//                     validator: (_) {
//                       if (endDate != null && startDate != null) {
//                         if (endDate!.isBefore(startDate!)) {
//                           return "End date cannot be before start date";
//                         }
//                       }
//                       return null;
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(onPressed: _saveLocation, child: const Text("Save")),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Locations"),
//         backgroundColor: Colors.teal,
//       ),
//       body: FutureBuilder<List<LocationManager>>(
//         future: locationsFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             return Center(child: Text("Error: ${snapshot.error}"));
//           }

//           final locations = snapshot.data!;

//           if (locations.isEmpty) {
//             return const Center(child: Text("No locations available"));
//           }

//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: locations.length,
//             itemBuilder: (context, index) {
//               final loc = locations[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(loc.nickName),
//                   subtitle: Text(
//                     "${dateFormat.format(loc.startDate)} - "
//                     "${loc.endDate == null ? 'N/A' : dateFormat.format(loc.endDate!)}\n"
//                     "Lat: ${loc.latitude}, Long: ${loc.longitude}\n"
//                     "Contact: ${loc.contactPersonName ?? '-'} (${loc.contactPersonNumber ?? '-'})",
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _openAddLocationDialog,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'add_location_dialog.dart';

class ManageLocationPage extends StatefulWidget {
  const ManageLocationPage({super.key});

  @override
  State<ManageLocationPage> createState() => _ManageLocationPageState();
}

class _ManageLocationPageState extends State<ManageLocationPage> {
  List<Map<String, dynamic>> sites = [];
  bool loading = true;

  final String baseUrl = "http://192.168.29.216:3000/sites";

  @override
  void initState() {
    super.initState();
    loadSites();
  }

  // ─────────────────────────────
  // Load Sites
  // ─────────────────────────────
  Future<void> loadSites() async {
    try {
      final res = await http.get(Uri.parse(baseUrl));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          sites = List<Map<String, dynamic>>.from(data);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  // ─────────────────────────────
  // Add Site
  // ─────────────────────────────
  Future<void> saveSite(
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    final closedPoints = [...points];

    if (closedPoints.first != closedPoints.last) {
      closedPoints.add(closedPoints.first);
    }

    final body = jsonEncode({
      "site_name": name,
      "polygon_json": closedPoints
          .map((e) => {"lat": e.latitude, "lng": e.longitude})
          .toList(),
      "start_date": start.toIso8601String().split("T")[0],
      "end_date": end.toIso8601String().split("T")[0],
    });

    await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    loadSites();
  }

  // ─────────────────────────────
  // Update Site
  // ─────────────────────────────
  Future<void> updateSite(
    int id,
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    final closedPoints = [...points];

    if (closedPoints.first != closedPoints.last) {
      closedPoints.add(closedPoints.first);
    }

    final body = jsonEncode({
      "site_name": name,
      "polygon_json": closedPoints
          .map((e) => {"lat": e.latitude, "lng": e.longitude})
          .toList(),
      "start_date": start.toIso8601String().split("T")[0],
      "end_date": end.toIso8601String().split("T")[0],
    });

    await http.put(
      Uri.parse("$baseUrl/$id"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    loadSites();
  }

  // ─────────────────────────────
  void openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddLocationDialog(onSave: saveSite),
    );
  }

  void openEditDialog(Map site) {
    showDialog(
      context: context,
      builder: (_) => AddLocationDialog(
        existingSite: site,
        onSave: (name, points, start, end) {
          updateSite(site["id"], name, points, start, end);
        },
      ),
    );
  }

  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Locations"),
        backgroundColor: Colors.teal,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : sites.isEmpty
          ? const Center(child: Text("No locations available"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sites.length,
              itemBuilder: (context, i) {
                final s = sites[i];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(s["site_name"]),
                    subtitle: Text(
                      "From ${s["start_date"]} → ${s["end_date"]}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => openEditDialog(s),
                    ),
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
