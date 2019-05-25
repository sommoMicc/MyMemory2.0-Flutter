class Arena {
  int id;
  String name;
  List<String> symbols;

  Arena({this.id,this.name,this.symbols});

  Arena.fromJson(Map<String,dynamic> json) :
    id = json["id"],
    name = json["name"],
    symbols = (json["symbols"] ?? "").toString().split(",");

  Map<String,dynamic> toJson() => {
    "id": this.id,
    "name": this.name,
    "symbols": (this.symbols ?? []).join(",")
  };
}