import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'location.dart';

part 'geometry.g.dart';

@JsonSerializable()
class Geometry extends Equatable {
  final Location? location;

  const Geometry({this.location});

  factory Geometry.fromJson(Map<String, dynamic> json) => _$GeometryFromJson(json);

  Map<String, dynamic> toJson() => _$GeometryToJson(this);

  Geometry copyWith({Location? location}) => Geometry(
        location: location ?? this.location,
      );

  @override
  List<Object?> get props => [location];
}
