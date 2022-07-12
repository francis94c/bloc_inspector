// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'bloc_change.freezed.dart';
part 'bloc_change.g.dart';

@freezed
class BlocChange with _$BlocChange {
  factory BlocChange({
    @Default("") String blocName,
    @Default("") String eventName,
    @Default({}) Map<String, dynamic> oldState,
    @Default({}) Map<String, dynamic> newState,
  }) = _BlocChange;

  factory BlocChange.fromJson(Map<String, dynamic> json) =>
      _$BlocChangeFromJson(json);
}
