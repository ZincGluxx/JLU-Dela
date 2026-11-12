//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AuthApi {
  AuthApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Activate an invited workbench account
  ///
  /// Exchanges a one-time invitation for a workbench account. The operator issues the invitation out of band together with the login and display name, so the invitee only chooses a password. The invitation is consumed in the same transaction that creates the user and the first session, so one invitation can activate at most one account even when two requests race.  The password is 12-128 Unicode code points with no character-class requirement, and it must differ from the invitation's login. The invitation login is normalized when the operator creates the invitation, not by this request.  An invalid, expired or already used invitation returns the same 401 `INVALID_INVITE` body, so the response does not reveal whether the token ever existed. Clients must not log the invitation token. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ActivateRequest] activateRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> activateAccountWithHttpInfo(ActivateRequest activateRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/auth/activate';

    // ignore: prefer_final_locals
    Object? postBody = activateRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Activate an invited workbench account
  ///
  /// Exchanges a one-time invitation for a workbench account. The operator issues the invitation out of band together with the login and display name, so the invitee only chooses a password. The invitation is consumed in the same transaction that creates the user and the first session, so one invitation can activate at most one account even when two requests race.  The password is 12-128 Unicode code points with no character-class requirement, and it must differ from the invitation's login. The invitation login is normalized when the operator creates the invitation, not by this request.  An invalid, expired or already used invitation returns the same 401 `INVALID_INVITE` body, so the response does not reveal whether the token ever existed. Clients must not log the invitation token. 
  ///
  /// Parameters:
  ///
  /// * [ActivateRequest] activateRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<TokenPairResponse?> activateAccount(ActivateRequest activateRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await activateAccountWithHttpInfo(activateRequest, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TokenPairResponse',) as TokenPairResponse;
    
    }
    return null;
  }

  /// Exchange a login and password for a session
  ///
  /// Verifies a workbench password and issues a new session. The server trims leading and trailing whitespace and lowercases `login` before validating it, so mixed-case input is accepted but stored and compared in lower case.  A wrong password, an unknown login, a user without a password and a disabled user all return the same 401 `INVALID_CREDENTIALS` body and cost one password verification, so the response does not reveal whether an account exists. Consecutive failures are counted per account: five failures within 15 minutes lock the account for 15 minutes, and further attempts return 429 `RATE_LIMITED` with `Retry-After` seconds even when the supplied password is correct. A successful login clears the counter. The limiter is per account, not per IP address. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [LoginRequest] loginRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> loginAccountWithHttpInfo(LoginRequest loginRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/auth/login';

    // ignore: prefer_final_locals
    Object? postBody = loginRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Exchange a login and password for a session
  ///
  /// Verifies a workbench password and issues a new session. The server trims leading and trailing whitespace and lowercases `login` before validating it, so mixed-case input is accepted but stored and compared in lower case.  A wrong password, an unknown login, a user without a password and a disabled user all return the same 401 `INVALID_CREDENTIALS` body and cost one password verification, so the response does not reveal whether an account exists. Consecutive failures are counted per account: five failures within 15 minutes lock the account for 15 minutes, and further attempts return 429 `RATE_LIMITED` with `Retry-After` seconds even when the supplied password is correct. A successful login clears the counter. The limiter is per account, not per IP address. 
  ///
  /// Parameters:
  ///
  /// * [LoginRequest] loginRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<TokenPairResponse?> loginAccount(LoginRequest loginRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await loginAccountWithHttpInfo(loginRequest, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TokenPairResponse',) as TokenPairResponse;
    
    }
    return null;
  }

  /// Revoke the current session
  ///
  /// Revokes the session identified by the bearer token. The refresh token in the body must belong to the same session. After this call both tokens are invalid, other sessions of the same user stay usable, and campus source credentials are not affected unless their owner revokes them separately. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [LogoutRequest] logoutRequest (required):
  Future<Response> logoutSessionWithHttpInfo(LogoutRequest logoutRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/auth/logout';

    // ignore: prefer_final_locals
    Object? postBody = logoutRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Revoke the current session
  ///
  /// Revokes the session identified by the bearer token. The refresh token in the body must belong to the same session. After this call both tokens are invalid, other sessions of the same user stay usable, and campus source credentials are not affected unless their owner revokes them separately. 
  ///
  /// Parameters:
  ///
  /// * [LogoutRequest] logoutRequest (required):
  Future<void> logoutSession(LogoutRequest logoutRequest, { Future<void>? abortTrigger, }) async {
    final response = await logoutSessionWithHttpInfo(logoutRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Rotate the session token pair
  ///
  /// Exchanges a current refresh token for a new access and refresh token. Both tokens rotate on every call. A token that was already rotated, revoked or expired is rejected, and the client must return to the workbench login entry point. This endpoint is not used to reconnect a campus source. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [RefreshRequest] refreshRequest (required):
  Future<Response> refreshSessionWithHttpInfo(RefreshRequest refreshRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/auth/refresh';

    // ignore: prefer_final_locals
    Object? postBody = refreshRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Rotate the session token pair
  ///
  /// Exchanges a current refresh token for a new access and refresh token. Both tokens rotate on every call. A token that was already rotated, revoked or expired is rejected, and the client must return to the workbench login entry point. This endpoint is not used to reconnect a campus source. 
  ///
  /// Parameters:
  ///
  /// * [RefreshRequest] refreshRequest (required):
  Future<TokenPairResponse?> refreshSession(RefreshRequest refreshRequest, { Future<void>? abortTrigger, }) async {
    final response = await refreshSessionWithHttpInfo(refreshRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TokenPairResponse',) as TokenPairResponse;
    
    }
    return null;
  }
}
