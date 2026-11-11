//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class TodosApi {
  TodosApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create a todo idempotently
  ///
  /// The `Idempotency-Key` header carries a client-generated UUID and is valid for 24 hours:  - same key and same request: returns the first result again with 201 - same key and a different request: 409 `IDEMPOTENCY_CONFLICT` - the idempotency record and the todo are written in one transaction  The server trims `title` before validating 1-200 characters. `notes` is limited to 20,000 characters. `id`, `revision`, `owner_id` and `source_status` are server-managed and rejected with 422.  Omitting `due_kind` makes the server infer it from the values supplied: `due_at` alone means `exact`, `due_date` alone means `date_only`, and no due field at all means `none`. Supplying both `due_at` and `due_date`, or a `due_kind` that does not match the values, is rejected with 422 and `fields[].path` points at the conflicting field.  Creation infers the kind from the values; update never does. Once a todo exists, changing its deadline requires an explicit `due_kind`.  A missing or malformed `Idempotency-Key` is 422 with `fields[].path = \"Idempotency-Key\"`, not 400 or 401. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated UUID. A retry of the same creation must reuse the same value.
  ///
  /// * [CreateTodoRequest] createTodoRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> createTodoWithHttpInfo(String idempotencyKey, CreateTodoRequest createTodoRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/todos';

    // ignore: prefer_final_locals
    Object? postBody = createTodoRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }
    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

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

  /// Create a todo idempotently
  ///
  /// The `Idempotency-Key` header carries a client-generated UUID and is valid for 24 hours:  - same key and same request: returns the first result again with 201 - same key and a different request: 409 `IDEMPOTENCY_CONFLICT` - the idempotency record and the todo are written in one transaction  The server trims `title` before validating 1-200 characters. `notes` is limited to 20,000 characters. `id`, `revision`, `owner_id` and `source_status` are server-managed and rejected with 422.  Omitting `due_kind` makes the server infer it from the values supplied: `due_at` alone means `exact`, `due_date` alone means `date_only`, and no due field at all means `none`. Supplying both `due_at` and `due_date`, or a `due_kind` that does not match the values, is rejected with 422 and `fields[].path` points at the conflicting field.  Creation infers the kind from the values; update never does. Once a todo exists, changing its deadline requires an explicit `due_kind`.  A missing or malformed `Idempotency-Key` is 422 with `fields[].path = \"Idempotency-Key\"`, not 400 or 401. 
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated UUID. A retry of the same creation must reuse the same value.
  ///
  /// * [CreateTodoRequest] createTodoRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<TodoResponse?> createTodo(String idempotencyKey, CreateTodoRequest createTodoRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await createTodoWithHttpInfo(idempotencyKey, createTodoRequest, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TodoResponse',) as TodoResponse;
    
    }
    return null;
  }

  /// Soft-delete a todo with optimistic concurrency
  ///
  /// `If-Match` carries the revision the client holds, as a decimal string. A stale revision returns 409 `REVISION_CONFLICT`; the client should refetch and decide again. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] ifMatch (required):
  ///   The revision the client holds, for example `\"3\"`.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> deleteTodoWithHttpInfo(String id, String ifMatch, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/todos/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }
    headerParams[r'If-Match'] = parameterToString(ifMatch);

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Soft-delete a todo with optimistic concurrency
  ///
  /// `If-Match` carries the revision the client holds, as a decimal string. A stale revision returns 409 `REVISION_CONFLICT`; the client should refetch and decide again. 
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] ifMatch (required):
  ///   The revision the client holds, for example `\"3\"`.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<void> deleteTodo(String id, String ifMatch, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await deleteTodoWithHttpInfo(id, ifMatch, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// List the caller's todos
  ///
  /// The caller is the user of the bearer session. The server ignores any user identifier supplied by the client.  Sorted by the effective due key ascending with nulls last, then by `id` ascending so the order is stable across pages.  The effective due key is `COALESCE(due_at, due_date at Asia/Shanghai midnight)`, so a `date_only` todo sorts as the start of that calendar day in the display timezone, not as UTC midnight.  The cursor is bound to the `completed` filter: changing the filter mid-pagination returns 400 `BAD_CURSOR`. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [bool] completed:
  ///   Filter by completion state. Omit to return both.
  ///
  /// * [int] limit:
  ///
  /// * [String] cursor:
  ///   Opaque `meta.next_cursor` from the previous page. Clients must not construct it.
  Future<Response> listTodosWithHttpInfo({ String? xRequestId, bool? completed, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/todos';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (completed != null) {
      queryParams.addAll(_queryParams('', 'completed', completed));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List the caller's todos
  ///
  /// The caller is the user of the bearer session. The server ignores any user identifier supplied by the client.  Sorted by the effective due key ascending with nulls last, then by `id` ascending so the order is stable across pages.  The effective due key is `COALESCE(due_at, due_date at Asia/Shanghai midnight)`, so a `date_only` todo sorts as the start of that calendar day in the display timezone, not as UTC midnight.  The cursor is bound to the `completed` filter: changing the filter mid-pagination returns 400 `BAD_CURSOR`. 
  ///
  /// Parameters:
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [bool] completed:
  ///   Filter by completion state. Omit to return both.
  ///
  /// * [int] limit:
  ///
  /// * [String] cursor:
  ///   Opaque `meta.next_cursor` from the previous page. Clients must not construct it.
  Future<TodoListResponse?> listTodos({ String? xRequestId, bool? completed, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    final response = await listTodosWithHttpInfo(xRequestId: xRequestId, completed: completed, limit: limit, cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TodoListResponse',) as TodoListResponse;
    
    }
    return null;
  }

  /// Update a todo with optimistic concurrency
  ///
  /// `revision` is required. Fields that are absent keep their current value.  Due fields are replaced as a group: once `due_kind` appears in the body, the server writes all three due fields at once and clears whichever one the kind does not use. `{\"revision\": 2, \"due_kind\": \"none\"}` therefore clears the deadline.  Supplying `due_date` or `due_at` (including an explicit `null`) without `due_kind` is rejected with 422 and `fields[].path` at the stray field. The update never infers the kind, so a client that sends `Optional.present(null)` on a nullable due field cannot silently leave the stored deadline in place. Clearing a deadline always means sending an explicit `due_kind`.  A body that carries only `revision` is accepted and still increments `revision` by one.  `color` has three states: absent keeps the current value, explicit `null` restores the default colour, and a value sets it. Generated Dart clients must be able to tell \"absent\" from \"explicit null\", otherwise they cannot express \"restore the default colour\".  A stale `revision` returns 409 `REVISION_CONFLICT` with the server's current todo in `error.current`, so the client can keep the user's draft and let them choose. A successful update increments `revision` by one. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [UpdateTodoRequest] updateTodoRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> updateTodoWithHttpInfo(String id, UpdateTodoRequest updateTodoRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/todos/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = updateTodoRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Update a todo with optimistic concurrency
  ///
  /// `revision` is required. Fields that are absent keep their current value.  Due fields are replaced as a group: once `due_kind` appears in the body, the server writes all three due fields at once and clears whichever one the kind does not use. `{\"revision\": 2, \"due_kind\": \"none\"}` therefore clears the deadline.  Supplying `due_date` or `due_at` (including an explicit `null`) without `due_kind` is rejected with 422 and `fields[].path` at the stray field. The update never infers the kind, so a client that sends `Optional.present(null)` on a nullable due field cannot silently leave the stored deadline in place. Clearing a deadline always means sending an explicit `due_kind`.  A body that carries only `revision` is accepted and still increments `revision` by one.  `color` has three states: absent keeps the current value, explicit `null` restores the default colour, and a value sets it. Generated Dart clients must be able to tell \"absent\" from \"explicit null\", otherwise they cannot express \"restore the default colour\".  A stale `revision` returns 409 `REVISION_CONFLICT` with the server's current todo in `error.current`, so the client can keep the user's draft and let them choose. A successful update increments `revision` by one. 
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [UpdateTodoRequest] updateTodoRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<TodoResponse?> updateTodo(String id, UpdateTodoRequest updateTodoRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await updateTodoWithHttpInfo(id, updateTodoRequest, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TodoResponse',) as TodoResponse;
    
    }
    return null;
  }
}
