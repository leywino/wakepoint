import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'google_place.dart';

part 'google_places_response.g.dart';

@JsonSerializable()
class GooglePlacesResponse extends Equatable {
  final List<GooglePlaceDto>? places;

  const GooglePlacesResponse({this.places});

  factory GooglePlacesResponse.fromJson(Map<String, dynamic> json) =>
      _$GooglePlacesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GooglePlacesResponseToJson(this);

  @override
  List<Object?> get props => [places];
}
