import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/api_data/api_keys.dart';
import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/web_services/dio_config.dart';

const _egyptBounds = '24.7,22.0,36.9,31.9';
const _egyptBiasLat = 30.0444;
const _egyptBiasLng = 31.2357;

bool _querySuggestsEgypt(String query) {
  final normalized = query.toLowerCase();
  return normalized.contains('egypt') ||
      normalized.contains('cairo') ||
      normalized.contains('giza') ||
      normalized.contains('maadi') ||
      normalized.contains('mohandessin') ||
      normalized.contains('dokki') ||
      normalized.contains('zamalek') ||
      normalized.contains('rehab') ||
      normalized.contains('madinaty') ||
      normalized.contains('zayed') ||
      normalized.contains('sheikh zayed') ||
      normalized.contains('october') ||
      normalized.contains('6 october') ||
      normalized.contains('6th of october') ||
      normalized.contains('tagamoa') ||
      normalized.contains('tagamo3') ||
      normalized.contains('fifth settlement') ||
      normalized.contains('new cairo') ||
      normalized.contains('nasr city') ||
      normalized.contains('heliopolis') ||
      normalized.contains('masr el gedida');
}

String _biasQueryToEgypt(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty || _querySuggestsEgypt(trimmed)) {
    return trimmed;
  }
  return '$trimmed, Egypt';
}

Map<String, dynamic>? _pickEgyptAwareResult(dynamic results) {
  if (results is! List || results.isEmpty) {
    return null;
  }

  final normalizedResults = results.whereType<Map>().map((entry) {
    return Map<String, dynamic>.from(entry);
  }).toList();

  for (final result in normalizedResults) {
    final components = result['components'];
    if (components is Map) {
      final countryCode = (components['country_code'] ?? '')
          .toString()
          .toLowerCase();
      if (countryCode == 'eg') {
        return result;
      }
    }
  }

  return normalizedResults.first;
}

String? _buildReadableReverseLabel(Map<String, dynamic> result) {
  final components = result['components'];
  if (components is! Map) {
    return result['formatted']?.toString();
  }

  final road = components['road']?.toString();
  final neighbourhood = components['neighbourhood']?.toString();
  final suburb = components['suburb']?.toString();
  final city = components['city']?.toString() ??
      components['town']?.toString() ??
      components['county']?.toString() ??
      components['state_district']?.toString();

  final parts = <String>[
    if (road != null && road.trim().isNotEmpty) road.trim(),
    if (neighbourhood != null &&
        neighbourhood.trim().isNotEmpty &&
        neighbourhood.trim() != road?.trim())
      neighbourhood.trim(),
    if (suburb != null &&
        suburb.trim().isNotEmpty &&
        suburb.trim() != neighbourhood?.trim())
      suburb.trim(),
    if (city != null && city.trim().isNotEmpty) city.trim(),
  ];

  if (parts.isNotEmpty) {
    return parts.take(3).join(', ');
  }

  return result['formatted']?.toString();
}

class ClientLocationCordinatesRepo {
  final DioClient dioClient;

  ClientLocationCordinatesRepo({required this.dioClient});

  Future<Map<String, dynamic>?> _fetchBestResult(
    Map<String, dynamic> queryParameters,
  ) async {
    final response = await dioClient.client.get(
      ApiLinks.geoCodebaseUrl,
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      return null;
    }

    return _pickEgyptAwareResult(response.data['results']);
  }

  Future<LatLng?> getClientLocationCordinates({
    required String location,
  }) async {
    final selectedResult =
        await _fetchBestResult({
          'q': _biasQueryToEgypt(location),
          'key': ApiKeys.geoCodingKey,
          'countrycode': 'eg',
          'bounds': _egyptBounds,
          'proximity': '$_egyptBiasLat,$_egyptBiasLng',
          'limit': 5,
          'no_annotations': 1,
        }) ??
        await _fetchBestResult({
          'q': location.trim(),
          'key': ApiKeys.geoCodingKey,
          'proximity': '$_egyptBiasLat,$_egyptBiasLng',
          'limit': 5,
          'no_annotations': 1,
        });

    if (selectedResult != null) {
      final geometry = selectedResult['geometry'];
      if (geometry is! Map) {
        return null;
      }
      final lat = geometry['lat'];
      final lng = geometry['lng'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
      return null;
    }

    return null;
  }
}

class ClientLocationNameRepo {
  final DioClient dioClient;

  ClientLocationNameRepo({required this.dioClient});

  Future<String?> getClientLocationName({
    required double lat,
    required double long,
  }) async {
    var response = await dioClient.client.get(
      ApiLinks.geoCodebaseUrl,
      queryParameters: {
        'q': '$lat,$long',
        'key': ApiKeys.geoCodingKey,
        'pretty': 1,
        'language': 'en',
        'countrycode': 'eg',
        'no_annotations': 1,
      },
    );
    if (response.statusCode == 200) {
      final selectedResult = _pickEgyptAwareResult(response.data['results']);
      if (selectedResult == null) {
        return null;
      }
      return _buildReadableReverseLabel(selectedResult);
    } else {
      return null;
    }
  }
}
