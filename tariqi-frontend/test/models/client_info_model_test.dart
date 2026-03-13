import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/client_info_model.dart';

void main() {
  group('ClientInfoModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'firstName': 'Sara',
        'lastName': 'Ali',
        'age': 30,
        'phoneNumber': '+201098765432',
        'email': 'sara@test.com',
        'inRide': 'ride123',
      };

      final model = ClientInfoModel.fromJson(json);

      expect(model.firstName, 'Sara');
      expect(model.lastName, 'Ali');
      expect(model.age, 30);
      expect(model.phoneNumber, '+201098765432');
      expect(model.email, 'sara@test.com');
      expect(model.inRide, 'ride123');
    });

    test('fromJson handles null inRide', () {
      final json = {
        'firstName': 'Sara',
        'lastName': 'Ali',
        'age': 25,
        'phoneNumber': '+201098765432',
        'email': 'sara@test.com',
        'inRide': null,
      };

      final model = ClientInfoModel.fromJson(json);
      expect(model.inRide, isNull);
    });

    test('fromJson handles empty JSON', () {
      final model = ClientInfoModel.fromJson({});
      expect(model.firstName, isNull);
      expect(model.lastName, isNull);
      expect(model.email, isNull);
    });
  });
}
