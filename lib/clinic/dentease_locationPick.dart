import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPicker({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late GoogleMapController mapController;
  LatLng? selectedLocation;
  String? pickedAddress;

  final String apiKey =
      'AIzaSyB_wMaSJqbHeIY2ruwHRLhOerBXzbefnRg'; // Replace with your API key

  // Tagum City boundaries (approximate)
  final LatLng southwestBoundary = LatLng(7.382, 125.736); // Bottom-left
  final LatLng northeastBoundary = LatLng(7.506, 125.854); // Top-right

  @override
  void initState() {
    super.initState();
    selectedLocation = LatLng(widget.initialLat, widget.initialLng);
    _getAddressFromCoordinates(selectedLocation!);
  }

  /// Check if selected position is within Tagum City
  bool isWithinTagum(LatLng position) {
    return (position.latitude >= southwestBoundary.latitude &&
        position.latitude <= northeastBoundary.latitude &&
        position.longitude >= southwestBoundary.longitude &&
        position.longitude <= northeastBoundary.longitude);
  }

  /// Get address from coordinates using Google Maps API
  Future<void> _getAddressFromCoordinates(LatLng position) async {
    if (!isWithinTagum(position)) {
      setState(() {
        pickedAddress = 'Selected location is outside Tagum City';
      });
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          setState(() {
            pickedAddress = data['results'][0]['formatted_address'];
          });
        } else {
          setState(() {
            pickedAddress = 'No address found';
          });
        }
      } else {
        setState(() {
          pickedAddress = 'Failed to fetch address';
        });
      }
    } catch (e) {
      setState(() {
        pickedAddress = 'Error: $e';
      });
    }
  }

  /// Handle map tap to pick a new location
  void _onMapTapped(LatLng position) {
    if (isWithinTagum(position)) {
      setState(() {
        selectedLocation = position;
        pickedAddress = 'Fetching address...';
      });
      _getAddressFromCoordinates(position);
    } else {
      setState(() {
        selectedLocation = null;
        pickedAddress = 'Selected location is outside Tagum City';
      });
    }
  }

  /// Confirm and return selected location
  void _confirmLocation() {
    if (selectedLocation != null &&
        pickedAddress != null &&
        isWithinTagum(selectedLocation!)) {
      Navigator.pop(context, {
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'address': pickedAddress,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid location within Tagum City.'),
        ),
      );
    }
  }

  /* 
  /// Prevent accidental exit if location is not confirmed
  Future<bool> _confirmExit() async {
    if (selectedLocation == null) {
      return true; // Allow exit if nothing is selected
    }
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit without selecting?'),
            content: const Text(
                'Are you sure you want to leave without selecting a location?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  } 

  add this in widget
  return WillPopScope(
      onWillPop: _confirmExit,
  ),
  
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Pick Location - Tagum City')),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(7.448212, 125.809425),
                zoom: 14,
              ),
              myLocationEnabled: true,
              onMapCreated: (controller) => mapController = controller,
              onTap: _onMapTapped,
              markers: selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: selectedLocation!,
                      ),
                    }
                  : {},
            ),
            // Address Display
            if (pickedAddress != null &&
                pickedAddress != 'Selected location is outside Tagum City')
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    pickedAddress!,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 35, bottom: 16),
            child: FloatingActionButton(
              onPressed: _confirmLocation,
              child: const Icon(Icons.check),
            ),
          ),
        ),
    );
  }
}
