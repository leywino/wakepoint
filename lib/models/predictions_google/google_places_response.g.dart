// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_places_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GooglePlacesResponse _$GooglePlacesResponseFromJson(
        Map<String, dynamic> json) =>
    GooglePlacesResponse(
      places: (json['places'] as List<dynamic>?)
          ?.map((e) => GooglePlaceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GooglePlacesResponseToJson(
        GooglePlacesResponse instance) =>
    <String, dynamic>{
      'places': instance.places,
    };
