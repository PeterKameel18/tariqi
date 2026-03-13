import 'package:intl/intl.dart';

String formatDateTime(String dateTimeString) {
  final dateTime = DateTime.parse(dateTimeString).toLocal();
  return DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
}


String formatDateTimeChat(String dateTimeString) {
  final dateTime = DateTime.parse(dateTimeString).toLocal();
  return DateFormat('hh:mm a').format(dateTime);
}