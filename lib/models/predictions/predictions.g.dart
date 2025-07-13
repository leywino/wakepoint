// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'predictions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Predictions _$PredictionsFromJson(Map<String, dynamic> json) => Predictions(
      errorMessage: json['error_message'] as String?,
      infoMessages: json['info_messages'] as List<dynamic>?,
      predictions: (json['predictions'] as List<dynamic>?)
          ?.map((e) => Prediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String?,
    );

Map<String, dynamic> _$PredictionsToJson(Predictions instance) =>
    <String, dynamic>{
      'error_message': instance.errorMessage,
      'info_messages': instance.infoMessages,
      'predictions': instance.predictions,
      'status': instance.status,
    };
