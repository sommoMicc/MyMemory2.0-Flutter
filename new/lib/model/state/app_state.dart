import 'package:flutter/material.dart';
import 'package:lets_memory/model/pojo/connection_status.dart';
import 'package:lets_memory/model/pojo/user.dart';

class AppState with ChangeNotifier  {
  User _user;
  BuildContext context;
  ConnectionStatus _connectionStatus;

  get user => this._user;
  set user(User newUser) {
    this._user = newUser;
    notifyListeners();
  }

  get connectionStatus => this._connectionStatus ?? ConnectionStatus.disconnected;
  set connectionStatus (ConnectionStatus newStatus){
    this._connectionStatus = newStatus;
    notifyListeners();
  }

}