import './online_user.dart';
import '../UI/lets_memory_flipable_card.dart';

abstract class SocketListener {
  void onLoginResult(bool success, String username);
  void onSearchResult(List<OnlineUser> users);

  void onChallengeReceived(String username);
  void onChallengeDenided(String username);

  void onBeginGame(List<LetsMemoryFlipableCard> cards);

  void onAdversaryLeft();

  bool isMounted();
}

