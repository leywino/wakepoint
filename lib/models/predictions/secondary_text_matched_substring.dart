import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'secondary_text_matched_substring.g.dart';

@JsonSerializable()
class SecondaryTextMatchedSubstring extends Equatable {
	final num? offset;
	final num? length;

	const SecondaryTextMatchedSubstring({this.offset, this.length});

	factory SecondaryTextMatchedSubstring.fromJson(Map<String, dynamic> json) {
		return _$SecondaryTextMatchedSubstringFromJson(json);
	}

	Map<String, dynamic> toJson() => _$SecondaryTextMatchedSubstringToJson(this);

	SecondaryTextMatchedSubstring copyWith({
		num? offset,
		num? length,
	}) {
		return SecondaryTextMatchedSubstring(
			offset: offset ?? this.offset,
			length: length ?? this.length,
		);
	}

	@override
	List<Object?> get props => [offset, length];
}
