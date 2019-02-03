import './online_user.dart';

abstract class SocketLoginListener {
  void onLoginResult(bool success, String username);
}

abstract class SocketSearchListener {
    void onSearchResult(List<OnlineUser> users);
}

