import 'package:shlex/shlex.dart' as shlex;

void main() {
  print(shlex.split('ls -l "/hello world"'));
}
