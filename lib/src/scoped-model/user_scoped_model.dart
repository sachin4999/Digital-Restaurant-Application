import 'dart:convert';
import 'package:restaurant_app/src/enums/auth_mode.dart';
import 'package:restaurant_app/src/models/user_info_model.dart';
import 'package:scoped_model/scoped_model.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;

class UserModel extends Model {

  List<User> _users = [];
  List<UserInfo> _userInfos =[];

  User _authenticatedUser;
  UserInfo _authenticatedUserInfo;

  bool _isLoading = false;

  List<User> get users{
    return List.from(_users);
  }
  List<UserInfo> get userInfos{
    return List.from(_userInfos);
  }

  User get authenticatedUser{
    return _authenticatedUser;
  }
  UserInfo get authenticatedUserInfo{
    return _authenticatedUserInfo;
  }
  
  bool get isLoading{
    return _isLoading;
  }

  Future<bool> fetchUserInfos() async {
    _isLoading = true;
    notifyListeners();

    try {
      final http.Response response = await http.get("https://restaurant-app-8548a-default-rtdb.firebaseio.com/users.json");

      final Map<String, dynamic> fetchedData = json.decode(response.body);

      final List<UserInfo> userInfos = [];

      fetchedData.forEach((String id, dynamic userInfoData) {
        UserInfo userInfo = UserInfo(
          id: id,
          email: userInfoData['email'],
          userType: userInfoData['userType'],
          userId: userInfoData['localId'],
          username: userInfoData['username'],
        );

        userInfos.add(userInfo);
      });

      _userInfos = userInfos;
      _isLoading = false;
      notifyListeners();
      return Future.value(true);
    } catch (error) {
      print("The error: $error");
      _isLoading = false;
      notifyListeners();
      return Future.value(false);
    }
  }

  Future<bool> addUserInfo(Map<String, dynamic> userInfo) async {
    _isLoading = true;
    notifyListeners();

    try {

      final http.Response response = await http.post(
          "https://restaurant-app-8548a-default-rtdb.firebaseio.com/users.json",
          body: json.encode(userInfo));

      final Map<String, dynamic> responseData = json.decode(response.body);

      UserInfo userInfoWithId = UserInfo(
        id: responseData['name'],
        email: userInfo['email'],
        username: userInfo['username'],
      );

      _userInfos.add(userInfoWithId);
      _isLoading = false;
      notifyListeners();
      return Future.value(true);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return Future.value(false);
    }
  }

  Future<UserInfo> getUserInfo(String userId) async {
    final bool response = await fetchUserInfos();
    print("The response: $response");
    UserInfo foundUserInfo;

    if (response) {
      for (int i = 0; i < _userInfos.length; i++) {
        if (_userInfos[i].userId == userId) {
          foundUserInfo = _userInfos[i];
          print("The found user: $foundUserInfo");
          break;
        }
      }
    }
    return Future.value(foundUserInfo);
  }

  UserInfo getUserDetails(String userId) {
    fetchUserInfos();
    UserInfo foundUserInfo;

    for (int i = 0; i < _userInfos.length; i++) {
      if (_userInfos[i].userId == userId) {
        foundUserInfo = _userInfos[i];
        break;
      }
    }
    return foundUserInfo;
  }

  Future<Map<String, dynamic>> authenticate(String email, String password,{AuthMode authMode = AuthMode.SignIn, Map<String, dynamic> userInfo}) async {
    
    _isLoading = true;
    notifyListeners();
    
    Map<String, dynamic> authData = {
      "email": email,
      "password": password,
      "returnSecureToken": true,
    };

    String id;
    String message;
    bool hasError = false;

    try {
      http.Response response;
      if(authMode == AuthMode.SignUp){
         response = await http.post(
          "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=AIzaSyBiin7t48GDKGnUPOmdrNQtTCqsTwsznJE",
          body: json.encode(authData),
          headers: {'Content-Type': 'application/json'},
        );
      }else if(authMode == AuthMode.SignIn){
        response = await http.post(
          "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyBiin7t48GDKGnUPOmdrNQtTCqsTwsznJE",
          body: json.encode(authData),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      Map<String, dynamic> responseBody = json.decode(response.body);

      if(responseBody.containsKey('idToken')){
        _authenticatedUser = User(
        id: responseBody['localId'],
        email: responseBody['email'],
        token: responseBody['idToken'],
      );
        if(authMode == AuthMode.SignIn){
          _authenticatedUserInfo = await getUserInfo(responseBody['localId']);
          message = "Signed In Successfully";
        }else if(authMode == AuthMode.SignUp){
          userInfo['localId'] = responseBody['localId'];
          addUserInfo(userInfo);
          message = "Signed Up Successfully";
        }
      }else{
        hasError = true;
        if(responseBody['error']['message'] == 'EMAIL_EXISTS'){
          message = "Email already exists";
          // print("Email already exists");
        }else if(responseBody['error']['message'] == 'EMAIL_NOT_FOUND'){
          message = "Email doesn't exist";
        }else if(responseBody['error']['message'] == 'INVALID_PASSWORD'){
          message = "Password is incorrect";
        }
      }

      print("Printing the user token: ${_authenticatedUser.token}");

      _isLoading = false;
      notifyListeners();
      return {
        'data':_authenticatedUser,
        'message': message,
        'hasError': hasError,
      };
    } catch (error) {

      _isLoading = false;
      notifyListeners();

      return{
        'message': 'Failed',
        'hasError': !hasError,
      };
    }
  }

  void logout(){
    _authenticatedUser = null;
    _authenticatedUserInfo = null;
  }
}
