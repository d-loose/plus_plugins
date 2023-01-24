import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:networkd/networkd.dart';
import 'package:nm/nm.dart';

// Used internally
// ignore_for_file: public_member_api_docs

@visibleForTesting
typedef NetworkManagerClientFactory = NetworkManagerClient Function();

@visibleForTesting
typedef NetworkdManagerFactory = NetworkdManager Function();

/// The Linux implementation of ConnectivityPlatform.
class ConnectivityPlusLinuxPlugin extends ConnectivityPlatform {
  /// Register this dart class as the platform implementation for linux
  static void registerWith() {
    ConnectivityPlatform.instance = ConnectivityPlusLinuxPlugin();
  }

  /// Checks the connection status of the device.
  @override
  Future<ConnectivityResult> checkConnectivity() async {
    NetworkManagerClient? networkManagerClient = createNetworkManagerClient();
    NetworkdManager? networkdManager = createNetworkdManager();

    try {
      await networkManagerClient.connect();
    } on Exception catch (e) {
      debugPrint('NetworkManager: cannot connect to DBus API ($e)');
      networkManagerClient = null;
    }

    try {
      await networkdManager.connect();
    } on Exception catch (e) {
      debugPrint('systemd-networkd: cannot connect to DBus API ($e)');
      networkdManager = null;
    }

    return _getConnectivity(
      networkManagerClient: networkManagerClient,
      networkdManager: networkdManager,
    );
  }

  NetworkManagerClient? _networkManagerClient;
  NetworkdManager? _networkdManager;
  StreamController<ConnectivityResult>? _controller;

  /// Returns a Stream of ConnectivityResults changes.
  @override
  Stream<ConnectivityResult> get onConnectivityChanged {
    _controller ??= StreamController<ConnectivityResult>.broadcast(
      onListen: _startListenConnectivity,
      onCancel: _stopListenConnectivity,
    );
    return _controller!.stream;
  }

  ConnectivityResult _getNetworkManagerConnectivity(
      NetworkManagerClient client) {
    if (client.connectivity != NetworkManagerConnectivityState.full) {
      return ConnectivityResult.none;
    }
    if (client.primaryConnectionType.contains('wireless')) {
      return ConnectivityResult.wifi;
    }
    if (client.primaryConnectionType.contains('ethernet')) {
      return ConnectivityResult.ethernet;
    }
    if (client.primaryConnectionType.contains('vpn')) {
      return ConnectivityResult.vpn;
    }
    if (client.primaryConnectionType.contains('bluetooth')) {
      return ConnectivityResult.bluetooth;
    }
    return ConnectivityResult.mobile;
  }

  Future<ConnectivityResult> _getNetworkdConnectivity(
      NetworkdManager networkdManager) async {
    final desc = await networkdManager.describe();
    NetworkdLinkDescription? linkDescription;
    for (final link in desc.interfaces ?? <NetworkdLinkDescription>[]) {
      if (link.requiredForOnline ?? false) {
        linkDescription = link;
      }
    }
    if (networkdManager.onlineState != 'online' || linkDescription == null) {
      return ConnectivityResult.none;
    }
    if (linkDescription.type?.contains('ether') ?? false) {
      return ConnectivityResult.ethernet;
    }
    if (linkDescription.type?.contains('wlan') ?? false) {
      return ConnectivityResult.wifi;
    }
    if (linkDescription.type?.contains('wwan') ?? false) {
      return ConnectivityResult.mobile;
    }
    return ConnectivityResult.ethernet;
  }

  Future<ConnectivityResult> _getConnectivity({
    NetworkManagerClient? networkManagerClient,
    NetworkdManager? networkdManager,
  }) async {
    var connectivity = ConnectivityResult.none;
    if (networkManagerClient != null) {
      connectivity = _getNetworkManagerConnectivity(networkManagerClient);
    }
    if (connectivity == ConnectivityResult.none && networkdManager != null) {
      connectivity = await _getNetworkdConnectivity(networkdManager);
    }
    return connectivity;
  }

  Future<void> _startListenConnectivity() async {
    await _startListenNetworkManagerConnectivity().catchError((e) {
      debugPrint('NetworkManager: cannot listen to connectivity changes ($e)');
      _networkManagerClient = null;
    });

    await _startListenNetworkdConnectivity().catchError((e) {
      debugPrint(
          'systemd-networkd: cannot listen to connectivity changes ($e)');
      _networkdManager = null;
    });
  }

  Future<void> _addConnectivity() async =>
      _controller!.add(await _getConnectivity(
        networkManagerClient: _networkManagerClient,
        networkdManager: _networkdManager,
      ));

  Future<void> _startListenNetworkManagerConnectivity() async {
    _networkManagerClient ??= createNetworkManagerClient();
    await _networkManagerClient!.connect();

    _addConnectivity();
    _networkManagerClient!.propertiesChanged.listen((properties) {
      if (properties.contains('Connectivity')) {
        _addConnectivity();
      }
    });
  }

  Future<void> _startListenNetworkdConnectivity() async {
    _networkdManager ??= createNetworkdManager();
    await _networkdManager!.connect();
    await _addConnectivity();
    _networkdManager!.propertiesChanged.listen((properties) {
      if (properties.contains('OnlineState')) {
        _addConnectivity();
      }
    });
  }

  Future<void> _stopListenConnectivity() async {
    await _networkManagerClient?.close();
    _networkManagerClient = null;
    await _networkdManager?.close();
    _networkdManager = null;
  }

  @visibleForTesting
  // ignore: prefer_function_declarations_over_variables
  NetworkManagerClientFactory createNetworkManagerClient =
      () => NetworkManagerClient();

  @visibleForTesting
  // ignore: prefer_function_declarations_over_variables
  NetworkdManagerFactory createNetworkdManager = () => NetworkdManager();
}
