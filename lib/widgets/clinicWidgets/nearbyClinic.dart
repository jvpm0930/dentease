import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class ClinicMapPage extends StatefulWidget {
  const ClinicMapPage({super.key});

  @override
  State<ClinicMapPage> createState() => _ClinicMapPageState();
}

class _ClinicMapPageState extends State<ClinicMapPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final Set<Polyline> _polylines = {};


  LatLng? _currentPosition;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocationAndClinics();
  }

  Future<void> _initLocationAndClinics() async {
    try {
      await _getCurrentLocation();
      await _fetchClinicLocations();
    } catch (e) {
      print('Error: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _drawRoute(LatLng destination) async {
    const apiKey = 'AIzaSyB_wMaSJqbHeIY2ruwHRLhOerBXzbefnRg'; // Replace with your API key
    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final dest = '${destination.latitude},${destination.longitude}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&key=$apiKey',
    );

    final response = await http.get(url);

    print("Polyline URL: $url");
    print("Polyline response: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final points = data['routes'][0]['overview_polyline']['points'];

      final List<LatLng> polylinePoints =
          _decodePolyline(points).map((p) => LatLng(p[0], p[1])).toList();

      print("Decoded ${polylinePoints.length} polyline points");

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePoints,
          color: Colors.blue,
          width: 5,
        ));
      });

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude <= destination.latitude
              ? _currentPosition!.latitude
              : destination.latitude,
          _currentPosition!.longitude <= destination.longitude
              ? _currentPosition!.longitude
              : destination.longitude,
        ),
        northeast: LatLng(
          _currentPosition!.latitude > destination.latitude
              ? _currentPosition!.latitude
              : destination.latitude,
          _currentPosition!.longitude > destination.longitude
              ? _currentPosition!.longitude
              : destination.longitude,
        ),
      );

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));

    } else {
      print('Failed to load directions');
    }
  }


  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> polyline = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add([lat / 1E5, lng / 1E5]);
    }

    return polyline;
  }



  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _currentPosition = LatLng(position.latitude, position.longitude);

    _markers.add(Marker(
      markerId: const MarkerId('you'),
      position: _currentPosition!,
      infoWindow: const InfoWindow(title: "You are here"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));
  }

  Future<void> _fetchClinicLocations() async {
    final response = await supabase
        .from('clinics')
        .select('clinic_id, clinic_name, latitude, longitude')
        .eq('status', 'approved');

    for (var clinic in response) {
      final lat = clinic['latitude'];
      final lng = clinic['longitude'];

      if (lat != null && lng != null) {
        final double? latitude = double.tryParse(lat.toString());
        final double? longitude = double.tryParse(lng.toString());

        if (latitude != null && longitude != null && _currentPosition != null) {
          // Calculate distance in meters
          final double distanceInMeters = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            latitude,
            longitude,
          );

          // Convert to km with 1 decimal
          final distanceInKm = (distanceInMeters / 1000).toStringAsFixed(1);

          // Add clinic marker with distance in infoWindow
          _markers.add(
            Marker(
              markerId: MarkerId(clinic['clinic_id'].toString()),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(
                title: clinic['clinic_name'],
                snippet: '$distanceInKm km away',
              ),
              onTap: () => _drawRoute(LatLng(latitude, longitude)),
            ),
          );

        }
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Clinics"),
        centerTitle: true,
      ),
      body: isLoading || _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _markers,
              polylines: _polylines, // ← Add this line
            ),

    );
  }
}
