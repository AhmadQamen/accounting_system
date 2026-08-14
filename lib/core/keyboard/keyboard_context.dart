enum KeyboardContext {
  textEditing,
  dialog,
  invoice,
  global;

  int get priority {
    switch (this) {
      case KeyboardContext.textEditing:
        return 100;
      case KeyboardContext.dialog:
        return 90;
      case KeyboardContext.invoice:
        return 70;
      case KeyboardContext.global:
        return 10;
    }
  }
}
