// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GooglePlaceDto _$GooglePlaceDtoFromJson(Map<String, dynamic> json) =>
    GooglePlaceDto(
      formattedAddress: json['formattedAddress'] as String?,
      location: json['location'] == null
          ? null
          : GoogleLocation.fromJson(json['location'] as Map<String, dynamic>),
      rating: (json['rating'] as num?)?.toDouble(),
      displayName: json['displayName'] == null
          ? null
          : GoogleDisplayName.fromJson(
              json['displayName'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GooglePlaceDtoToJson(GooglePlaceDto instance) =>
    <String, dynamic>{
      'formattedAddress': instance.formattedAddress,
      'location': instance.location,
      'rating': instance.rating,
      'displayName': instance.displayName,
    };
