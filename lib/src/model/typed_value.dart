/// [value] as a [T], or null when it is something else.
///
/// The one rule behind every typed read of a node's stored values. A wrong
/// type reads as missing rather than throwing, because those values come back
/// from a file and a file can be stale or edited by hand. One widening is
/// made: an `int` is accepted as a `double`, because a number written as `1.0`
/// comes back as `1` from anything that is not the Dart VM — a web build, a
/// script, a person with a text editor.
T? typedValue<T>(Object? value) {
  if (value is T) return value;
  if (value is int && 0.0 is T) return value.toDouble() as T;
  return null;
}
