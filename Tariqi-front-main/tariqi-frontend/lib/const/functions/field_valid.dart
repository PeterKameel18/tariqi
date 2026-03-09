import 'package:get/get_utils/get_utils.dart';
/// Validates a field based on its type and length constraints.
///
/// This function checks if the provided `val` is non-empty and within the
/// specified `minVal` and `maxVal` character limits. It also validates the
/// `val` against the `type` specified, which can be "mobile", "email", or
/// "name". For "mobile", it checks if the value is a valid phone number;
/// for "email", it checks if the value is a valid email address; and for
/// "name", it ensures the value contains only alphabetic characters and spaces.
///
/// Returns a validation error message if any check fails, or `null` if all
/// validations pass.
///
/// Parameters:
/// - `val`: The value to be validated.
/// - `type`: The type of validation to perform ("mobile", "email", "name").
/// - `fieldName`: The name of the field being validated, used in error messages.
/// - `minVal`: The minimum length the value should have.
/// - `maxVal`: The maximum length the value can have.
validFields({
  required String val,
  required String type,
  required String fieldName,
  required int minVal,
  required int maxVal,
}) {
  if (val.isEmpty) {
    return "Please fill the required field: $fieldName.";
  }

  if (val.length > maxVal) {
    return "$fieldName can't be more than $maxVal characters.";
  }

  if (val.length < minVal) {
    return "$fieldName can't be less than $minVal characters.";
  }

  switch (type) {
    case "mobile":
      if (!GetUtils.isPhoneNumber(val)) {
        return "Please enter a valid $fieldName.";
      }
      break;

    case "email":
      if (!GetUtils.isEmail(val)) {
        return "Please enter a valid $fieldName.";
      }
      break;

    case "name":
      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) {
        return "Please enter a valid $fieldName.";
      }
      break;
  }

  return null;
}
