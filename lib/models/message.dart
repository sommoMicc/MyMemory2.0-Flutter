//Risposta ad un'operazione di rete
class Message {
  String status;
  String message;

  Message(this.status,this.message);
  
  factory Message.fromJSON(Map<String, dynamic> json) {
    return Message(json['status'],json['message']);
  }
}