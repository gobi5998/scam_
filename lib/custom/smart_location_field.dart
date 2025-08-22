import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class SmartLocationField extends StatefulWidget {
  final Function(String address, Map<String, dynamic> coordinates)?
  onLocationChanged;
  final String? initialAddress;
  final String? label;
  final String? hint;

  const SmartLocationField({
    Key? key,
    this.onLocationChanged,
    this.initialAddress,
    this.label = 'Location',
    this.hint = 'Enter address or get current location',
  }) : super(key: key);

  @override
  State<SmartLocationField> createState() => _SmartLocationFieldState();
}

class _SmartLocationFieldState extends State<SmartLocationField> {
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();

  bool _isOnline = true;
  bool _isLoadingLocation = false;
  bool _isManualMode = false;
  Map<String, dynamic>? _currentCoordinates;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialAddress ?? '';
    _checkConnectivity();
    _setupConnectivityListener();

    // If online, try to get current location automatically
    if (_isOnline) {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });

      // If coming back online, try to get current location
      if (_isOnline && !_isManualMode) {
        _getCurrentLocation();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!_isOnline) {
      print('📱 Offline mode - cannot get current location');
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      print('📍 Getting current location...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        _showError(
          'Location services are disabled. Please enable location services.',
        );
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          _showError(
            'Location permission denied. Please enable location permission.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied forever');
        _showError(
          'Location permission denied forever. Please enable in settings.',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('✅ Location obtained: ${position.latitude}, ${position.longitude}');

      // Get real address using geocoding
      String address = '${position.latitude}, ${position.longitude}';

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks[0];
          address = [
            placemark.street,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        }
      } catch (e) {
        print('❌ Error getting address from coordinates: $e');
        // Keep the coordinates as fallback
        address = '${position.latitude}, ${position.longitude}';
      }

      setState(() {
        _currentCoordinates = {
          'type': 'Point',
          'coordinates': [
            position.longitude,
            position.latitude,
          ], // [lng, lat] format
        };
        _currentAddress = address;
        _addressController.text = address;
        _isLoadingLocation = false;
        _isManualMode = false;
      });

      // Notify parent
      widget.onLocationChanged?.call(address, _currentCoordinates!);

      _showSuccess('Current location obtained successfully');
    } catch (e) {
      print('❌ Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      _showError('Failed to get current location: $e');
    }
  }

  void _saveManualAddress() {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError('Please enter an address');
      return;
    }

    setState(() {
      _currentAddress = address;
      _isManualMode = true;
      // For manual address, we'll use approximate coordinates (0,0) or null
      _currentCoordinates = null;
    });

    // Notify parent
    widget.onLocationChanged?.call(address, _currentCoordinates ?? {});

    _showSuccess('Address saved successfully');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isOnline ? Colors.green.shade200 : Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: _isOnline
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
              ),
              SizedBox(width: 8),
              Text(
                _isOnline ? 'Online - Auto location' : 'Offline - Manual input',
                style: TextStyle(
                  fontSize: 12,
                  color: _isOnline
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Location field
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: OutlineInputBorder(),
            suffixIcon: _isOnline && !_isManualMode
                ? IconButton(
                    icon: _isLoadingLocation
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.my_location),
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    tooltip: 'Get current location',
                  )
                : null,
          ),
          maxLines: 2,
          enabled: !_isOnline || _isManualMode,
        ),

        SizedBox(height: 8),

        // Action buttons
        Row(
          children: [
            if (_isOnline && !_isManualMode)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                  icon: _isLoadingLocation
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.my_location, size: 16),
                  label: Text(
                    _isLoadingLocation
                        ? 'Getting Location...'
                        : 'Get Current Location',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            if (!_isOnline || _isManualMode) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveManualAddress,
                  icon: Icon(Icons.save, size: 16),
                  label: Text('Save Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (_isManualMode)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isManualMode = false;
                      });
                      _getCurrentLocation();
                    },
                    icon: Icon(Icons.my_location, size: 16),
                    label: Text('Use GPS'),
                  ),
                ),
            ],
          ],
        ),

        // Current location info
        if (_currentAddress != null) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Location:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(_currentAddress!, style: TextStyle(fontSize: 12)),
                if (_currentCoordinates != null) ...[
                  SizedBox(height: 4),
                  Text(
                    'Coordinates: ${_currentCoordinates!['coordinates'][1].toStringAsFixed(6)}, ${_currentCoordinates!['coordinates'][0].toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
