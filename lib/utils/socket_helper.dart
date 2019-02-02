import 'network_helper.dart';
import  'package:socket_io_client/socket_io_client.dart' as IO;

class SocketHelper {
  static final SocketHelper _singleton = SocketHelper._internal();
  factory SocketHelper() {
    return _singleton;
  }


  // Costruttore vero e proprio
  SocketHelper._internal() {
    print("CHIAMATO COSTRUTTORE SOCKETHELPER");
    IO.Socket socket = IO.io(NetworkHelper.ADDRESS, <String, dynamic>{'transports': ['websocket']});
    socket.on("connect",(_){
      print("Connected");
    });
    socket.open();
  }
}