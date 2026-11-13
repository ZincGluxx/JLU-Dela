# Private file consumption

All four file operations require the application Bearer token. Never send campus cookies or student reports. The upload contains exactly one binary multipart field named `file`, with its original filename. The default limit is 10 MiB; the configuration ceiling is 64 MiB. Only uploads receive an extra 64 KiB request-body allowance for multipart overhead.

Unattached files are directly readable and deletable only by their uploader. Missing or invisible files return `404 FILE_NOT_FOUND`. Once attached, direct metadata and content reads return 404 even for the uploader. Direct deletion returns `409 FILE_IN_USE` to the uploader and 404 to everyone else. Business consumers must obtain attached files through an authorized business route, not a public-scope query parameter. This phase adds no material or community client endpoints.

Metadata uses the standard `data` / `meta.request_id` envelope. It exposes only `id`, `uploader_id`, `original_name`, `size_bytes`, `media_type`, and `created_at`. Content is raw bytes with `application/octet-stream`, attachment disposition, `nosniff`, and `private, no-store`; `media_type` is not permission to render an upload inline.

## Flutter entry point

Use the existing `WorkbenchApi` instance:

```dart
final revision = api.session.sessionRevision;
final uploaded = await api.files.upload(
  http.MultipartFile.fromBytes('file', bytes, filename: originalName),
);
if (revision != api.session.sessionRevision) return;
// Update only the still-current account's state.
final metadata = await api.files.metadata(uploaded.id);
final Uint8List content = await api.files.download(uploaded.id);
await api.files.delete(uploaded.id);
```

Capture and check `sessionRevision` around each asynchronous operation before updating state, and check widget `mounted` where applicable. The gateway is stateless; it does not own UI scope or persist results. It reuses `WorkbenchApi`'s `ApiClient` and unique `SessionHttpClient`, including token refresh and replay rules. Multipart POST is not replayed automatically; a caller must not blindly retry an uncertain upload.

`FilesGateway` returns generated `StoredFile` metadata, raw `Uint8List` downloads, and existing `ApiFailure` errors. File error codes include `FILE_NOT_FOUND`, `FILE_IN_USE`, `FILE_STORAGE_UNAVAILABLE`, `PAYLOAD_TOO_LARGE`, and `VALIDATION_FAILED`. The generated binary convenience method attempts unsupported `MultipartFile` deserialization; use `api.files.download`, which reads the generated HTTP response's bytes without text decoding. The multipart generator template omits the extra text field that would otherwise duplicate `file`.
