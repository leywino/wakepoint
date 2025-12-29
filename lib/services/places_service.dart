import 'package:dio/dio.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/models/predictions_google/google_place_adapter.dart';
import 'package:wakepoint/models/predictions_google/google_places_response.dart';
import 'package:wakepoint/models/predictions_ola/ola_places.dart';
import 'package:wakepoint/models/predictions_ola/predictions.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "PlacesService";
void logHere(String message) => log(message, tag: _logTag);

class PlacesService {
  final Dio _dio = Dio();

  /// LOW-LEVEL (optional): raw Ola response
  Future<Predictions?> fetchOlaRaw({
    required String apiKey,
    required String query,
    double? lat,
    double? lng,
    CancelToken? cancelToken,
  }) async {
    try {
      String baseUrl = endpointAutocomplete;
      String location =
          (lat != null && lng != null) ? "&location=$lat%2C$lng" : "";
      String types = "&types=locality";
      String url =
          "$baseUrl?input=${Uri.encodeComponent(query)}$location$types&api_key=$apiKey";

      logHere("Fetching Ola predictions: $url");

      final response = await _dio.get(url, cancelToken: cancelToken);

      return Predictions.fromJson(response.data);
    } catch (e) {
      logHere("Error fetching Ola predictions: $e");
      return null;
    }
  }

  /// HIGH-LEVEL: what your app should actually use
  Future<List<OlaPlace>> fetchOlaPlaces({
    required String apiKey,
    required String query,
    double? lat,
    double? lng,
    CancelToken? cancelToken,
  }) async {
    final predictions = await fetchOlaRaw(
      apiKey: apiKey,
      query: query,
      lat: lat,
      lng: lng,
      cancelToken: cancelToken,
    );

    if (predictions?.predictions == null) return [];

    return predictions!.predictions!.map(OlaPlace.fromPrediction).toList();
  }

  Future<List<GooglePlace>> fetchGooglePlaces({
    required String apiKey,
    required String query,
    double? lat,
    double? lng,
    CancelToken? cancelToken,
  }) async {
    log(apiKey);
    final response = await _dio.post(
      googlePlacesSearchEndpoint,
      options: Options(
        headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
              'places.displayName,places.formattedAddress,places.location,places.rating',
        },
      ),
      data: {
        'textQuery': query,
        if (lat != null && lng != null)
          'locationBias': {
            'circle': {
              'center': {'latitude': lat, 'longitude': lng},
              'radius': 5000,
            }
          }
      },
      cancelToken: cancelToken,
    );

    log(response.toString());

    final parsed = GooglePlacesResponse.fromJson(response.data);

    return parsed.places?.map((dto) => GooglePlace(dto)).toList() ?? [];
  }
}
