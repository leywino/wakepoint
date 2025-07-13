// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'structured_formatting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StructuredFormatting _$StructuredFormattingFromJson(
        Map<String, dynamic> json) =>
    StructuredFormatting(
      mainTextMatchedSubstrings:
          (json['main_text_matched_substrings'] as List<dynamic>?)
              ?.map((e) =>
                  MainTextMatchedSubstring.fromJson(e as Map<String, dynamic>))
              .toList(),
      secondaryTextMatchedSubstrings: (json['secondary_text_matched_substrings']
              as List<dynamic>?)
          ?.map((e) =>
              SecondaryTextMatchedSubstring.fromJson(e as Map<String, dynamic>))
          .toList(),
      secondaryText: json['secondary_text'] as String?,
      mainText: json['main_text'] as String?,
    );

Map<String, dynamic> _$StructuredFormattingToJson(
        StructuredFormatting instance) =>
    <String, dynamic>{
      'main_text_matched_substrings': instance.mainTextMatchedSubstrings,
      'secondary_text_matched_substrings':
          instance.secondaryTextMatchedSubstrings,
      'secondary_text': instance.secondaryText,
      'main_text': instance.mainText,
    };
