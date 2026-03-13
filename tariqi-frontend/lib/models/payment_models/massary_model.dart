class MasaryModel {
  String? status;
  Data? data;

  MasaryModel({this.status, this.data});

  MasaryModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
}

class Data {
  int? invoiceId;
  String? invoiceKey;
  PaymentData? paymentData;

  Data({this.invoiceId, this.invoiceKey, this.paymentData});

  Data.fromJson(Map<String, dynamic> json) {
    invoiceId = json['invoice_id'];
    invoiceKey = json['invoice_key'];
    paymentData = json['payment_data'] != null
        ? PaymentData.fromJson(json['payment_data'])
        : null;
  }
}

class PaymentData {
  int? masaryCode;

  PaymentData({this.masaryCode});

  PaymentData.fromJson(Map<String, dynamic> json) {
    masaryCode = json['masaryCode'];
  }
}
