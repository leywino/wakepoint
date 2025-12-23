import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'location.g.dart';

@JsonSerializable()
class Location extends Equatable {
	final num? lng;
	final num? lat;

	const Location({this.lng, this.lat});

	factory Location.fromJson(Map<String, dynamic> json) {
		return _$LocationFromJson(json);
	}

	Map<String, dynamic> toJson() => _$LocationToJson(this);

	Location copyWith({
		num? lng,
		num? lat,
	}) {
		return Location(
			lng: lng ?? this.lng,
			lat: lat ?? this.lat,
		);
	}

	@override
	List<Object?> get props => [lng, lat];
}
