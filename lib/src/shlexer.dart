// Port of https://github.com/rgov/node-shlex

class Shlexer extends Iterable<String> {
  String str;
  bool debug;

  // Characters that will be considered whitespace and skipped. Whitespace
  // bounds tokens. By default, includes space, tab, linefeed and carriage
  // return.
  String whitespace;

  // Characters that will be considered string quotes. The token accumulates
  // until the same quote is encountered again (thus, different quote types
  // protect each other as in the shell.) By default, includes ASCII single
  // and double quotes.
  String quotes;

  // Characters that will be considered as escape. Just `\` by default.
  String escapes;

  //The subset of quote types that allow escaped characters. Just `"` by default.
  String escapedQuotes;

  // Whether to support localized $"" quotes
  // https://www.gnu.org/software/bash/manual/html_node/Locale-Translation.html
  //
  // The behavior is as if the current locale is set to C or POSIX, i.e., the
  // contents are not translated.
  bool localeQuotes = true;

  // Whether to support ANSI C-style $'' quotes
  // https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html
  bool ansiCQuotes;

  Shlexer(this.str,
      {this.whitespace = ' \t\r\n',
      this.quotes = '\'"',
      this.escapes = '\\',
      this.escapedQuotes = '"',
      this.ansiCQuotes = true,
      this.debug = false});

  String processEscapes(String input, String quote, bool isAnsiCQuote) {
    if (!isAnsiCQuote && !escapedQuotes.contains(quote)) {
      // This quote type doesn't support escape sequences
      return input;
    }

    // We need to form a regex that matches any of the escape characters,
    // without interpreting any of the characters as a regex special character.
    var anyEscape = '[${escapes.split('').map((c) => '\\$c').join()}]';

    // In regular quoted strings, we can only escape an escape character, and
    // the quote character itself.
    if (!isAnsiCQuote && escapedQuotes.contains(quote)) {
      var re = RegExp('$anyEscape($anyEscape|\\$quote)');
      return input.replaceAllMapped(re, (m) => m[1]!);
    }

    // ANSI C quoted strings support a wide variety of escape sequences
    if (isAnsiCQuote) {
      var patterns = <String, String Function(String)>{
        // Literal characters
        '([\\\\\'"?])': (x) => x,

        // Non-printable ASCII characters
        'a': (x) => '\x07',
        'b': (x) => '\x08',
        'e|E': (x) => '\x1b',
        'f': (x) => '\x0c',
        'n': (x) => '\x0a',
        'r': (x) => '\x0d',
        't': (x) => '\x09',
        'v': (x) => '\x0b',

        // Octal bytes
        '([0-7]{1,3})': (x) => String.fromCharCode(int.parse(x, radix: 8)),

        // Hexadecimal bytes
        'x([0-9a-fA-F]{1,2})': (x) =>
            String.fromCharCode(int.parse(x, radix: 16)),

        // Unicode code units
        'u([0-9a-fA-F]{1,4})': (x) =>
            String.fromCharCode(int.parse(x, radix: 16)),
        'U([0-9a-fA-F]{1,8})': (x) =>
            String.fromCharCode(int.parse(x, radix: 16)),

        // Control characters
        // https://en.wikipedia.org/wiki/Control_character#How_control_characters_map_to_keyboards
        'c(.)': (x) {
          if (x == '?') {
            return '\x7f';
          } else if (x == '@') {
            return '\x00';
          } else {
            return String.fromCharCode(x.codeUnitAt(0) & 31);
          }
        }
      };

      // Construct an uber-RegEx that catches all of the above pattern
      var re = RegExp('$anyEscape(${patterns.keys.join('|')})');

      // For each match, figure out which subpattern matched, and apply the
      // corresponding function
      return input.replaceAllMapped(re, (m) {
        var p1 = m.group(1);
        for (var matched in patterns.keys) {
          var mm = RegExp('^$matched\$').firstMatch(p1!);
          if (mm != null) {
            return patterns[matched]!(mm.groupCount > 0 ? mm.group(1) ?? '' : '');
          }
        }
        return '';
      });
    }

    // Should not get here
    return '';
  }

  @override
  Iterator<String> get iterator {
    return split().iterator;
  }

  Iterable<String> split() sync* {
    var i = 0;
    var lastDollar = -2; // position of last dollar sign we saw
    String? inDollarQuote;
    String? inQuote;
    String? escaped;
    String? token;

    if (debug) {
      print('full input: >$str<');
    }

    while (true) {
      final pos = i;
      final char = i < str.length ? str[i++] : null;

      if (debug) {
        print([
          'position: $pos',
          'input: >$char<',
          'accumulated: $token',
          'inQuote: $inQuote',
          'inDollarQuote: $inDollarQuote',
          'lastDollar: $lastDollar',
          'escaped: $escaped'
        ].join('\n'));
      }

      // Ran out of characters, we're done
      if (char == null) {
        if (inQuote != null) {
          throw ('Got EOF while in a quoted string');
        }
        if (escaped != null) {
          throw ('Got EOF while in an escape sequence');
        }
        if (token != null) {
          yield token;
        }
        return;
      }

      // We were in an escape sequence, complete it
      if (escaped != null) {
        if (char == '\n') {
          // An escaped newline just means to continue the command on the next
          // line. We just need to ignore it.
        } else if (inQuote != null) {
          // If we are in a quote, just accumulate the whole escape sequence,
          // as we will interpret escape sequences later.
          token = (token ?? '') + escaped + char;
        } else {
          // Just use the literal character
          token = (token ?? '') + char;
        }

        escaped = null;
        continue;
      }

      if (escapes.contains(char)) {
        if (inQuote == null ||
            inDollarQuote != null ||
            escapedQuotes.contains(inQuote)) {
          // We encountered an escape character, which is going to affect how
          // we treat the next character.
          escaped = char;
          continue;
        } else {
          // This string type doesn't use escape characters. Ignore for now.
        }
      }

      // We were in a string
      if (inQuote != null) {
        // String is finished. Don't grab the quote character.
        if (char == inQuote) {
          token = processEscapes(token ?? '', inQuote, inDollarQuote == '\'');
          inQuote = null;
          inDollarQuote = null;
          continue;
        }

        // String isn't finished yet, accumulate the character
        token = (token ?? '') + char;
        continue;
      }

      // This is the start of a new string, don't accumulate the quotation mark
      if (quotes.contains(char)) {
        inQuote = char;
        if (lastDollar == pos - 1) {
          if (char == '\'' && !ansiCQuotes) {
            // Feature not enabled
          } else if (char == '"' && !localeQuotes) {
            // Feature not enabled
          } else {
            inDollarQuote = char;
          }
        }

        token = (token ?? ''); // fixes blank string

        if (inDollarQuote != null) {
          // Drop the opening $ we captured before
          token = token.substring(0, token.length - 1);
        }

        continue;
      }

      // This is a dollar sign, record that we saw it in case it's the start of
      // an ANSI C or localized string
      if (inQuote == null && char == '\$') {
        lastDollar = pos;
      }

      // This is whitespace, so yield the token if we have one
      if (whitespace.contains(char)) {
        if (token != null) {
          yield token;
        }
        token = null;
        continue;
      }

      // Otherwise, accumulate the character
      token = (token ?? '') + char;
    }
  }
}
