import 'dart:js_interop';

@JS()
@anonymous
extension type MsalConfig._(JSObject _) implements JSObject {
  external String? get authorizationUrl;
  external set authorizationUrl(String? value);
  external String? get tokenUrl;
  external set tokenUrl(String? value);
  external String? get tenant;
  external set tenant(String? value);
  external String? get policy;
  external set policy(String? value);
  external String? get clientId;
  external set clientId(String? value);
  external String? get responseType;
  external set responseType(String? value);
  external String? get redirectUri;
  external set redirectUri(String? value);
  external String? get scope;
  external set scope(String? value);
  external String? get responseMode;
  external set responseMode(String? value);
  external String? get state;
  external set state(String? value);
  external String? get prompt;
  external set prompt(String? value);
  external String? get codeChallenge;
  external set codeChallenge(String? value);
  external String? get codeChallengeMethod;
  external set codeChallengeMethod(String? value);
  external String? get loginHint;
  external set loginHint(String? value);
  external String? get domainHint;
  external set domainHint(String? value);
  external String? get nonce;
  external set nonce(String? value);
  external String? get tokenIdentifier;
  external set tokenIdentifier(String? value);
  external String? get clientSecret;
  external set clientSecret(String? value);
  external String? get codeVerifier;
  external set codeVerifier(String? value);
  external String? get resource;
  external set resource(String? value);
  external bool? get isB2C;
  external set isB2C(bool? value);
  external String? get customAuthorizationUrl;
  external set customAuthorizationUrl(String? value);
  external String? get customTokenUrl;
  external set customTokenUrl(String? value);
  external String? get cacheLocation;
  external set cacheLocation(String? value);
  external String? get customParameters;
  external set customParameters(String? value);
  external String? get customDomainUrl;
  external set customDomainUrl(String? value);

  static MsalConfig construct({
    String? tenant,
    String? policy,
    String? clientId,
    String? responseType,
    String? redirectUri,
    String? scope,
    String? responseMode,
    String? state,
    String? prompt,
    String? codeChallenge,
    String? codeChallengeMethod,
    String? nonce,
    String? tokenIdentifier,
    String? clientSecret,
    String? resource,
    bool? isB2C,
    String? customAuthorizationUrl,
    String? customTokenUrl,
    String? loginHint,
    String? domainHint,
    String? codeVerifier,
    String? authorizationUrl,
    String? tokenUrl,
    String? cacheLocation,
    String? customParameters,
    String? postLogoutRedirectUri,
    String? customDomainUrl,
  }) {
    final Map<String, dynamic> map = {};
    if (tenant != null) map['tenant'] = tenant;
    if (policy != null) map['policy'] = policy;
    if (clientId != null) map['clientId'] = clientId;
    if (responseType != null) map['responseType'] = responseType;
    if (redirectUri != null) map['redirectUri'] = redirectUri;
    if (scope != null) map['scope'] = scope;
    if (responseMode != null) map['responseMode'] = responseMode;
    if (state != null) map['state'] = state;
    if (prompt != null) map['prompt'] = prompt;
    if (codeChallenge != null) map['codeChallenge'] = codeChallenge;
    if (codeChallengeMethod != null)
      map['codeChallengeMethod'] = codeChallengeMethod;
    if (nonce != null) map['nonce'] = nonce;
    if (tokenIdentifier != null) map['tokenIdentifier'] = tokenIdentifier;
    if (clientSecret != null) map['clientSecret'] = clientSecret;
    if (resource != null) map['resource'] = resource;
    if (isB2C != null) map['isB2C'] = isB2C;
    if (customAuthorizationUrl != null)
      map['customAuthorizationUrl'] = customAuthorizationUrl;
    if (customTokenUrl != null) map['customTokenUrl'] = customTokenUrl;
    if (loginHint != null) map['loginHint'] = loginHint;
    if (domainHint != null) map['domainHint'] = domainHint;
    if (codeVerifier != null) map['codeVerifier'] = codeVerifier;
    if (authorizationUrl != null) map['authorizationUrl'] = authorizationUrl;
    if (tokenUrl != null) map['tokenUrl'] = tokenUrl;
    if (cacheLocation != null) map['cacheLocation'] = cacheLocation;
    if (customParameters != null) map['customParameters'] = customParameters;
    if (postLogoutRedirectUri != null)
      map['postLogoutRedirectUri'] = postLogoutRedirectUri;
    if (customDomainUrl != null) map['customDomainUrl'] = customDomainUrl;

    return map.jsify() as MsalConfig;
  }
}
