import 'package:get/get.dart';
import 'package:tariqi/client_repo/location_repo.dart';
import 'package:tariqi/web_services/dio_config.dart';

class LocationDisplayHelper {
  static final Map<String, String> _resolvedCache = <String, String>{};
  static final RegExp _coordinatePattern = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
  );

  static String formatCompactCoordinates(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  static String immediateLabel(dynamic value, {required String fallback}) {
    final directLabel = _extractDirectLabel(value);
    if (directLabel != null && directLabel.isNotEmpty) {
      return directLabel;
    }

    final coordinates = extractCoordinates(value);
    if (coordinates != null) {
      return formatCompactCoordinates(
        coordinates.$1,
        coordinates.$2,
      );
    }

    return fallback;
  }

  static Future<String> resolveLabel(
    dynamic value, {
    required String fallback,
  }) async {
    final directLabel = _extractDirectLabel(value);
    if (directLabel != null && directLabel.isNotEmpty) {
      return directLabel;
    }

    final coordinates = extractCoordinates(value);
    if (coordinates == null) {
      return fallback;
    }

    final cacheKey =
        '${coordinates.$1.toStringAsFixed(5)},${coordinates.$2.toStringAsFixed(5)}';
    final cached = _resolvedCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final repo = ClientLocationNameRepo(dioClient: Get.find<DioClient>());
      final resolved = await repo.getClientLocationName(
        lat: coordinates.$1,
        long: coordinates.$2,
      );
      final compactAddress = _compactAddress(resolved);
      if (compactAddress != null && compactAddress.isNotEmpty) {
        _resolvedCache[cacheKey] = compactAddress;
        return compactAddress;
      }
    } catch (_) {}

    final coordinateLabel = formatCompactCoordinates(
      coordinates.$1,
      coordinates.$2,
    );
    _resolvedCache[cacheKey] = coordinateLabel;
    return coordinateLabel;
  }

  static (double, double)? extractCoordinates(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final lat = map['lat'];
      final lng = map['lng'];
      if (lat is num && lng is num) {
        return (lat.toDouble(), lng.toDouble());
      }
    }

    if (value is String) {
      final match = _coordinatePattern.firstMatch(value.trim());
      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);
        if (lat != null && lng != null) {
          return (lat, lng);
        }
      }
    }

    return null;
  }

  static String? _extractDirectLabel(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '{}' || trimmed == 'null') {
        return null;
      }
      if (_coordinatePattern.hasMatch(trimmed)) {
        return null;
      }
      return _compactAddress(trimmed) ?? trimmed;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'address',
        'formatted',
        'display_name',
        'name',
        'label',
      ]) {
        final candidate = map[key]?.toString().trim();
        if (candidate != null &&
            candidate.isNotEmpty &&
            candidate != '{}' &&
            candidate != 'null') {
          return _compactAddress(candidate) ?? candidate;
        }
      }
    }

    return null;
  }

  static String? _compactAddress(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;

    final parts = normalized
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) => !RegExp(r'^\d+$').hasMatch(part))
        .toList();

    if (parts.isEmpty) {
      return normalized;
    }

    final filteredParts = parts.where((part) {
      final lower = part.toLowerCase();
      return lower != 'egypt' && lower != 'eg';
    }).toList();

    final displayParts = (filteredParts.isNotEmpty ? filteredParts : parts)
        .take(3)
        .toList();
    return displayParts.join(', ');
  }
}
