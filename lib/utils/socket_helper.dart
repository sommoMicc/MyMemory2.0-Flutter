import  'package:socket_io_client/socket_io_client.dart' as IO;

import 'network_helper.dart';
import 'storage_helper.dart';

import '../models/socket_listener.dart';
import '../models/message.dart';

class SocketHelper {
  IO.Socket _socket;
  SocketListener currentSocketListener;
  bool isConnectionInitiated;

  static final SocketHelper _singleton = SocketHelper._internal();
  factory SocketHelper() {
    return _singleton;
  }
  SocketHelper._internal(): isConnectionInitiated = false;

  void mightConnect() async {
    //Inizializzo il socket solo se ho già un token (quindi ho già fatto il login via HTTP)
    String token = await StorageHelper().getToken();
    if(token != null && token.length > 0) {
      connect();
      print("Inizializzata connessione con connect");
    }
    else {
      print("Token non presente o nullo");
    }
  }

  void connect() {
    if(!isConnectionInitiated) {
      _socket = IO.io(NetworkHelper.ADDRESS, <String, dynamic>{'transports': ['websocket']});
      _socket.on("connect",(_) async {
        print("Connected");
        _doLogin();
      });
  
      _socket.on("loginResponse",_onLoginResponse);
      
    }
    isConnectionInitiated = true;
  }

  void _doLogin() async {
    String token = await StorageHelper().getToken();
    if(token != null && token.length != 0) {      
      _socket.emit("login",token);
    }
  }

  void _onLoginResponse(dynamic data) {
    print(data);
    Message response = Message.fromJSON(data);
    if(response.status == "success") {
      currentSocketListener.onLoginResult(true, response.message);
    }
    else {
      StorageHelper().logout();
      currentSocketListener.onLoginResult(false, null);
    }
  }
}