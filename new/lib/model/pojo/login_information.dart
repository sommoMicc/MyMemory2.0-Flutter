class LoginInformations {
  String username, password;

  LoginInformations({this.username,this.password});

  bool validate() {
    if((this.username ?? "").trim().length < 1) {
      throw "Username non valido";
    }

    if((this.password ?? "").trim().length < 4) {
      throw "Password non valida";
    }

    return true;
  }
}