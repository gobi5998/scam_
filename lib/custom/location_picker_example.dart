// import 'package:flutter/material.dart';
// import 'location_picker_screen.dart';
//
// /// Example screen showing how to use the new Google Maps-based location picker
// class LocationPickerExample extends StatefulWidget {
//   const LocationPickerExample({Key? key}) : super(key: key);
//
//   @override
//   State<LocationPickerExample> createState() => _LocationPickerExampleState();
// }
//
// class _LocationPickerExampleState extends State<LocationPickerExample> {
//   String? selectedLocation;
//   String? selectedAddress;
//   double? selectedLatitude;
//   double? selectedLongitude;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Location Picker Example'),
//         backgroundColor: Colors.orange[600],
//         foregroundColor: Colors.white,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // Location selection button
//             ElevatedButton.icon(
//               onPressed: () {
//                 LocationPickerBottomSheet.show(
//                   context,
//                   onLocationSelected: (location, address, latitude, longitude) {
//                     setState(() {
//                       selectedLocation = location;
//                       selectedAddress = address;
//                       selectedLatitude = latitude;
//                       selectedLongitude = longitude;
//                     });
//
//                     // Show success message
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text('Location selected: $location'),
//                         backgroundColor: Colors.green,
//                       ),
//                     );
//                   },
//                 );
//               },
//               icon: const Icon(Icons.location_on),
//               label: const Text('Select Location'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.orange[600],
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 24),
//
//             // Display selected location information
//             if (selectedLocation != null) ...[
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Selected Location:',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//
//                       // Location name
//                       Row(
//                         children: [
//                           const Icon(Icons.place, color: Colors.red),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               selectedLocation!,
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 8),
//
//                       // Full address
//                       Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Icon(Icons.location_on, color: Colors.blue),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               selectedAddress ?? 'Address not available',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 8),
//
//                       // Coordinates
//                       if (selectedLatitude != null && selectedLongitude != null) ...[
//                         Row(
//                           children: [
//                             const Icon(Icons.gps_fixed, color: Colors.green),
//                             const SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Lat: ${selectedLatitude!.toStringAsFixed(6)}, '
//                                 'Lng: ${selectedLongitude!.toStringAsFixed(6)}',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[500],
//                                   fontFamily: 'monospace',
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 16),
//
//               // Action buttons
//               Row(
//                 children: [
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: () {
//                         // Copy coordinates to clipboard
//                         if (selectedLatitude != null && selectedLongitude != null) {
//                           final coords = '${selectedLatitude!.toStringAsFixed(6)}, ${selectedLongitude!.toStringAsFixed(6)}';
//                           // You can add clipboard functionality here
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text('Coordinates copied: $coords'),
//                               backgroundColor: Colors.blue,
//                             ),
//                           );
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue[600],
//                         foregroundColor: Colors.white,
//                       ),
//                       child: const Text('Copy Coordinates'),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: () {
//                         // Open in maps app
//                         if (selectedLatitude != null && selectedLongitude != null) {
//                           final url = 'https://www.google.com/maps?q=${selectedLatitude},${selectedLongitude}';
//                           // You can use url_launcher to open this URL
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text('Opening in maps: $url'),
//                               backgroundColor: Colors.green,
//                             ),
//                           );
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green[600],
//                         foregroundColor: Colors.white,
//                       ),
//                       child: const Text('Open in Maps'),
//                     ),
//                   ),
//                 ],
//               ),
//             ] else ...[
//               // No location selected
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(32),
//                   child: Column(
//                     children: [
//                       Icon(
//                         Icons.location_off,
//                         size: 64,
//                         color: Colors.grey[400],
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         'No location selected',
//                         style: TextStyle(
//                           fontSize: 18,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'Tap the button above to select a location using Google Maps',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey[500],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//
//             const Spacer(),
//
//             // Information card
//             Card(
//               color: Colors.blue[50],
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(Icons.info, color: Colors.blue[600]),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Features:',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.blue[700],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       '• Interactive Google Maps interface\n'
//                       '• Search for locations by name\n'
//                       '• Get current location with GPS\n'
//                       '• Precise coordinates (latitude/longitude)\n'
//                       '• Accurate address information\n'
//                       '• Visual marker on selected location',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.blue[600],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// /// How to use the location picker in your app:
// ///
// /// 1. Import the location picker:
// ///    import 'package:your_app/custom/location_picker_screen.dart';
// ///
// /// 2. Call the location picker:
// ///    LocationPickerBottomSheet.show(
// ///      context,
// ///      onLocationSelected: (location, address, latitude, longitude) {
// ///        // Handle the selected location
// ///        print('Location: $location');
// ///        print('Address: $address');
// ///        print('Latitude: $latitude');
// ///        print('Longitude: $longitude');
// ///      },
// ///    );
// ///
// /// 3. The callback provides:
// ///    - location: Human-readable location name
// ///    - address: Full formatted address
// ///    - latitude: Precise latitude coordinate
// ///    - longitude: Precise longitude coordinate
// ///
// /// 4. Features available:
// ///    - Interactive map for precise location selection
// ///    - Search functionality for finding places
// ///    - Current location detection
// ///    - Visual marker showing selected location
// ///    - Real-time address updates as you move the map
