import 'package:wakepoint/models/place.dart';
import 'google_place.dart';

class GooglePlace implements Place {
  final GooglePlaceDto dto;

  GooglePlace(this.dto);

  @override
  String get name => dto.displayName?.text ?? 'Unknown';

  @override
  String get address => dto.formattedAddress ?? 'Unknown';

  @override
  double get latitude => dto.location?.latitude ?? 0.0;

  @override
  double get longitude => dto.location?.longitude ?? 0.0;

  @override
  double? get rating => dto.rating;
}
