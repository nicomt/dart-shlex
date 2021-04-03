library shlex;

import 'package:shlex/src/shlexer.dart';

export 'src/shlexer.dart';

// Splits a given string using shell-like syntax.
List<String> split(String s) {
  return Shlexer(s).toList();
}

// Escapes a potentially shell-unsafe string using quotes.
String quote(String s) {
  if (s == '') { return '\'\''; }
  var unsafeRe = RegExp(r'[^\w@%\-+=:,./]');
  if (!unsafeRe.hasMatch(s)) { return s; }
  return '\'' + s.replaceAll('\'', '\'"\'"\'') + '\'';
}