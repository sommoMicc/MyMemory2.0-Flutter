//Definisce un utente avversario
class OnlineUser {
  String username;
  bool isOnline;

  OnlineUser(this.username,this.isOnline);

  factory OnlineUser.fromJSON(Map<String, dynamic> json) {
    return OnlineUser(json['username'],json['online']);
  }
}