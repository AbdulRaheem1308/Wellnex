import 'dart:io';
import 'package:flutter/foundation.dart';

@visibleForTesting
bool? debugMockIsAndroid;

@visibleForTesting
bool? debugMockIsIOS;

bool get isAndroid => debugMockIsAndroid ?? Platform.isAndroid;
bool get isIOS => debugMockIsIOS ?? Platform.isIOS;
