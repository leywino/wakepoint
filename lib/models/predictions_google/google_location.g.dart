// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleLocation _$GoogleLocationFromJson(Map<String, dynamic> json) =>
    GoogleLocation(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GoogleLocationToJson(GoogleLocation instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
