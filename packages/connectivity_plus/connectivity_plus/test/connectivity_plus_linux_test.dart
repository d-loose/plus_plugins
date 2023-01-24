import 'package:connectivity_plus/src/connectivity_plus_linux.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:networkd/networkd.dart';
import 'package:nm/nm.dart';

import 'connectivity_plus_linux_test.mocks.dart';

@GenerateMocks([NetworkManagerClient, NetworkdManager])
void main() {
  test('registered instance', () {
    ConnectivityPlusLinuxPlugin.registerWith();
    expect(ConnectivityPlatform.instance, isA<ConnectivityPlusLinuxPlugin>());
  });

  group('NetworkManager connections', () {
    test('bluetooth', () async {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connectivity)
            .thenReturn(NetworkManagerConnectivityState.full);
        when(client.primaryConnectionType).thenReturn('bluetooth');
        return client;
      };
      linux.createNetworkdManager = () => MockNetworkdManager();
      expect(
        linux.checkConnectivity(),
        completion(equals(ConnectivityResult.bluetooth)),
      );
    });

    test('ethernet', () async {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connectivity)
            .thenReturn(NetworkManagerConnectivityState.full);
        when(client.primaryConnectionType).thenReturn('ethernet');
        return client;
      };
      linux.createNetworkdManager = () => MockNetworkdManager();
      expect(
        linux.checkConnectivity(),
        completion(equals(ConnectivityResult.ethernet)),
      );
    });

    test('wireless', () async {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connectivity)
            .thenReturn(NetworkManagerConnectivityState.full);
        when(client.primaryConnectionType).thenReturn('wireless');
        return client;
      };
      linux.createNetworkdManager = () => MockNetworkdManager();
      expect(
        linux.checkConnectivity(),
        completion(equals(ConnectivityResult.wifi)),
      );
    });

    test('vpn', () async {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connectivity)
            .thenReturn(NetworkManagerConnectivityState.full);
        when(client.primaryConnectionType).thenReturn('vpn');
        return client;
      };
      linux.createNetworkdManager = () => MockNetworkdManager();
      expect(
        linux.checkConnectivity(),
        completion(equals(ConnectivityResult.vpn)),
      );
    });

    test('connectivity changes', () {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connectivity)
            .thenReturn(NetworkManagerConnectivityState.full);
        when(client.primaryConnectionType).thenReturn('wireless');
        when(client.propertiesChanged).thenAnswer((_) {
          when(client.connectivity)
              .thenReturn(NetworkManagerConnectivityState.none);
          return Stream.value(['Connectivity']);
        });
        return client;
      };
      linux.createNetworkdManager = () {
        final networkdManager = MockNetworkdManager();
        when(networkdManager.onlineState).thenReturn('');
        when(networkdManager.propertiesChanged)
            .thenAnswer((_) => const Stream.empty());
        when(networkdManager.describe())
            .thenAnswer((_) async => NetworkdManagerDescription());
        return networkdManager;
      };
      expect(linux.onConnectivityChanged,
          emitsInOrder([ConnectivityResult.wifi, ConnectivityResult.none]));
    });
  });

  group('systemd-networkd connections', () {
    test('ethernet', () async {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connect()).thenThrow(Exception('error'));
        return client;
      };
      linux.createNetworkdManager = () {
        final networkdManager = MockNetworkdManager();
        when(networkdManager.onlineState).thenReturn('online');
        when(networkdManager.describe()).thenAnswer((_) async =>
            NetworkdManagerDescription(interfaces: [
              NetworkdLinkDescription(requiredForOnline: true, type: 'ether')
            ]));
        return networkdManager;
      };
      expect(
        linux.checkConnectivity(),
        completion(equals(ConnectivityResult.ethernet)),
      );
    });
    test('wifi', () async {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connect()).thenThrow(Exception('error'));
        return client;
      };
      linux.createNetworkdManager = () {
        final networkdManager = MockNetworkdManager();
        when(networkdManager.onlineState).thenReturn('online');
        when(networkdManager.describe()).thenAnswer((_) async =>
            NetworkdManagerDescription(interfaces: [
              NetworkdLinkDescription(requiredForOnline: true, type: 'wlan')
            ]));
        return networkdManager;
      };
      expect(
        linux.checkConnectivity(),
        completion(equals(ConnectivityResult.wifi)),
      );
    });
    test('mobile', () async {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connect()).thenThrow(Exception('error'));
        return client;
      };
      linux.createNetworkdManager = () {
        final networkdManager = MockNetworkdManager();
        when(networkdManager.onlineState).thenReturn('online');
        when(networkdManager.describe()).thenAnswer((_) async =>
            NetworkdManagerDescription(interfaces: [
              NetworkdLinkDescription(requiredForOnline: true, type: 'wwan')
            ]));
        return networkdManager;
      };
      expect(
        linux.checkConnectivity(),
        completion(equals(ConnectivityResult.mobile)),
      );
    });

    test('connectivity changes', () {
      final linux = ConnectivityPlusLinuxPlugin();
      linux.createNetworkManagerClient = () {
        final client = MockNetworkManagerClient();
        when(client.connect()).thenThrow(Exception('error'));
        return client;
      };
      linux.createNetworkdManager = () {
        final networkdManager = MockNetworkdManager();
        when(networkdManager.onlineState).thenReturn('online');
        when(networkdManager.propertiesChanged).thenAnswer((_) {
          when(networkdManager.onlineState).thenReturn('');
          return Stream.value(['OnlineState']);
        });
        when(networkdManager.describe()).thenAnswer((_) async =>
            NetworkdManagerDescription(interfaces: [
              NetworkdLinkDescription(requiredForOnline: true, type: 'wlan')
            ]));
        return networkdManager;
      };
      expect(linux.onConnectivityChanged,
          emitsInOrder([ConnectivityResult.wifi, ConnectivityResult.none]));
    });
  });

  test('no connectivity with fallback', () async {
    final linux = ConnectivityPlusLinuxPlugin();
    linux.createNetworkManagerClient = () {
      final client = MockNetworkManagerClient();
      when(client.connectivity)
          .thenReturn(NetworkManagerConnectivityState.none);
      return client;
    };
    linux.createNetworkdManager = () {
      final networkdManager = MockNetworkdManager();
      when(networkdManager.onlineState).thenReturn('');
      when(networkdManager.describe())
          .thenAnswer((_) async => NetworkdManagerDescription());
      return networkdManager;
    };
    expect(
        linux.checkConnectivity(), completion(equals(ConnectivityResult.none)));
  });

  test('no services available', () async {
    final linux = ConnectivityPlusLinuxPlugin();
    linux.createNetworkManagerClient = () {
      final client = MockNetworkManagerClient();
      when(client.connect()).thenThrow(Exception('error'));
      return client;
    };
    linux.createNetworkdManager = () {
      final networkdManager = MockNetworkdManager();
      when(networkdManager.connect()).thenThrow(Exception('error'));
      return networkdManager;
    };
    expect(
        linux.checkConnectivity(), completion(equals(ConnectivityResult.none)));
  });
}
