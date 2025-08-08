import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerScreen extends StatefulWidget {
  final Function(String, String)? onLocationSelected;
  final List<SavedAddress>? savedAddresses;

  const LocationPickerScreen({
    Key? key,
    this.onLocationSelected,
    this.savedAddresses,
  }) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Placemark> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  String? _currentLocationAddress;
  bool _isLoadingCurrentLocation = false;

  List<SavedAddress> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _getCurrentLocation();
  }

  void _loadSavedAddresses() {
    _savedAddresses =
        widget.savedAddresses ??
        [
          SavedAddress(
            id: '1',
            label: 'Home',
            address:
                'No:25, Pon Nagar, Kavery Nagar, Reddiarpalayam, Puducherry, India',
            isSelected: true,
          ),
        ];
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingCurrentLocation = true;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(() {
          _currentLocationAddress = _formatAddress(placemarks[0]);
        });
      }
    } catch (e) {
      print('Error getting current location: $e');
    } finally {
      setState(() {
        _isLoadingCurrentLocation = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      List<Placemark> placemarks = [];

      for (Location location in locations.take(5)) {
        List<Placemark> placemarkList = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        if (placemarkList.isNotEmpty) {
          placemarks.add(placemarkList.first);
        }
      }

      setState(() {
        _searchResults = placemarks;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];

    if (placemark.street != null && placemark.street!.isNotEmpty) {
      addressParts.add(placemark.street!);
    }

    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    }

    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty) {
      addressParts.add(placemark.administrativeArea!);
    }

    if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
      addressParts.add(placemark.postalCode!);
    }

    if (placemark.country != null && placemark.country!.isNotEmpty) {
      addressParts.add(placemark.country!);
    }

    return addressParts.join(', ');
  }

  void _onPlaceSelected(Placemark placemark) {
    String address = _formatAddress(placemark);
    String locationName =
        placemark.name ?? placemark.locality ?? 'Selected Location';

    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(locationName, address);
    }

    Navigator.of(context).pop();
  }

  void _onCurrentLocationSelected() {
    if (_currentLocationAddress != null) {
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(
          'Current Location',
          _currentLocationAddress!,
        );
      }
      Navigator.of(context).pop();
    }
  }

  void _onSavedAddressSelected(SavedAddress address) {
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(address.label, address.address);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Enter your location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance the back button
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Try JP Nagar, Siri Gardenia, etc.',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _searchPlaces(value);
                        } else {
                          setState(() {
                            _searchResults = [];
                            _showResults = false;
                          });
                        }
                      },
                    ),
                  ),

                  // Search Results
                  if (_showResults && _searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          Placemark placemark = _searchResults[index];
                          String address = _formatAddress(placemark);

                          return ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                            ),
                            title: Text(
                              placemark.name ??
                                  placemark.locality ??
                                  'Unknown Location',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _onPlaceSelected(placemark),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Current Location Option
                  InkWell(
                    onTap: _isLoadingCurrentLocation
                        ? null
                        : _onCurrentLocationSelected,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.send, color: Colors.orange[600], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Use my current location',
                              style: TextStyle(
                                color: Colors.orange[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_isLoadingCurrentLocation)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Add New Address Option
                  // InkWell(
                  //   onTap: () {
                  //     // TODO: Implement add new address functionality
                  //   },
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(vertical: 12),
                  //     child: Row(
                  //       children: [
                  //         Icon(
                  //           Icons.add,
                  //           color: Colors.orange[600],
                  //           size: 20,
                  //         ),
                  //         const SizedBox(width: 12),
                  //         Text(
                  //           'Add new address',
                  //           style: TextStyle(
                  //             color: Colors.orange[600],
                  //             fontSize: 16,
                  //             fontWeight: FontWeight.w500,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),

                  // const SizedBox(height: 24),

                  // Saved Addresses Section
                  // if (_savedAddresses.isNotEmpty) ...[
                  //   Text(
                  //     'SAVED ADDRESSES',
                  //     style: TextStyle(
                  //       color: Colors.grey[600],
                  //       fontSize: 14,
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  //   const SizedBox(height: 12),
                  //   Expanded(
                  //     child: ListView.builder(
                  //       itemCount: _savedAddresses.length,
                  //       itemBuilder: (context, index) {
                  //         return _buildSavedAddressCard(_savedAddresses[index]);
                  //       },
                  //     ),
                  //   ),
                  // ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAddressCard(SavedAddress address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.home, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      address.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (address.isSelected) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[400],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'CURRENTLY SELECTED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address.address,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

// Static method to show location picker as bottom sheet
class LocationPickerBottomSheet {
  static void show(
    BuildContext context, {
    Function(String, String)? onLocationSelected,
    List<SavedAddress>? savedAddresses,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPickerScreen(
        onLocationSelected: onLocationSelected,
        savedAddresses: savedAddresses,
      ),
    );
  }
}

class SavedAddress {
  final String id;
  final String label;
  final String address;
  final bool isSelected;

  SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.isSelected = false,
  });
}

// Add New Address Screen
class AddNewAddressScreen extends StatefulWidget {
  final Function(String, String) onAddressAdded;

  const AddNewAddressScreen({Key? key, required this.onAddressAdded})
    : super(key: key);

  @override
  State<AddNewAddressScreen> createState() => _AddNewAddressScreenState();
}

class _AddNewAddressScreenState extends State<AddNewAddressScreen> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Address'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Address Label (e.g., Home, Office)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Full Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_labelController.text.isNotEmpty &&
                    _addressController.text.isNotEmpty) {
                  widget.onAddressAdded(
                    _labelController.text,
                    _addressController.text,
                  );
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Address',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
