//Risposta ad un'operazione di rete
class Message {
  String status;
  String message;
  Map<String, dynamic> data;

  Message(this.status,this.message,this.data);
  
  factory Message.fromJSON(Map<String, dynamic> json) {
    return Message(json['status'],json['message'],json['data']);
  }
}