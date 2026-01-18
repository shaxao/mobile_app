import 'dart:js' as js;

void removeLoading() {
  try {
    js.context.callMethod('removeLoading');
  } catch (e) {
    // ignore
  }
}
