import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/submission.dart';
import '../models/task.dart';
import 'api_exception.dart';

class ApiService {
  ApiService({
    http.Client? client,
    this.baseUrl = "https://courteous-essence-production-c381.up.railway.app",
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  String? _token;

  String? get token => _token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Map<String, String> get authHeaders => Map.unmodifiable(_headers);

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Future<AppUser> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identifier': identifier,
            'password': password,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const ApiException('Koneksi timeout. Coba lagi.'),
        );

    debugPrint('LOGIN STATUS: ${response.statusCode}');
    debugPrint('LOGIN BODY: ${response.body}');

    final data = _decodeObject(response);
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('Login gagal, token tidak ditemukan.');
    }

    setToken(token);
    return currentUser();
  }

  Future<AppUser> currentUser() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/me'),
      headers: _headers,
    );
    return AppUser.fromJson(_decodeObject(response));
  }

  // ── Classes ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchClasses() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/classes'),
      headers: _headers,
    );
    debugPrint('CLASSES STATUS: ${response.statusCode}');
    debugPrint('CLASSES BODY: ${response.body}');
    return _decodeList(response);
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Future<List<Task>> fetchTasks({int? classId}) async {
    final uri = Uri.parse('$baseUrl/tasks').replace(
      queryParameters: {
        if (classId != null) 'class_id': classId.toString(),
      },
    );
    final response = await _client.get(uri, headers: _headers);
    debugPrint('TASKS STATUS: ${response.statusCode}');
    return _decodeList(response).map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> fetchTask(int id) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/tasks/$id'),
      headers: _headers,
    );
    return Task.fromJson(_decodeObject(response));
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required DateTime? deadline,
    required int classId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/tasks'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'deadline': deadline?.toUtc().toIso8601String(),
        'class_id': classId,
      }),
    );
    return Task.fromJson(_decodeObject(response));
  }

  // ── Submissions ───────────────────────────────────────────────────────────

  Future<List<Submission>> fetchSubmissions({int? taskId}) async {
    final uri = Uri.parse('$baseUrl/submissions').replace(
      queryParameters: {
        if (taskId != null) 'task_id': taskId.toString(),
      },
    );
    final response = await _client.get(uri, headers: _headers);
    debugPrint('SUBMISSIONS STATUS: ${response.statusCode}');
    debugPrint('SUBMISSIONS RAW BODY: ${response.body}');

    final submissions = _decodeList(response).map((json) {
      debugPrint('SUBMISSION JSON KEYS: ${json.keys.toList()}');
      return Submission.fromJson(json);
    }).toList();

    debugPrint('PARSED SUBMISSIONS LENGTH: ${submissions.length}');
    return submissions;
  }

  Future<DownloadedSubmissionFile> downloadSubmissionFile(
    Submission submission,
  ) async {
    final downloadUrl = submission.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw const ApiException('This submission has no downloadable file.');
    }

    final uri = _absoluteUri(downloadUrl);
    debugPrint('DOWNLOAD FILE URL: $uri');

    final response = await _client.get(uri, headers: _headers);
    debugPrint('DOWNLOAD FILE STATUS: ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
      throw ApiException('Download failed with status ${response.statusCode}.');
    }

    return DownloadedSubmissionFile(
      bytes: response.bodyBytes,
      fileName: _fileNameFromHeaders(response.headers) ??
          submission.fileName ??
          'submission-${submission.id}',
      contentType: response.headers['content-type'],
    );
  }

  Future<Submission> submitTask({
    required int taskId,
    required PlatformFile file,
  }) async {
    final response = await _sendSubmission(
      path: '/submit',
      taskId: taskId,
      file: file,
    );
    return Submission.fromJson(_decodeObject(response));
  }

  Future<http.Response> _sendSubmission({
    required String path,
    required int taskId,
    required PlatformFile file,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields['task_id'] = taskId.toString();

    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path!,
        filename: file.name,
      ));
    } else {
      throw const ApiException('Selected file is not available.');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    debugPrint('SUBMISSION UPLOAD STATUS: ${response.statusCode}');
    debugPrint('SUBMISSION UPLOAD RESPONSE BODY: ${response.body}');
    return response;
  }

  Future<Submission> gradeSubmission({
    required int submissionId,
    required int grade,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/grade'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'submission_id': submissionId, 'grade': grade}),
    );
    return Submission.fromJson(_decodeObject(response));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _absoluteUri(String pathOrUrl) {
    final parsed = Uri.parse(pathOrUrl);
    if (parsed.hasScheme) return parsed;
    final normalizedPath =
        pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  String? _fileNameFromHeaders(Map<String, String> headers) {
    final disposition = headers['content-disposition'];
    if (disposition == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(disposition);
    return match?.group(1);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final data = _decode(response);
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const ApiException('Unexpected API response.');
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    final data = _decode(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw const ApiException('Unexpected API response.');
  }

  Object? _decode(http.Response response) {
    dynamic body;
    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }
      throw ApiException(
        'Server error (${response.statusCode}). Coba lagi nanti.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic>) {
      final message = body['message'];
      if (message is String && message.isNotEmpty) throw ApiException(message);
      final detail = body['detail'];
      if (detail is String) throw ApiException(detail);
      if (detail != null) throw ApiException(jsonEncode(detail));
    }

    throw ApiException('Request failed with status ${response.statusCode}.');
  }
} // ← penutup class ApiService

class DownloadedSubmissionFile {
  const DownloadedSubmissionFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String? contentType;

  bool get isImage {
    final lowerName = fileName.toLowerCase();
    return lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        (contentType?.startsWith('image/') ?? false);
  }
}