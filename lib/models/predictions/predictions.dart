import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'prediction.dart';

part 'predictions.g.dart';

@JsonSerializable()
class Predictions extends Equatable {
	@JsonKey(name: 'error_message') 
	final String? errorMessage;
	@JsonKey(name: 'info_messages') 
	final List<dynamic>? infoMessages;
	final List<Prediction>? predictions;
	final String? status;

	const Predictions({
		this.errorMessage, 
		this.infoMessages, 
		this.predictions, 
		this.status, 
	});

	factory Predictions.fromJson(Map<String, dynamic> json) {
		return _$PredictionsFromJson(json);
	}

	Map<String, dynamic> toJson() => _$PredictionsToJson(this);

	Predictions copyWith({
		String? errorMessage,
		List<dynamic>? infoMessages,
		List<Prediction>? predictions,
		String? status,
	}) {
		return Predictions(
			errorMessage: errorMessage ?? this.errorMessage,
			infoMessages: infoMessages ?? this.infoMessages,
			predictions: predictions ?? this.predictions,
			status: status ?? this.status,
		);
	}

	@override
	List<Object?> get props {
		return [
				errorMessage,
				infoMessages,
				predictions,
				status,
		];
	}
}
