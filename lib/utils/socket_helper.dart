import 'network_helper.dart';
import 'storage_helper.dart';

import '../models/socket_listener.dart';
import '../models/message.dart';

import  'package:socket_io_client/socket_io_client.dart' as IO;


class SocketHelper {
  static IO.Socket _socket;
  static SocketListener currentSocketListener;

  static final SocketHelper _singleton = SocketHelper._internal();
  factory SocketHelper() {
    return _singleton;
  }
  SocketHelper._internal() {
    print("CHIAMATO COSTRUTTORE SOCKETHELPER");
    _socket = IO.io(NetworkHelper.ADDRESS, <String, dynamic>{'transports': ['websocket']});
    _socket.on("connect",(_) async {
      print("Connected");
      _doLogin();
    });

    _socket.on("loginResponse",_onLoginResponse);
  }

  void _doLogin() async {
    String token = await StorageHelper().getToken();
    if(token != null && token.length != 0) {      
      _socket.emit("login",token);
    }
  }

  void _onLoginResponse(dynamic data) {
    Message response = Message.fromJSON(data);
    if(response.status == "success") {
      currentSocketListener.onLoginResult(true, response.message);
    }
    else {
      currentSocketListener.onLoginResult(false, null);
    }
  }
}