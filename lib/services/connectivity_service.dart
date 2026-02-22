import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  // Current connection status
  bool _hasConnection = true;

  ConnectivityService._internal() {
    _initConnectivity();
  }

  Stream<bool> get connectionStream => _connectionController.stream;
  bool get hasConnection => _hasConnection;

  Future<void> _initConnectivity() async {
    // Check initial status
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      // Ignore errors for initial check
      _hasConnection = true;
    }

    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool hasNetwork = false;
    for (var result in results) {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet) {
        hasNetwork = true;
        break;
      }
    }

    if (_hasConnection != hasNetwork) {
      _hasConnection = hasNetwork;
      _connectionController.add(_hasConnection);
    }
  }

  void dispose() {
    _connectionController.close();
  }
}
