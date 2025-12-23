import 'package:wakepoint/models/place.dart';
import 'package:wakepoint/models/predictions_ola/prediction.dart';


class OlaPlace implements Place {
  final Prediction prediction;
  @override
  final double? rating;

  OlaPlace({required this.prediction, this.rating});

  factory OlaPlace.fromPrediction(Prediction prediction) =>
      OlaPlace(prediction: prediction, rating: null);

  @override
  String get name => prediction.description ?? 'Unknown';

  @override
  String get address => prediction.description ?? 'Unknown';

  @override
  double get latitude => prediction.geometry?.location?.lat?.toDouble() ?? 0.0;

  @override
  double get longitude => prediction.geometry?.location?.lng?.toDouble() ?? 0.0;
}
