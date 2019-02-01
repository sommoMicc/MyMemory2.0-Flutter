import 'package:http/http.dart' as http;
import 'dart:convert'; //per JSON

import './storage_helper.dart';
import '../models/message.dart';

class NetworkHelper {
  static final String PROTOCOL = "https";
  static final String WEB_DOMAIN = "tagliabuemichele.homepc.it";
  static final int PORT = 443;

  static Future<Message> doSignUp(String username, String email) async {
    print("Daje chiamato dosignup");

    final response = await http.post(
      _buildURL()+"/signup",
      body: {
        "username": username??"",
        "email": email??""
      }
    );
    if (response.statusCode == 200) {
      return Message.fromJSON(json.decode(response.body));
    } else {
      throw Exception('Comunicazione fallita');
    }
  }

  static Future<Message> doLogin(String email) async {
    print("Daje chiamato doLogin");

    final response = await http.post(
      _buildURL()+"/login",
      body: {
        "email": email??""
      }
    );
    if (response.statusCode == 200) {
      return Message.fromJSON(json.decode(response.body));
    } else {
      throw Exception('Comunicazione fallita');
    }
  }

  static String _buildURL() {
    return PROTOCOL+"://"+WEB_DOMAIN+":"+PORT.toString();
  }
}