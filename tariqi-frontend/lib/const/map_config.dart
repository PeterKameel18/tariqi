/// Centralized map tile configuration.
/// CartoDB Voyager provides a clean, modern map style with good readability.
abstract class MapConfig {
  static const String tileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];
  static const String packageName = 'com.tariqi.app';
}
