import './online_user.dart';

abstract class SocketListener {
  void onLoginResult(bool success, String username);
  void onSearchResult(List<OnlineUser> users);

  void onChallengeReceived(String username);
  void onChallengeDenided(String username);

  void onBeginGame(String username);

  bool isMounted();
}

