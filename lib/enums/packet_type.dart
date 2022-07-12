import 'package:json_annotation/json_annotation.dart';

enum PacketType {
  @JsonValue("instance_identity")
  instanceIdentity,
  @JsonValue("bloc_created")
  blocCreated,
  @JsonValue("bloc_changed")
  blocChanged,
  @JsonValue("bloc_transitioned")
  blocTransitioned,
  @JsonValue("bloc_fallback_transitioned")
  blocFallbackTransitioned,
  @JsonValue("bloc_fallback_created")
  blocFallbackCreated,
  @JsonValue("bloc_error")
  blocError,
}
