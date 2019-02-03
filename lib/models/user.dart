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
    return User(json['username'],json['token']);
  }
}