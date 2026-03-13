import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/payment_models/massary_model.dart';
import 'package:tariqi/models/payment_models/master_card_model.dart'
    as mastercard;
import 'package:tariqi/models/payment_models/payment_method_models.dart'
    as pm;

void main() {
  // ============================================
  // MasaryModel Tests
  // ============================================
  group('MasaryModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 12345,
          'invoice_key': 'inv_key_abc',
          'payment_data': {'masaryCode': 987654},
        },
      };
      final model = MasaryModel.fromJson(json);
      expect(model.status, 'success');
      expect(model.data, isNotNull);
      expect(model.data!.invoiceId, 12345);
      expect(model.data!.invoiceKey, 'inv_key_abc');
      expect(model.data!.paymentData, isNotNull);
      expect(model.data!.paymentData!.masaryCode, 987654);
    });

    test('fromJson handles null data', () {
      final json = {'status': 'failed', 'data': null};
      final model = MasaryModel.fromJson(json);
      expect(model.status, 'failed');
      expect(model.data, isNull);
    });

    test('fromJson handles missing data field', () {
      final json = {'status': 'pending'};
      final model = MasaryModel.fromJson(json);
      expect(model.status, 'pending');
      expect(model.data, isNull);
    });

    test('fromJson handles empty json', () {
      final model = MasaryModel.fromJson({});
      expect(model.status, isNull);
      expect(model.data, isNull);
    });

    test('fromJson handles null payment_data in data', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 123,
          'invoice_key': 'key',
          'payment_data': null,
        },
      };
      final model = MasaryModel.fromJson(json);
      expect(model.data!.paymentData, isNull);
    });

    test('fromJson handles zero masaryCode', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 123,
          'invoice_key': 'key',
          'payment_data': {'masaryCode': 0},
        },
      };
      final model = MasaryModel.fromJson(json);
      expect(model.data!.paymentData!.masaryCode, 0);
    });

    test('fromJson handles large masaryCode', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 123,
          'invoice_key': 'key',
          'payment_data': {'masaryCode': 999999999},
        },
      };
      final model = MasaryModel.fromJson(json);
      expect(model.data!.paymentData!.masaryCode, 999999999);
    });
  });

  // ============================================
  // MasterCardModel Tests
  // ============================================
  group('MasterCardModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 54321,
          'invoice_key': 'inv_mc_key',
          'payment_data': {
            'redirectTo': 'https://payment-gateway.com/pay/abc123',
          },
        },
      };
      final model = mastercard.MasterCardModel.fromJson(json);
      expect(model.status, 'success');
      expect(model.data, isNotNull);
      expect(model.data!.invoiceId, 54321);
      expect(model.data!.invoiceKey, 'inv_mc_key');
      expect(model.data!.paymentData, isNotNull);
      expect(
        model.data!.paymentData!.redirectTo,
        'https://payment-gateway.com/pay/abc123',
      );
    });

    test('fromJson handles null data', () {
      final json = {'status': 'error', 'data': null};
      final model = mastercard.MasterCardModel.fromJson(json);
      expect(model.status, 'error');
      expect(model.data, isNull);
    });

    test('fromJson handles missing data field', () {
      final json = {'status': 'pending'};
      final model = mastercard.MasterCardModel.fromJson(json);
      expect(model.data, isNull);
    });

    test('fromJson handles empty json', () {
      final model = mastercard.MasterCardModel.fromJson({});
      expect(model.status, isNull);
      expect(model.data, isNull);
    });

    test('fromJson handles null payment_data', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 123,
          'invoice_key': 'key',
          'payment_data': null,
        },
      };
      final model = mastercard.MasterCardModel.fromJson(json);
      expect(model.data!.paymentData, isNull);
    });

    test('fromJson handles null redirectTo', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 123,
          'invoice_key': 'key',
          'payment_data': {'redirectTo': null},
        },
      };
      final model = mastercard.MasterCardModel.fromJson(json);
      expect(model.data!.paymentData!.redirectTo, isNull);
    });

    test('fromJson handles empty redirectTo URL', () {
      final json = {
        'status': 'success',
        'data': {
          'invoice_id': 123,
          'invoice_key': 'key',
          'payment_data': {'redirectTo': ''},
        },
      };
      final model = mastercard.MasterCardModel.fromJson(json);
      expect(model.data!.paymentData!.redirectTo, '');
    });

    test('EDGE CASE: accessing redirectTo when data is null causes crash', () {
      final model = mastercard.MasterCardModel.fromJson({'data': null});
      // This is a potential crash point in payment_controller.dart line:
      // masterCardModel!.data!.paymentData!.redirectTo
      expect(() => model.data!.paymentData, throwsA(isA<TypeError>()));
    });
  });

  // ============================================
  // PaymentMethod Tests
  // ============================================
  group('PaymentMethod', () {
    test('fromJson parses complete data with multiple methods', () {
      final json = {
        'status': 'success',
        'data': [
          {
            'paymentId': 2,
            'name_en': 'Credit Card',
            'name_ar': 'بطاقة ائتمان',
            'redirect': 'https://gateway.com',
            'logo': 'https://example.com/visa.png',
          },
          {
            'paymentId': 14,
            'name_en': 'Masary',
            'name_ar': 'مصاري',
            'redirect': 'none',
            'logo': 'https://example.com/masary.png',
          },
        ],
      };
      final model = pm.PaymentMethod.fromJson(json);
      expect(model.status, 'success');
      expect(model.data, isNotNull);
      expect(model.data!.length, 2);
      expect(model.data![0].paymentId, 2);
      expect(model.data![0].nameEn, 'Credit Card');
      expect(model.data![0].nameAr, 'بطاقة ائتمان');
      expect(model.data![0].redirect, 'https://gateway.com');
      expect(model.data![0].logo, 'https://example.com/visa.png');
      expect(model.data![1].paymentId, 14);
      expect(model.data![1].nameEn, 'Masary');
    });

    test('fromJson handles null data', () {
      final json = {'status': 'success', 'data': null};
      final model = pm.PaymentMethod.fromJson(json);
      expect(model.status, 'success');
      expect(model.data, isNull);
    });

    test('fromJson handles empty data array', () {
      final json = {'status': 'success', 'data': []};
      final model = pm.PaymentMethod.fromJson(json);
      expect(model.data, isNotNull);
      expect(model.data!.length, 0);
    });

    test('fromJson handles missing data field', () {
      final json = {'status': 'error'};
      final model = pm.PaymentMethod.fromJson(json);
      expect(model.data, isNull);
    });

    test('fromJson handles empty json', () {
      final model = pm.PaymentMethod.fromJson({});
      expect(model.status, isNull);
      expect(model.data, isNull);
    });

    test('fromJson Data handles null fields', () {
      final dataJson = <String, dynamic>{};
      final data = pm.Data.fromJson(dataJson);
      expect(data.paymentId, isNull);
      expect(data.nameEn, isNull);
      expect(data.nameAr, isNull);
      expect(data.redirect, isNull);
      expect(data.logo, isNull);
    });

    test('fromJson handles single payment method', () {
      final json = {
        'status': 'success',
        'data': [
          {
            'paymentId': 1,
            'name_en': 'Cash',
            'name_ar': 'نقدي',
          },
        ],
      };
      final model = pm.PaymentMethod.fromJson(json);
      expect(model.data!.length, 1);
      expect(model.data![0].nameEn, 'Cash');
    });

    test('fromJson handles Arabic-only names', () {
      final json = {
        'status': 'success',
        'data': [
          {
            'paymentId': 1,
            'name_ar': 'فودافون كاش',
          },
        ],
      };
      final model = pm.PaymentMethod.fromJson(json);
      expect(model.data![0].nameAr, 'فودافون كاش');
      expect(model.data![0].nameEn, isNull);
    });
  });
}
