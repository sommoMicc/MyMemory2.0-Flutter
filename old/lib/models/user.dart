//Identifica l'utente attualmente loggato
class User {
  String username;
  String token;

  User(this.username,this.token);
  Map<String, dynamic> toJson() =>
    {
      'username': username,
      'token': token,
    };
  
  factory User.fromJSON(Map<String, dynamic> json) {
    Map<String, dynamic> jsonData = Map<String, dynamic>.from(json);
    return User(jsonData['username'],jsonData['token']);
  }
}