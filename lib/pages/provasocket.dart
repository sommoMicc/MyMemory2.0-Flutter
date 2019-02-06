import 'package:flutter/material.dart';
import 'package:adhara_socket_io/adhara_socket_io.dart';

class ProvaSocket extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _ProvaSocketState();
  }
}

class _ProvaSocketState extends State<ProvaSocket> {
  String status;
  String additionalInfo;
  @override
  void initState() {
    super.initState();
    status = "Nothing done";
    additionalInfo = "";
    initSocket();
  }
  
  void initSocket() async {
    SocketIO socket = await SocketIOManager().createInstance('https://tagliabuemichele.homepc.it/');       //TODO change the port  accordingly
    socket.onConnect((data){
      print("connected...");
      print(data);
      setState(() {
        status = "Connected";
      });
    });
    socket.onDisconnect((data) {
      setState(() {
        status = "Disconnected "+data;
      });
      print("Disconneted :(");
      print(data);
    });
    socket.on("news", (data){   //sample event
      print("news");
      print(data);
    });
    socket.on("pong", (data) {
      setState(() {
        status = "Ricevuto pong";
      });
    });
    socket.on("ping", (data) {
      setState(() {
        status = "Ricevuto ping";
      });
    });

    socket.connect();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(status),
            Padding(padding: EdgeInsets.only(top: 10)),
            Text(additionalInfo)
          ]
        ),
      ),
    );
  }
}