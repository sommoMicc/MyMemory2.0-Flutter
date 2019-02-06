//Risposta ad un'operazione di rete
class Message {
  String status;
  String message;
  Map<String, dynamic> data;

  Message(this.status,this.message,this.data) {
    print("Costruttore message");
    print(this.data);
  }
  
  factory Message.fromJSON(dynamic json) {
    Map<String, dynamic> jsonData = Map<String, dynamic>.from(json);

    return Message(jsonData['status'],jsonData['message'],jsonData['data'] == null ? null : Map<String, dynamic>.from(jsonData['data']));
  }
}