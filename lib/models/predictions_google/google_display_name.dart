import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'google_display_name.g.dart';

@JsonSerializable()
class GoogleDisplayName extends Equatable {
  final String? text;
  final String? languageCode;

  const GoogleDisplayName({this.text, this.languageCode});

  factory GoogleDisplayName.fromJson(Map<String, dynamic> json) =>
      _$GoogleDisplayNameFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleDisplayNameToJson(this);

  @override
  List<Object?> get props => [text, languageCode];
}
