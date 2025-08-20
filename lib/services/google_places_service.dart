import 'package:http/http.dart' as http;
import 'dart:convert';

class GooglePlacesService {
  static const String _apiKey = 'AIzaSyBIeWGWnjG2D5mU3cbnT7jJV5RTWdsrAOw';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  /// Search for places using Google Places API
  static Future<List<PlaceResult>> searchPlaces(String query) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?input=$query&key=$_apiKey&types=geocode'
      );


      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((prediction) => PlaceResult.fromJson(prediction)).toList();
        } else {
          print('Google Places API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          return [];
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  /// Get place details using place_id
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json?place_id=$placeId&fields=formatted_address,geometry,name,place_id&key=$_apiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          print('Google Places Details API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }

  /// Search for places with location bias (near current location)
  static Future<List<PlaceResult>> searchPlacesNearby(
    String query,
    double latitude,
    double longitude,
    {int radius = 50000} // 50km radius
  ) async {
    try {
      final location = '$latitude,$longitude';
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?input=$query&key=$_apiKey&types=geocode&location=$location&radius=$radius'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((prediction) => PlaceResult.fromJson(prediction)).toList();
        } else {
          print('Google Places API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          return [];
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching places nearby: $e');
      return [];
    }
  }

  /// Get exact address from coordinates using Google Geocoding API
  static Future<PlaceDetails?> getAddressFromCoordinates(
    double latitude,
    double longitude
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json?latlng=$latitude,$longitude&key=$_apiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          return PlaceDetails.fromGeocodingResult(result);
        } else {
          print('Google Geocoding API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }
}

class PlaceResult {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;

  PlaceResult({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] ?? {};

    return PlaceResult(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting['main_text'] ?? '',
      secondaryText: structuredFormatting['secondary_text'] ?? '',
      types: List<String>.from(json['types'] ?? []),
    );
  }

  @override
  String toString() {
    return 'PlaceResult(placeId: $placeId, description: $description, mainText: $mainText, secondaryText: $secondaryText)';
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double? latitude;
  final double? longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.latitude,
    this.longitude,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};

    return PlaceDetails(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      latitude: location['lat']?.toDouble(),
      longitude: location['lng']?.toDouble(),
    );
  }

  factory PlaceDetails.fromGeocodingResult(Map<String, dynamic> json) {
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};

    return PlaceDetails(
      placeId: json['place_id'] ?? '',
      name: json['formatted_address']?.split(',').first ?? 'Current Location',
      formattedAddress: json['formatted_address'] ?? '',
      latitude: location['lat']?.toDouble(),
      longitude: location['lng']?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'PlaceDetails(placeId: $placeId, name: $name, formattedAddress: $formattedAddress, lat: $latitude, lng: $longitude)';
  }
}
