import 'package:flutter/foundation.dart';

@visibleForTesting
bool? debugMockIsAndroid;

@visibleForTesting
bool? debugMockIsIOS;

bool get isAndroid => debugMockIsAndroid ?? false;
bool get isIOS => debugMockIsIOS ?? false;
