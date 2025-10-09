import 'package:flutter/material.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/models/address.dart';

class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  
  Address? _reverseGeocodedAddress;
  List<Address> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  void _checkConfiguration() {
    if (!GeocodingService.isConfigured) {
      setState(() {
        _error = 'LocationIQ API key not configured. Status: ${GeocodingService.apiKeyStatus}';
      });
    }
  }

  Future<void> _testReverseGeocode() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    
    if (lat == null || lng == null) {
      setState(() {
        _error = 'Please enter valid latitude and longitude';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _reverseGeocodedAddress = null;
    });

    try {
      final address = await GeocodingService.reverseGeocode(
        latitude: lat,
        longitude: lng,
      );
      
      setState(() {
        _reverseGeocodedAddress = address;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testForwardGeocode() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _error = 'Please enter a search query';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _searchResults = [];
    });

    try {
      final results = await GeocodingService.forwardGeocode(
        query: query,
        limit: 5,
        countryCode: 'IN',
      );
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LocationIQ Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Configuration Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          GeocodingService.isConfigured 
                              ? Icons.check_circle 
                              : Icons.error,
                          color: GeocodingService.isConfigured 
                              ? Colors.green 
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(GeocodingService.apiKeyStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Error Display
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              ),
            
            if (_error != null) const SizedBox(height: 16),
            
            // Reverse Geocoding Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reverse Geocoding Test',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              hintText: '12.9716',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              hintText: '77.5946',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _testReverseGeocode,
                        child: _isLoading 
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test Reverse Geocoding'),
                      ),
                    ),
                    
                    if (_reverseGeocodedAddress != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Result:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text('Display Name: ${_reverseGeocodedAddress!.displayName}'),
                            if (_reverseGeocodedAddress!.shortAddress.isNotEmpty)
                              Text('Short Address: ${_reverseGeocodedAddress!.shortAddress}'),
                            if (_reverseGeocodedAddress!.locality != null)
                              Text('Locality: ${_reverseGeocodedAddress!.locality}'),
                            if (_reverseGeocodedAddress!.state != null)
                              Text('State: ${_reverseGeocodedAddress!.state}'),
                            if (_reverseGeocodedAddress!.country != null)
                              Text('Country: ${_reverseGeocodedAddress!.country}'),
                            Text('Coordinates: ${_reverseGeocodedAddress!.latitude}, ${_reverseGeocodedAddress!.longitude}'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Forward Geocoding Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forward Geocoding Test',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Query',
                        hintText: 'Bangalore, India',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _testForwardGeocode(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _testForwardGeocode,
                        child: _isLoading 
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test Forward Geocoding'),
                      ),
                    ),
                    
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Results (${_searchResults.length}):',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            ...(_searchResults.take(3).map((address) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (address.shortAddress.isNotEmpty)
                                    Text('Short: ${address.shortAddress}'),
                                  Text('Coords: ${address.latitude.toStringAsFixed(4)}, ${address.longitude.toStringAsFixed(4)}'),
                                  if (address.locality != null)
                                    Text('Locality: ${address.locality}'),
                                  const Divider(),
                                ],
                              ),
                            ))),
                          ],
                        ),
                      ),
                    ],
                  ],
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
    _searchController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }
}
