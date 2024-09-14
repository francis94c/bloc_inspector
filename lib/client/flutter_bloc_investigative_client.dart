import 'dart:convert';
import 'dart:io';

import 'package:bloc_inspector_sdk/extensions/string.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_inspector_sdk/enums/packet_type.dart';
import 'package:bloc_inspector_sdk/models/bloc_change.dart';
import 'package:bloc_inspector_sdk/models/instance_identity.dart';
import 'package:bloc_inspector_sdk/models/investigative_packet.dart';
import 'package:logger/logger.dart';
import 'package:nsd/nsd.dart';
import 'package:synchronized/synchronized.dart' as synchronized;

class FlutterBlocInvestigativeClient {
  final synchronized.Lock lock = synchronized.Lock();

  late final Logger logger = Logger();
  late final InstanceIdentity identity;
  late final List<String> buffer = [];

  final int port;
  final bool enabled;
  final bool inEmulator;
  final String applicationId;
  final String appName;
  final bool log;
  final Dio dio = Dio(BaseOptions(headers: {
    'Content-Type': 'application/json',
  }));

  String? ipAddress;
  Discovery? nsd;
  int _sentCount = 0;

  FlutterBlocInvestigativeClient({
    this.ipAddress,
    this.port = 8275,
    this.applicationId = "com.example.app",
    this.appName = "Example App",
    this.enabled = kDebugMode,
    this.inEmulator = true,
    this.log = false,
  }) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!enabled) return;

    identity = InstanceIdentity(
        applicationId: applicationId,
        appName: appName,
        deviceOS: Platform.operatingSystem);

    if (inEmulator) ipAddress = "10.0.2.2";

    if (ipAddress == null) {
      nsd = await startDiscovery('_http._tcp');
      nsd?.addServiceListener(_serviceListener);
      logger.d("Listening for relevant services.");
    } else {
      try {
        await _announceIdentity();
      } catch (error, trace) {
        _logError("An Error Occurred.", error, trace);
      }
    }
  }

  String get _baseUrl => "http://$ipAddress:$port";

  Future<void> _announceIdentity() async {
    final response = await dio.post(_baseUrl,
        data: json.encode(InvestigativePacket(
            type: PacketType.instanceIdentity, identity: identity)));
    logger.d(response.data);
    logger.d("Announced Identity");
  }

  void _serviceListener(Service service, ServiceStatus status) async {
    if (status == ServiceStatus.found &&
        service.name == "flutter_bloc_investigator") {
      try {
        await _announceIdentity();
        stopDiscovery(nsd!);
      } catch (error, trace) {
        _logError("An Error Occurred.", error, trace);
      }
    }
  }

  void onCreateBloc(BlocBase bloc) async {
    if (!enabled) {
      _logDebug("Inspector is disabled");
      return;
    }

    String? data;

    try {
      data = json.encode(InvestigativePacket(
        type: PacketType.blocCreated,
        blocName: bloc.runtimeType.toString(),
        state: bloc.state.toJson(),
        identity: identity,
      ));
    } catch (error) {
      data = json.encode(InvestigativePacket(
        type: PacketType.blocFallbackCreated,
        blocName: bloc.runtimeType.toString().humanized,
        fallbackState: bloc.state.toString(),
        identity: identity,
      ));
    } finally {
      if (data != null) {
        buffer.add(data);
        _sendLog(data);
      }
    }
  }

  void onTransitionBloc(Bloc bloc, Transition transition) async {
    if (!enabled) {
      _logDebug("Inspector is disabled");
      return;
    }

    String? data;
    try {
      data = json.encode(
        InvestigativePacket(
          type: PacketType.blocTransitioned,
          blocName: bloc.runtimeType.toString().humanized,
          identity: identity,
          blocChange: BlocChange(
            blocName: bloc.runtimeType.toString().humanized,
            eventName: transition.event.runtimeType.toString().humanized,
            oldState: transition.currentState.toJson(),
            newState: transition.nextState.toJson(),
          ),
        ),
      );
    } on NoSuchMethodError catch (error) {
      data = json.encode(
        InvestigativePacket(
            type: PacketType.blocFallbackTransitioned,
            identity: identity,
            decodeErrorReason: error.toString(),
            blocName: bloc.runtimeType.toString().humanized,
            oldFallbackState: transition.currentState.toString(),
            newFallbackState: transition.nextState.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString().humanized,
              eventName: transition.event.runtimeType.toString().humanized,
            )),
      );
    } on JsonUnsupportedObjectError catch (error) {
      data = json.encode(
        InvestigativePacket(
            type: PacketType.blocFallbackTransitioned,
            identity: identity,
            blocName: bloc.runtimeType.toString().humanized,
            oldFallbackState: transition.currentState.toString(),
            newFallbackState: transition.nextState.toString(),
            decodeErrorReason: error.cause.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString().humanized,
              eventName: transition.event.runtimeType.toString().humanized,
            )),
      );
    } catch (error) {
      logger.e(error);
    }
    if (data != null) {
      await _sendLog(data);
    }
  }

  void onChange(BlocBase bloc, Change change) async {
    if (!enabled) {
      _logDebug("Inspector is disabled");
      return;
    }

    String? data;
    try {
      data = json.encode(
        InvestigativePacket(
          type: PacketType.blocTransitioned,
          blocName: bloc.runtimeType.toString().humanized,
          identity: identity,
          blocChange: BlocChange(
            blocName: bloc.runtimeType.toString().humanized,
            eventName: "No Transition",
            oldState: change.currentState.toJson(),
            newState: change.nextState.toJson(),
          ),
        ),
      );
    } on NoSuchMethodError catch (error) {
      data = json.encode(
        InvestigativePacket(
            type: PacketType.blocFallbackTransitioned,
            identity: identity,
            decodeErrorReason: error.toString(),
            blocName: bloc.runtimeType.toString().humanized,
            oldFallbackState: change.currentState.toString(),
            newFallbackState: change.nextState.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString().humanized,
              eventName: "No Transition",
            )),
      );
    } on JsonUnsupportedObjectError catch (error) {
      data = json.encode(
        InvestigativePacket(
            type: PacketType.blocFallbackTransitioned,
            identity: identity,
            blocName: bloc.runtimeType.toString().humanized,
            oldFallbackState: change.currentState.toString(),
            newFallbackState: change.nextState.toString(),
            decodeErrorReason: error.cause.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString().humanized,
              eventName: "No Transition",
            )),
      );
    } catch (error) {
      logger.e(error);
    }
    if (data != null) {
      await _sendLog(data);
    }
  }

  Future<void> _establishConnection() async {
    if (ipAddress == null) {
      nsd = await startDiscovery("_http._tcp");
      nsd?.addServiceListener(_serviceListener);
      logger.d("Listening for relevant services");
    } else {
      try {
        await _announceIdentity();
      } catch (error, trace) {
        logger.e("An Error Occurred.", error: error, stackTrace: trace);
      }
    }
  }

  Future<void> _sendLog(String log) async {
    await lock.synchronized(() async {
      if (_sentCount > 10) {
        await _establishConnection();
        _sentCount = 0;
      }

      try {
        await dio.post(_baseUrl, data: log);
        _sentCount++;
      } catch (error) {
        logger.e(error);
      }
    });
  }

  void onBlocChange(BlocBase bloc, Change change) async {
    String? data;
    try {
      data = json.encode(
        InvestigativePacket(
          type: PacketType.blocTransitioned,
          blocName: bloc.runtimeType.toString().humanized,
          identity: identity,
          blocChange: BlocChange(
            blocName: bloc.runtimeType.toString().humanized,
            eventName: "Generic",
            oldState: change.currentState.toJson(),
            newState: change.nextState.toJson(),
          ),
        ),
      );
    } on NoSuchMethodError {
      data = json.encode(
        InvestigativePacket(
            type: PacketType.blocFallbackTransitioned,
            identity: identity,
            blocName: bloc.runtimeType.toString().humanized,
            oldFallbackState: change.currentState.toString(),
            newFallbackState: change.nextState.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString().humanized,
              eventName: "Generic",
            )),
      );
    } catch (error) {
      logger.e(error);
    }
    if (data != null) {
      await _sendLog(data);
    }
  }

  void onBlocError() {
    // TODO: Implement
  }

  void _logDebug(String message) {
    if (!log) return;
    logger.d(message);
  }

  void _logError(String message, Object error, StackTrace trace) {
    if (!log) return;
    logger.e(error);
  }

  /// Dispose.
  Future<void> dispose() async {
    if (nsd != null) await stopDiscovery(nsd!);
  }
}
