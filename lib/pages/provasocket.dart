import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

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

    IO.Socket socket = IO.io('https://tagliabuemichele.homepc.it/', <String, dynamic>{'transports': ['websocket']});
    socket.on('connect', (_) { 
      setState(() {
        status = "Connected!";
        socket.emit("ping");
      });
    });
    socket.on('disconnect', (_) { 
      setState(() {
        status = "Disconnected :/";
      });
    });
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