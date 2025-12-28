// places_search_provider.dart
import 'package:dio/dio.dart';
import 'package:wakepoint/models/place.dart';

abstract class PlacesSearchProvider {
  Future<List<Place>> search({
    required String query,
    required String apiKey,
    double? lat,
    double? lng,
    CancelToken? cancelToken,
  });
}
