import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _getItem(JSString key);

@JS('window.localStorage.setItem')
external void _setItem(JSString key, JSString value);

/// Web localStorage access via js_interop.
String? webStorageGet(String key) => _getItem(key.toJS)?.toDart;
void webStorageSet(String key, String value) => _setItem(key.toJS, value.toJS);
