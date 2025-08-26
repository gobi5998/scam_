import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../services/location_storage_service.dart';
import '../services/google_places_service.dart';

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

  List<PlaceResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  String? _currentLocationAddress;
  bool _isLoadingCurrentLocation = false;
  Position? _currentPosition;

  List<SavedAddress> _savedAddresses = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _getCurrentLocationWithFallback();
  }

  Future<void> _getCurrentLocationWithFallback() async {
    try {
      await _getCurrentLocation();
    } catch (e) {
      print('Primary location method failed, trying last known location...');
      await _getLastKnownLocation();
    }
  }

  Future<void> _getLastKnownLocation() async {
    try {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        setState(() {
          _currentPosition = lastKnownPosition;
        });

        print('📍 Using last known position: ${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}');

        // Get address for last known position
        final placeDetails = await GooglePlacesService.getAddressFromCoordinates(
          lastKnownPosition.latitude,
          lastKnownPosition.longitude,
        );

        if (placeDetails != null) {
          setState(() {
            _currentLocationAddress = placeDetails.formattedAddress;
          });
          print('✅ Last known location obtained: ${placeDetails.formattedAddress}');
        }
      }
    } catch (e) {
      print('Error getting last known location: $e');
    }
  }

  void _loadSavedAddresses() async {
    final saved = await LocationStorageService.getSavedAddresses();
    setState(() {
      _savedAddresses =
      (widget.savedAddresses ??
          saved
              .map(
                (e) => SavedAddress(
              id: e['savedAt'] ?? e['label'] ?? DateTime.now().toString(),
              label: e['label'] ?? 'Saved',
              address: e['address'] ?? '',
            ),
          )
              .toList());
    });
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

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
      });

      print('📍 GPS Coordinates obtained: ${position.latitude}, ${position.longitude}');
      print('📍 Accuracy: ${position.accuracy} meters');

      // Use Google Geocoding API for more accurate address
      final placeDetails = await GooglePlacesService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placeDetails != null) {
        setState(() {
          _currentLocationAddress = placeDetails.formattedAddress;
        });
        print('✅ Current location obtained via Google API: ${placeDetails.formattedAddress}');
      } else {
        // Fallback to basic geocoding if Google API fails
        print('⚠️ Google API failed, trying fallback geocoding...');
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          setState(() {
            _currentLocationAddress = _formatAddress(placemarks[0]);
          });
          print('⚠️ Using fallback geocoding: ${_currentLocationAddress}');
        } else {
          throw Exception('Could not get address from coordinates');
        }
      }
    } catch (e) {
      print('Error getting current location: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting current location: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _getCurrentLocation,
            ),
          ),
        );
      }
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
      List<PlaceResult> results;
      
      // If we have current position, search nearby for better results
      if (_currentPosition != null) {
        results = await GooglePlacesService.searchPlacesNearby(
          query,
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      } else {
        results = await GooglePlacesService.searchPlaces(query);
      }

      setState(() {
        _searchResults = results;
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

  void _onPlaceSelected(PlaceResult placeResult) async {
    try {
      // Get detailed place information
      final placeDetails = await GooglePlacesService.getPlaceDetails(placeResult.placeId);
      
      String locationName = placeResult.mainText.isNotEmpty 
          ? placeResult.mainText 
          : placeResult.description.split(',').first;
      String address = placeDetails?.formattedAddress ?? placeResult.description;

      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(locationName, address);
      }

      // Persist for offline reuse
      LocationStorageService.addSavedAddress(
        label: locationName,
        address: address,
      );
      LocationStorageService.saveLastSelectedAddress(
        label: locationName,
        address: address,
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('Error getting place details: $e');
      // Fallback to using the description
      String locationName = placeResult.mainText.isNotEmpty 
          ? placeResult.mainText 
          : placeResult.description.split(',').first;
      String address = placeResult.description;

      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(locationName, address);
      }

      Navigator.of(context).pop();
    }
  }

  void _onCurrentLocationSelected() {
    if (_currentLocationAddress != null && _currentPosition != null) {
      // Create a more descriptive location name
      String locationName = 'Current Location';
      
      // Try to extract a meaningful name from the address
      if (_currentLocationAddress!.contains(',')) {
        locationName = _currentLocationAddress!.split(',').first.trim();
        if (locationName.isEmpty) {
          locationName = 'Current Location';
        }
      }

      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(
          locationName,
          _currentLocationAddress!,
        );
      }
      
      // Save with coordinates for better accuracy
      LocationStorageService.saveLastSelectedAddress(
        label: locationName,
        address: _currentLocationAddress!,
      );
      
      print('📍 Current location selected: $locationName - ${_currentLocationAddress}');
      print('📍 Coordinates: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      
      Navigator.of(context).pop();
    } else {
      // Show error if location is not available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location not available. Please try again.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _onSavedAddressSelected(SavedAddress address) {
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(address.label, address.address);
    }
    LocationStorageService.saveLastSelectedAddress(
      label: address.label,
      address: address.address,
    );
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
                        // Cancel previous timer
                        _debounceTimer?.cancel();
                        
                        if (value.isNotEmpty) {
                          // Set a new timer for debouncing
                          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                            _searchPlaces(value);
                          });
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
                  if (_showResults)
                    if (_isSearching)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(16),
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
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Searching for locations...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_searchResults.isNotEmpty)
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
                          PlaceResult placeResult = _searchResults[index];

                          return ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                            ),
                            title: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                                children: _buildHighlightedText(
                                  placeResult.mainText.isNotEmpty 
                                      ? placeResult.mainText 
                                      : placeResult.description.split(',').first,
                                  _searchController.text,
                                ),
                              ),
                            ),
                            subtitle: Text(
                              placeResult.secondaryText.isNotEmpty 
                                  ? placeResult.secondaryText 
                                  : placeResult.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            onTap: () => _onPlaceSelected(placeResult),
                          );
                        },
                      ),
                    )
                    else if (_searchController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(16),
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
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_off,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'No locations found for "${_searchController.text}"',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
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
                          Icon(Icons.my_location, color: Colors.blue[600], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Use my current location',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_currentLocationAddress != null)
                                  Text(
                                    _currentLocationAddress!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (_isLoadingCurrentLocation)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_currentLocationAddress != null)
                            const Icon(Icons.arrow_forward_ios, size: 16)
                          else
                            IconButton(
                              icon: Icon(Icons.refresh, color: Colors.blue[600], size: 20),
                              onPressed: _getCurrentLocation,
                            ),
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

  List<TextSpan> _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final int index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return spans;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
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