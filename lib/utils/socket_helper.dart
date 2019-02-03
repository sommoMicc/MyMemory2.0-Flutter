import  'package:socket_io_client/socket_io_client.dart' as IO;

import 'network_helper.dart';
import 'storage_helper.dart';

import '../models/socket_listener.dart';
import '../models/message.dart';
import '../models/online_user.dart';

class SocketHelper {
  IO.Socket _socket;
  SocketLoginListener currentSocketListener;
  SocketSearchListener currentSocketSearchListener;
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
      _socket.on("searchResult",_onSearchResult);

      _socket.on("userConnected",_onUserConnected);
      _socket.on("userDisconnected",_onUserDisconnected);
      
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

  void searchUsers(String query) {
    print("Do search");
    _socket.emit("search",query);
  }

  void _onSearchResult(dynamic data) {
    print("Search Result:");
    Message response = Message.fromJSON(data);
    if(response.status == "success") {
      List<OnlineUser> users = [];
      List<dynamic> results = response.data['users'];
      results.forEach((onlineUserJSON) {
        users.add(OnlineUser.fromJSON(onlineUserJSON));
      });
      currentSocketSearchListener.onSearchResult(users);
      //currentSocketListener.onLoginResult(true, response.message);
    }
    else {
      //currentSocketListener.onLoginResult(false, null);
    }
  }


  void _onUserConnected(dynamic username) {
    print("Utente connesso: "+username);
  }

  void _onUserDisconnected(dynamic username) {
    print("Utente disconnesso: "+username);
  }
}