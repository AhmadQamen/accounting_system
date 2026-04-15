import 'package:accounting_system/core/errors/failures.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';

void handleFailure(Failure failure) {
  if (failure is ValidationFailure) {
    CustomSnackBar.showErrorSnackbar(failure.errors.toString());
  } else {
    CustomSnackBar.showErrorSnackbar(failure.message);
  }
}

void handleSuccses({String text = "تمت العملية بنجاح"}) {
  CustomSnackBar.showSuccessSnackbar(text);
}
