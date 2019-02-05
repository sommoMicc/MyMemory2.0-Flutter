import 'package:http/http.dart' as http;
import 'dart:convert'; //per JSON

import 'package:letsmemory/utils/storage_helper.dart';
import 'package:letsmemory/utils/socket_helper.dart';
import 'package:letsmemory/models/message.dart';

import 'dart:io' show Platform;

class NetworkHelper {
  static final String PROTOCOL = "https";
  static final String WEB_DOMAIN = "tagliabuemichele.homepc.it";
  static final String PORT = "443";
  
  static final String ADDRESS = PROTOCOL+"://"+WEB_DOMAIN;

  static Future<Message> doSignUp(String username, String email) async {

    final response = await http.post(
      _buildURL()+"/signup",
      body: {
        "username": username??"",
        "email": email??"",
        "platform": Platform.isIOS ? "IOS":"ANDROID"
      }
    );
    if (response.statusCode == 200) {
      return Message.fromJSON(json.decode(response.body));
    } else {
      throw Exception('Comunicazione fallita');
    }
  }

  static Future<Message> doLogin(String email) async {
    final response = await http.post(
      _buildURL()+"/login",
      body: {
        "email": email??"",
        "platform": Platform.isIOS ? "IOS":"ANDROID"
      }
    );
    if (response.statusCode == 200) {
      return Message.fromJSON(json.decode(response.body));
    } else {
      throw Exception('Comunicazione fallita');
    }
  }

  static Future<Message> finishLogin(String token) async {
    final response = await http.post(
      _buildURL()+"/finishLogin",
      body: {
        "token": token??"",
        "platform": Platform.isIOS ? "IOS":"ANDROID"
      }
    );
    if (response.statusCode == 200) {
      Message responseMessage = await Message.fromJSON(json.decode(response.body));
      if(responseMessage.status == "success") {
        if(responseMessage.data != null) {
          await StorageHelper().setToken(responseMessage.data['token']);
          await StorageHelper().setUsername(responseMessage.data['username']);

          SocketHelper().mightConnect();
        }
      }
      return responseMessage;
    } else {
      throw Exception('Comunicazione fallita');
    }
  }

  static String _buildURL() {
    return PROTOCOL+"://"+WEB_DOMAIN+":"+PORT.toString();
  }
}