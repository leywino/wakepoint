import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'geometry.dart';
import 'matched_substring.dart';
import 'structured_formatting.dart';
import 'term.dart';

part 'prediction.g.dart';

@JsonSerializable()
class Prediction extends Equatable {
	final String? reference;
	final List<String>? types;
	@JsonKey(name: 'matched_substrings') 
	final List<MatchedSubstring>? matchedSubstrings;
	final List<Term>? terms;
	@JsonKey(name: 'distance_meters') 
	final num? distanceMeters;
	@JsonKey(name: 'structured_formatting') 
	final StructuredFormatting? structuredFormatting;
	final String? description;
	final Geometry? geometry;
	@JsonKey(name: 'place_id') 
	final String? placeId;
	final List<String>? layer;

	const Prediction({
		this.reference, 
		this.types, 
		this.matchedSubstrings, 
		this.terms, 
		this.distanceMeters, 
		this.structuredFormatting, 
		this.description, 
		this.geometry, 
		this.placeId, 
		this.layer, 
	});

	factory Prediction.fromJson(Map<String, dynamic> json) {
		return _$PredictionFromJson(json);
	}

	Map<String, dynamic> toJson() => _$PredictionToJson(this);

	Prediction copyWith({
		String? reference,
		List<String>? types,
		List<MatchedSubstring>? matchedSubstrings,
		List<Term>? terms,
		num? distanceMeters,
		StructuredFormatting? structuredFormatting,
		String? description,
		Geometry? geometry,
		String? placeId,
		List<String>? layer,
	}) {
		return Prediction(
			reference: reference ?? this.reference,
			types: types ?? this.types,
			matchedSubstrings: matchedSubstrings ?? this.matchedSubstrings,
			terms: terms ?? this.terms,
			distanceMeters: distanceMeters ?? this.distanceMeters,
			structuredFormatting: structuredFormatting ?? this.structuredFormatting,
			description: description ?? this.description,
			geometry: geometry ?? this.geometry,
			placeId: placeId ?? this.placeId,
			layer: layer ?? this.layer,
		);
	}

	@override
	List<Object?> get props {
		return [
				reference,
				types,
				matchedSubstrings,
				terms,
				distanceMeters,
				structuredFormatting,
				description,
				geometry,
				placeId,
				layer,
		];
	}
}
