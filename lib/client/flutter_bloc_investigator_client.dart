import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_investigator_client/enums/packet_type.dart';
import 'package:flutter_bloc_investigator_client/models/bloc_change.dart';
import 'package:flutter_bloc_investigator_client/models/instance_identity.dart';
import 'package:flutter_bloc_investigator_client/models/investigative_packet.dart';
import 'package:logger/logger.dart';
import 'package:nsd/nsd.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tcp_client_dart/tcp_client_dart.dart';
import 'package:synchronized/synchronized.dart' as synchronized;

class FlutterBlocInvestigatorClient {
  final synchronized.Lock lock = synchronized.Lock();
  static const int bufferLength = 40;

  late final List<TcpClient> _connections = [];
  late final Logger logger = Logger();
  late final InstanceIdentity identity;
  late final List<String> buffer = [];

  final int port;
  final bool enabled;
  final bool inEmulator;
  final bool log;

  String? ipAddress;
  Discovery? nsd;

  FlutterBlocInvestigatorClient({
    this.ipAddress = "10.0.2.2",
    this.port = 8275,
    this.enabled = kDebugMode,
    this.inEmulator = true,
    this.log = false,
  }) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!enabled) return;

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    identity = InstanceIdentity(
        applicationId: packageInfo.packageName,
        appName: packageInfo.appName,
        deviceOS: Platform.operatingSystem);

    if (inEmulator) ipAddress = "10.0.2.2";

    if (ipAddress == null) {
      nsd = await startDiscovery('_http._tcp');
      nsd?.addServiceListener(_serviceListener);
      logger.d("Listening for relevant services.");
    } else {
      try {
        TcpClient connection = await TcpClient.connect(
          ipAddress!,
          port,
          terminatorString: "\n",
          connectionType: TcpConnectionType.persistent,
        );
        connection.stringStream.listen(_onMessage);
        await _announceIdentity(connection);
        _connections.add(connection);
      } catch (error, trace) {
        logger.e("An Error Occurred.", error, trace);
      }
    }
  }

  Future<void> _announceIdentity(TcpClient connection) async {
    final response = await connection.sendAndWait(
        "${json.encode(InvestigativePacket(type: PacketType.instanceIdentity, identity: identity))}[&&]");
    logger.d(response?.body);
    logger.d("Announced Identity");
  }

  void _serviceListener(Service service, ServiceStatus status) async {
    if (status == ServiceStatus.found &&
        service.name == "flutter_bloc_investigator") {
      try {
        TcpClient connection = await TcpClient.connect(
          service.host!,
          service.port!,
          terminatorString: "\n",
          connectionType: TcpConnectionType.persistent,
        );
        connection.stringStream.listen(_onMessage);
        await _announceIdentity(connection);
        _connections.add(connection);
        stopDiscovery(nsd!);
      } catch (error, trace) {
        logger.e("An Error Occurred.", error, trace);
      }
    }
  }

  void _onMessage(String message) {
    logger.d(message);
  }

  void onCreateBloc(BlocBase bloc) async {
    if (!enabled) {
      _log("Inspector is disabled");
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
        blocName: bloc.runtimeType.toString(),
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

  void onTransition(Bloc bloc, Transition transition) async {
    if (!enabled) {
      _log("Inspector is disabled");
      return;
    }

    String? data;
    try {
      data = json.encode(
        InvestigativePacket(
          type: PacketType.blocTransitioned,
          blocName: bloc.runtimeType.toString(),
          identity: identity,
          blocChange: BlocChange(
            blocName: bloc.runtimeType.toString(),
            eventName: transition.event.runtimeType.toString(),
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
            blocName: bloc.runtimeType.toString(),
            oldFallbackState: transition.currentState.toString(),
            newFallbackState: transition.nextState.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString(),
              eventName: transition.event.runtimeType.toString(),
            )),
      );
    } on JsonUnsupportedObjectError catch (error) {
      data = json.encode(
        InvestigativePacket(
            type: PacketType.blocFallbackTransitioned,
            identity: identity,
            blocName: bloc.runtimeType.toString(),
            oldFallbackState: transition.currentState.toString(),
            newFallbackState: transition.nextState.toString(),
            decodeErrorReason: error.cause.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString(),
              eventName: transition.event.runtimeType.toString(),
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
        TcpClient connection = await TcpClient.connect(ipAddress!, port,
            terminatorString: "\n",
            connectionType: TcpConnectionType.persistent);
        connection.stringStream.listen(_onMessage);
        await _announceIdentity(connection);
        _connections.add(connection);
        await _flush();
      } catch (error, trace) {
        logger.e("An Error Occurred.", error, trace);
      }
    }
  }

  Future<void> _sendLog(String log, {bool handleFailure = false}) async {
    await lock.synchronized(() async {
      if (_connections.isEmpty) {
        buffer.add(log);
        if (handleFailure) {
          await _establishConnection();
        }
        return;
      }

      for (TcpClient connection in _connections) {
        try {
          await connection.sendAndWait("$log[&&]");
        } catch (error) {
          logger.e(error);
        }
      }
    });
  }

  Future<void> _flush() async {
    await _sendLog(buffer.join("[&&]"), handleFailure: false);
    buffer.clear();
  }

  // void _reconnect(TcpClient oldConnection) async {
  //   try {
  //     TcpClient connection =
  //         await TcpClient.connect(oldConnection.host, oldConnection.port);
  //     _connections.remove(oldConnection);
  //     _connections.add(connection);
  //     await _flush();
  //   } catch (error) {
  //     logger.e(error);
  //   }
  // }

  void onBlocChange(BlocBase bloc, Change change) async {
    String? data;
    try {
      data = json.encode(
        InvestigativePacket(
          type: PacketType.blocTransitioned,
          blocName: bloc.runtimeType.toString(),
          identity: identity,
          blocChange: BlocChange(
            blocName: bloc.runtimeType.toString(),
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
            blocName: bloc.runtimeType.toString(),
            oldFallbackState: change.currentState.toString(),
            newFallbackState: change.nextState.toString(),
            blocChange: BlocChange(
              blocName: bloc.runtimeType.toString(),
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
    for (var element in _connections) {
      element.send("Hello From App: onError");
    }
  }

  void _log(String message) {
    if (!log) return;
    logger.d(message);
  }

  /// Dispose.
  Future<void> dispose() async {
    if (nsd != null) await stopDiscovery(nsd!);
  }
}
