import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'term.g.dart';

@JsonSerializable()
class Term extends Equatable {
	final num? offset;
	final String? value;

	const Term({this.offset, this.value});

	factory Term.fromJson(Map<String, dynamic> json) => _$TermFromJson(json);

	Map<String, dynamic> toJson() => _$TermToJson(this);

	Term copyWith({
		num? offset,
		String? value,
	}) {
		return Term(
			offset: offset ?? this.offset,
			value: value ?? this.value,
		);
	}

	@override
	List<Object?> get props => [offset, value];
}
