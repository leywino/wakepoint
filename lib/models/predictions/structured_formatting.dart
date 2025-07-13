import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'main_text_matched_substring.dart';
import 'secondary_text_matched_substring.dart';

part 'structured_formatting.g.dart';

@JsonSerializable()
class StructuredFormatting extends Equatable {
	@JsonKey(name: 'main_text_matched_substrings') 
	final List<MainTextMatchedSubstring>? mainTextMatchedSubstrings;
	@JsonKey(name: 'secondary_text_matched_substrings') 
	final List<SecondaryTextMatchedSubstring>? secondaryTextMatchedSubstrings;
	@JsonKey(name: 'secondary_text') 
	final String? secondaryText;
	@JsonKey(name: 'main_text') 
	final String? mainText;

	const StructuredFormatting({
		this.mainTextMatchedSubstrings, 
		this.secondaryTextMatchedSubstrings, 
		this.secondaryText, 
		this.mainText, 
	});

	factory StructuredFormatting.fromJson(Map<String, dynamic> json) {
		return _$StructuredFormattingFromJson(json);
	}

	Map<String, dynamic> toJson() => _$StructuredFormattingToJson(this);

	StructuredFormatting copyWith({
		List<MainTextMatchedSubstring>? mainTextMatchedSubstrings,
		List<SecondaryTextMatchedSubstring>? secondaryTextMatchedSubstrings,
		String? secondaryText,
		String? mainText,
	}) {
		return StructuredFormatting(
			mainTextMatchedSubstrings: mainTextMatchedSubstrings ?? this.mainTextMatchedSubstrings,
			secondaryTextMatchedSubstrings: secondaryTextMatchedSubstrings ?? this.secondaryTextMatchedSubstrings,
			secondaryText: secondaryText ?? this.secondaryText,
			mainText: mainText ?? this.mainText,
		);
	}

	@override
	List<Object?> get props {
		return [
				mainTextMatchedSubstrings,
				secondaryTextMatchedSubstrings,
				secondaryText,
				mainText,
		];
	}
}
