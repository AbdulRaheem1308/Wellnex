import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wellnex_app/core/constants/app_constants.dart';

void main() {
  test('hive map test', () async {
    Hive.init('test_dir');
    final box = await Hive.openBox('wellnex_storage');
    box.put('user_data', {'isProfileCreated': false});
    
    final data = box.get(AppConstants.userKey);
    print('Type of data: ${data.runtimeType}');
    
    try {
      final user = Map<String, dynamic>.from(data as Map);
      print('user map: $user');
      print('isProfileCreated: ${user['isProfileCreated']}');
      print('isProfileCreated != true: ${user['isProfileCreated'] != true}');
    } catch (e) {
      print('Error: $e');
    }
  });
}
