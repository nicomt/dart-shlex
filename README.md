# dart-shlex

`dart-shlex` is a Dart module for quoting and parsing shell commands.
This library is a port of the [`node-shelex`](https://github.com/rgov/node-shlex) traying to keep as close to the original as possible.

The following is verbatim quote from the original documentation.

> The API was inspired by the [`shlex`][pyshlex] module from the Python Standard 
Library. However, the Python implementation is fairly complex, and supports a
confusing matrix of modes that is not replicated here. `node-shlex` always
operates in what the Python module calls "POSIX mode."

[pyshlex]: https://docs.python.org/3/library/shlex.html

> As of version 2.0.0, Bash's [ANSI C strings][ansi-c] (`$'x'`) and
[locale-specific translation strings][locale] (`$"x"`) are supported. This
diverges from the Python `shlex` behavior but makes parsing more accurate.

[ansi-c]: https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html
[locale]: https://www.gnu.org/software/bash/manual/html_node/Locale-Translation.html

> Note that `node-shlex` does not attempt to split on or otherwise parse 
operators (such as `2>/dev/null`), and it does not perform variable interpolation.

## Usage

### `shlex.quote()`

```dart
import 'package:shlex/shlex.dart' as shlex;

main() {
  shlex.quote("abc");      // returns: abc
  shlex.quote("abc def");  // returns: 'abc def'
  shlex.quote("can't");    // returns: 'can'"'"'t'
}
```

### `shlex.split()`

```dart
import 'package:shlex/shlex.dart' as shlex;

main() {
  shlex.split('ls -al /')  // returns: [ 'ls', '-al', '/' ]
  shlex.split('rm -f "/Volumes/Macintosh HD"')  // returns [ 'rm', '-f', '/Volumes/Macintosh HD' ]
}
```
