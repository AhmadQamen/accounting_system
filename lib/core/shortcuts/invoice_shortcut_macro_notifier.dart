import 'package:flutter/foundation.dart';
import 'invoice_shortcut_macro.dart';
import 'invoice_shortcut_macro_service.dart';

class InvoiceShortcutMacroNotifier extends ChangeNotifier {
  final _service = InvoiceShortcutMacroService();
  List<InvoiceShortcutMacro> _macros = const [];
  InvoiceShortcutMacro? _pending;
  bool loaded = false;
  List<InvoiceShortcutMacro> get macros => List.unmodifiable(_macros);
  InvoiceShortcutMacro? takePending() { final value = _pending; _pending = null; return value; }
  Future<void> load() async { _macros = await _service.all(); loaded = true; notifyListeners(); }
  Future<void> save(InvoiceShortcutMacro macro) async { await _service.save(macro); await load(); }
  Future<void> remove(String id) async { await _service.delete(id); await load(); }
  bool dispatchIfMatches(InvoiceShortcutMacro macro) { _pending = macro; notifyListeners(); return true; }
}
