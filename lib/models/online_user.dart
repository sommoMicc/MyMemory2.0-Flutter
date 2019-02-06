//Definisce un utente avversario
class OnlineUser {
  String username;
  bool isOnline;

  OnlineUser(this.username,this.isOnline) {
    print("COSTRUITO ONLINE USER");
  }

  factory OnlineUser.fromJSON(Map<String, dynamic> json) {
    print("ONLINE USER FROM JSON");
    Map<String, dynamic> jsonData = Map<String, dynamic>.from(json);
    return OnlineUser(jsonData['username'],jsonData['online']);
  }
}