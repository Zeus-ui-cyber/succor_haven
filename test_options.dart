import 'package:socket_io_client/socket_io_client.dart' as io;

void main() {
  final opts = io.OptionBuilder().enableForceNew().build();
  print(opts);
}
