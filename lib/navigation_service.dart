import 'package:flutter/widgets.dart';

/// Global navigator key used by the app so route guards can access a BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global RouteObserver so screens can subscribe to route changes
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
