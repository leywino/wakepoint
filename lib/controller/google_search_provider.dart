// google_places_provider.dart
import 'package:dio/dio.dart';
import 'package:wakepoint/controller/place_search_provider.dart';
import 'package:wakepoint/models/place.dart';
import 'package:wakepoint/services/places_service.dart';

class GoogleSearchProvider implements PlacesSearchProvider {
  final PlacesService _service = PlacesService();

  @override
  Future<List<Place>> search({
    required String query,
    required String apiKey,
    double? lat,
    double? lng,
    CancelToken? cancelToken,
  }) {
    return _service.fetchGooglePlaces(
      apiKey: apiKey,
      query: query,
      lat: lat,
      lng: lng,
      cancelToken: cancelToken,
    );
  }
}
