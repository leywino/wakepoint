import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'google_location.dart';
import 'google_display_name.dart';

part 'google_place.g.dart';

@JsonSerializable()
class GooglePlaceDto extends Equatable {
  final String? formattedAddress;
  final GoogleLocation? location;
  final double? rating;
  final GoogleDisplayName? displayName;

  const GooglePlaceDto({
    this.formattedAddress,
    this.location,
    this.rating,
    this.displayName,
  });

  factory GooglePlaceDto.fromJson(Map<String, dynamic> json) =>
      _$GooglePlaceDtoFromJson(json);

  Map<String, dynamic> toJson() => _$GooglePlaceDtoToJson(this);

  @override
  List<Object?> get props =>
      [formattedAddress, location, rating, displayName];
}
