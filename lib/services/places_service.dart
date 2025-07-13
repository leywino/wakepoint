import 'package:dio/dio.dart';
import 'package:wakepoint/config/constants.dart';
import 'package:wakepoint/models/predictions/predictions.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "PlacesService";
void logHere(String message) => log(message, tag: _logTag);

class PlacesService {
  final Dio _dio = Dio();

  Future<Predictions?> fetchPredictions({
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

      logHere("Fetching predictions: $url");

      final response = await _dio.get(url, cancelToken: cancelToken);

      logHere("Response received: ${response.statusCode}");
      return Predictions.fromJson(response.data);
    } catch (e) {
      logHere("Error fetching predictions: $e");
      return null;
    }
  }
}
