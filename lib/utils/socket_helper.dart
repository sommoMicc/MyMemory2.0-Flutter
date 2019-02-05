import  'package:socket_io_client/socket_io_client.dart' as IO;

import 'network_helper.dart';
import 'storage_helper.dart';

import 'package:letsmemory/models/socket_listener.dart';
import 'package:letsmemory/models/message.dart';
import '../models/online_user.dart';

import 'package:letsmemory/UI/lets_memory_flipable_card.dart';
import 'dart:async';

class SocketHelper {
  static IO.Socket _socket;
  List<SocketListener> currentSocketListener = [];
  GameSocketListener currentGameListener;

  List<OnlineUser> searchResults;

  bool isConnectionInitiated;
  bool isConnected;

  Timer reconnectTimer;

  static final SocketHelper _singleton = SocketHelper._internal();
  factory SocketHelper() {
    return _singleton;
  }
  SocketHelper._internal(): isConnectionInitiated = false, isConnected = false {
    print("Chiamato metodo sockethelper internal"); 
  }

  void mightConnect() async {
    //Inizializzo il socket solo se ho già un token (quindi ho già fatto il login via HTTP)
    print("Chiamato mightConnect");
    String token = await StorageHelper().getToken();
    if(token != null && token.length > 0 && !isConnectionInitiated) {
      connect();
      print("Inizializzata connessione con connect");
    }
    else {
      print("connessione con connect non inizializzata");
    }
  }

  void connect() {
    if(!isConnectionInitiated) {
      isConnectionInitiated = true;
      if(_socket == null) {
        _socket = IO.io(NetworkHelper.ADDRESS, <String, dynamic>{'transports': ['websocket']});
        _socket.on("connect",(_) async {
          if(reconnectTimer != null) {
            reconnectTimer.cancel();
          }
          print("Connected");
          isConnected = true;
          _doLogin();
        });
      }

      _socket.on("loginResponse",_onLoginResponse);
      _socket.on("searchResult",_onSearchResult);

      _socket.on("userConnected",_onUserConnected);
      _socket.on("userDisconnected",_onUserDisconnected);

      _socket.on("wannaChallenge",_onChallengeReceived);
      _socket.on("challengeDenided",_onChallengeDenided);

      _socket.on("beginGame",_onBeginGame);
      _socket.on("adversaryLeft",_onAdversaryLeft);
      
      _socket.on("disconnect",_onDisconnect);
      _socket.on("reconnect",_onReconnect);

      _socket.on("adversaryTurn",_onAdversaryTurn);
      _socket.on("myTurn",_onMyTurn);
      _socket.on("adversaryCardFlipped",_onAdversaryCardFlipped);
      _socket.on("adversaryCardHidden",_onAdversaryCardHidden);
      _socket.on("gameFinished",_onGameFinished);
    }
  }

  void _doLogin() async {
    String token = await StorageHelper().getToken();
    if(token != null && token.length != 0) {      
      _socket.emit("login",token);
    }
  }

  void addSocketListener(SocketListener listener) {
    print("Chiamato addSocketListener");
    currentSocketListener.add(listener);
    print("Ora la lista ha "+currentSocketListener.length.toString()+" elementi");
  }

  void removeSocketListener(SocketListener listener) {
    print("Chiamato removeSocketListener");
    currentSocketListener.remove(listener);
    print("Ora la lista ha "+currentSocketListener.length.toString()+" elementi");
  }

  void _onLoginResponse(dynamic data) {
    Message response = Message.fromJSON(data);
    if(response.status == "success") {
      currentSocketListener.forEach((listener) {
        if(listener.isMounted())
          listener.onLoginResult(true, response.message);
      });
    }
    else {
      StorageHelper().logout();
      currentSocketListener.forEach((listener) {
        if(listener.isMounted())
          listener.onLoginResult(false, null);
      });
    }
  }

  void searchUsers(String query) {
    _socket.emit("search",query);
  }

  void _onSearchResult(dynamic data) {
    Message response = Message.fromJSON(data);
    if(response.status == "success") {
      searchResults = [];
      List<dynamic> results = response.data['users'];
      results.forEach((onlineUserJSON) {
        searchResults.add(OnlineUser.fromJSON(onlineUserJSON));
      });

      _notifySearchResultChanged();
    }
    else {
      //currentSocketListener.onLoginResult(false, null);
    }
  }

  void _notifySearchResultChanged() {
      currentSocketListener.forEach((listener) {
        if(listener.isMounted())
          listener.onSearchResult(searchResults);
      });
  }


  void _onUserConnected(dynamic username) {
    for(int i=0;i<searchResults.length;i++) {
      if(username == searchResults[i].username) {
        searchResults[i].isOnline = true;
      }
    }
    _notifySearchResultChanged();
  }

  void _onUserDisconnected(dynamic username) {
    for(int i=0;i<searchResults.length;i++) {
      if(username == searchResults[i].username) {
        searchResults[i].isOnline = false;
      }
    }
    _notifySearchResultChanged();
  }

  void _onChallengeReceived(dynamic username) {
    currentSocketListener.forEach((listener) {
      if(listener.isMounted())
        listener.onChallengeReceived(username);
    });
  }

  void _onChallengeDenided(dynamic username) {
    currentSocketListener.forEach((listener) {
      if(listener.isMounted())
        listener.onChallengeDenided(username);
    });
  }

  void acceptChallenge(String username) {
    _socket.emit("challengeAccepted",username);
  }

  void denyChallenge(String username) {
    _socket.emit("challengeDenided",username);
  }

  void sendChallenge(String username) {
    _socket.emit("sendChallenge",username);
  }

  void _onBeginGame(dynamic data) async {
    Message message = Message.fromJSON(data);

    if(message.status == "success") {
      List<LetsMemoryFlipableCard> cards = [];
      List<dynamic> cardsDynamicList = message.data['cards'];
      cardsDynamicList.forEach((cardJSON) {
        cards.add(LetsMemoryFlipableCard.fromJSON(cardJSON));
      });

      String currentUseranme = await StorageHelper().getUsername();
      List<dynamic> players = message.data['players'];
      
      int playerNumber;
      bool playerFound = false;
      
      for(playerNumber=0;playerNumber<players.length && 
        !playerFound;playerNumber++) {
        
        if(players[playerNumber] == currentUseranme) {
          playerFound = true;
        }
      }

      currentSocketListener.forEach((listener) {
        if(listener.isMounted())
          listener.onBeginGame(
            playerNumber+1,
            players[(playerNumber) % players.length],
            cards
          );
      });
    }
  }

  void _onAdversaryLeft(dynamic data) {
    currentSocketListener.forEach((listener) {
      if(listener.isMounted())
        listener.onAdversaryLeft();
    });
  }

  void leaveGame() {
    _socket.emit("leaveGame");
  }

  void _onDisconnect(dynamic data) {
    print("Disconnesso causa: "+data);
    isConnected = false;
    currentSocketListener.forEach((listener) {
      if(listener.isMounted())
        listener.onDisconnect();
    });
    if(currentGameListener != null && currentGameListener.isMounted()) {
      currentGameListener.onDisconnect();
    }
    if(reconnectTimer != null) {
      reconnectTimer.cancel();
    }
    reconnectTimer = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      this.connect();
    });
  }

  void _onReconnect(dynamic data) {
    print("Reconnecting!!");
    isConnected = false;
    currentSocketListener.forEach((listener) {
      if(listener.isMounted())
        listener.onReconnect();
    });
  }


  void _onAdversaryTurn(dynamic data) {
    if(currentGameListener != null && currentGameListener.isMounted()) {
      currentGameListener.onAdversaryTurn();
    }
  }
  void _onMyTurn(dynamic data) {
    if(currentGameListener != null && currentGameListener.isMounted()) {
      currentGameListener.onMyTurn();
    }
  }
  void _onAdversaryCardFlipped(dynamic data) {
    if(currentGameListener != null && currentGameListener.isMounted()) {
      currentGameListener.onAdversaryCardFlipped(data);
    }
  }
  void _onAdversaryCardHidden(dynamic data) {
    if(currentGameListener != null && currentGameListener.isMounted()) {
      currentGameListener.onAdversaryCardHidden(data);
    }
  }

  void cardFlipped(int cardIndex) {
    _socket.emit("cardFlipped",cardIndex);
  }
  void cardHidden(int cardIndex) {
    _socket.emit("cardHidden",cardIndex);
  }

  void _onGameFinished(dynamic winner) {
    if(currentGameListener != null && currentGameListener.isMounted()) {
      currentGameListener.onGameFinished(winner);
    }
  }

}