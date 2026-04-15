String? validate({
  required String? text,
  required int min,
  required int max,
  required String msgMin,
  required String msgMax,
}) {
  if (text!.length < min) {
    return '$msgMin $min';
  } else if (text.length > max) {
    return '$msgMax $max';
  } else {
    return null;
  }
}
