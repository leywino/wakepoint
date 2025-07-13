import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'main_text_matched_substring.g.dart';

@JsonSerializable()
class MainTextMatchedSubstring extends Equatable {
	final num? offset;
	final num? length;

	const MainTextMatchedSubstring({this.offset, this.length});

	factory MainTextMatchedSubstring.fromJson(Map<String, dynamic> json) {
		return _$MainTextMatchedSubstringFromJson(json);
	}

	Map<String, dynamic> toJson() => _$MainTextMatchedSubstringToJson(this);

	MainTextMatchedSubstring copyWith({
		num? offset,
		num? length,
	}) {
		return MainTextMatchedSubstring(
			offset: offset ?? this.offset,
			length: length ?? this.length,
		);
	}

	@override
	List<Object?> get props => [offset, length];
}
