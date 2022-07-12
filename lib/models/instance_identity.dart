// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'instance_identity.freezed.dart';
part 'instance_identity.g.dart';

@freezed
class InstanceIdentity with _$InstanceIdentity {
  factory InstanceIdentity({
    @Default("com.example.app") String applicationId,
    @Default("") String appName,
    @Default("") String deviceOS,
  }) = _InstanceIdentity;

  factory InstanceIdentity.fromJson(Map<String, dynamic> json) =>
      _$InstanceIdentityFromJson(json);
}
