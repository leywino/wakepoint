import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'geometry.dart';
part 'prediction.g.dart';

@JsonSerializable()
class Prediction extends Equatable {
  final String? description;
  final Geometry? geometry;

  const Prediction({
    this.description,
    this.geometry,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return _$PredictionFromJson(json);
  }

  Map<String, dynamic> toJson() => _$PredictionToJson(this);

  Prediction copyWith({
    String? description,
    Geometry? geometry,
  }) {
    return Prediction(
      description: description ?? this.description,
      geometry: geometry ?? this.geometry,
    );
  }

  @override
  List<Object?> get props {
    return [
      description,
      geometry,
    ];
  }
}
