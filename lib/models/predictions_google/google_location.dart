import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'google_location.g.dart';

@JsonSerializable()
class GoogleLocation extends Equatable {
  final double? latitude;
  final double? longitude;

  const GoogleLocation({this.latitude, this.longitude});

  factory GoogleLocation.fromJson(Map<String, dynamic> json) =>
      _$GoogleLocationFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleLocationToJson(this);

  @override
  List<Object?> get props => [latitude, longitude];
}
