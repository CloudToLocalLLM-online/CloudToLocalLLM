@JS()
library msauth;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:aad_oauth/helper/core_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:aad_oauth/model/failure.dart';
import 'package:aad_oauth/model/msalconfig.dart';
import 'package:aad_oauth/model/token.dart';
import 'package:dartz/dartz.dart';

@JS('aadOauth')
external AadOauth get aadOauth;

extension type AadOauth._(JSObject _) implements JSObject {
  external void init(MsalConfig config);
  external void login(bool refreshIfAvailable, bool useRedirect,
      JSFunction onSuccess, JSFunction onError);
  external void logout(
      JSFunction onSuccess, JSFunction onError, bool showPopup);
  external JSAny? getAccessToken();
  external JSAny? getIdToken();
  external bool hasCachedAccountInformation();
  external void refreshToken(JSFunction onSuccess, JSFunction onError);
}

class WebOAuth extends CoreOAuth {
  final Config config;
  WebOAuth(this.config) {
    aadOauth.init(MsalConfig.construct(
        tenant: config.tenant,
        policy: config.policy,
        clientId: config.clientId,
        responseType: config.responseType,
        redirectUri: config.redirectUri,
        scope: config.scope,
        responseMode: config.responseMode,
        state: config.state,
        prompt: config.prompt,
        codeChallenge: config.codeChallenge,
        codeChallengeMethod: config.codeChallengeMethod,
        nonce: config.nonce,
        tokenIdentifier: config.tokenIdentifier,
        clientSecret: config.clientSecret,
        resource: config.resource,
        isB2C: config.isB2C,
        customAuthorizationUrl: config.customAuthorizationUrl,
        customTokenUrl: config.customTokenUrl,
        loginHint: config.loginHint,
        domainHint: config.domainHint,
        codeVerifier: config.codeVerifier,
        authorizationUrl: config.authorizationUrl,
        tokenUrl: config.tokenUrl,
        cacheLocation: config.cacheLocation.value,
        customParameters: jsonEncode(config.customParameters),
        postLogoutRedirectUri: config.postLogoutRedirectUri,
        customDomainUrl: config.customDomainUrlWithTenantId));
  }

  @override
  Future<String?> getAccessToken() async {
    final token = aadOauth.getAccessToken();
    return (token as JSString?)?.toDart;
  }

  @override
  Future<String?> getIdToken() async {
    final token = aadOauth.getIdToken();
    return (token as JSString?)?.toDart;
  }

  @override
  Future<bool> get hasCachedAccountInformation =>
      Future<bool>.value(aadOauth.hasCachedAccountInformation());

  @override
  Future<Either<Failure, Token>> login(
      {bool refreshIfAvailable = false}) async {
    final completer = Completer<Either<Failure, Token>>();

    aadOauth.login(
      refreshIfAvailable,
      config.webUseRedirect,
      ((JSAny value) {
        String? tokenStr;
        if (value.isA<JSString>()) {
          tokenStr = (value as JSString).toDart;
        }
        // If not a string, we might want to handle it or just complete with null/empty if that's valid?
        // Assuming string for now based on legacy logic.
        completer.complete(Right(Token(accessToken: tokenStr)));
      }).toJS,
      ((JSAny error) {
        completer.complete(Left(AadOauthFailure(
          errorType: ErrorType.accessDeniedOrAuthenticationCanceled,
          message:
              'Access denied or authentication canceled. Error: ${error.toString()}',
        )));
      }).toJS,
    );

    return completer.future;
  }

  @override
  Future<Either<Failure, Token>> refreshToken() {
    final completer = Completer<Either<Failure, Token>>();

    aadOauth.refreshToken(
      ((JSAny value) {
        String? tokenStr;
        if (value.isA<JSString>()) {
          tokenStr = (value as JSString).toDart;
        }
        completer.complete(Right(Token(accessToken: tokenStr)));
      }).toJS,
      ((JSAny error) {
        completer.complete(Left(AadOauthFailure(
          errorType: ErrorType.accessDeniedOrAuthenticationCanceled,
          message:
              'Access denied or authentication canceled. Error: ${error.toString()}',
        )));
      }).toJS,
    );

    return completer.future;
  }

  @override
  Future<void> logout({bool showPopup = true}) async {
    final completer = Completer<void>();

    aadOauth.logout(
      (() => completer.complete()).toJS,
      ((JSAny error) => completer.completeError(error.toString())).toJS,
      showPopup,
    );

    return completer.future;
  }
}
