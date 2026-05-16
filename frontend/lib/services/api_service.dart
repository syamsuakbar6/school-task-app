import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
          onTimeout: () =>
              throw const ApiException('Koneksi timeout. Coba lagi.'),
        );

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

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/me/password'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 204) {
      _decode(response);
    }
  }

  Future<List<Map<String, dynamic>>> fetchClasses({
    bool includeHistory = false,
    int? academicYearId,
  }) async {
    final uri = Uri.parse('$baseUrl/classes').replace(
      queryParameters: {
        if (includeHistory) 'include_history': 'true',
        if (academicYearId != null)
          'academic_year_id': academicYearId.toString(),
      },
    );
    final response = await _client.get(
      uri,
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<List<Map<String, dynamic>>> fetchAccessibleAcademicYears() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/classes/academic-years'),
      headers: _headers,
    );
    return _decodeList(response);
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Future<List<Task>> fetchTasks({
    int? classId,
    int? academicYearId,
    bool? mineOnly,
  }) async {
    final uri = Uri.parse('$baseUrl/tasks').replace(
      queryParameters: {
        if (classId != null) 'class_id': classId.toString(),
        if (academicYearId != null)
          'academic_year_id': academicYearId.toString(),
        if (mineOnly != null) 'mine_only': mineOnly.toString(),
      },
    );
    final response = await _client.get(uri, headers: _headers);
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

  Future<List<Submission>> fetchSubmissions({
    int? taskId,
    int? academicYearId,
  }) async {
    final uri = Uri.parse('$baseUrl/submissions').replace(
      queryParameters: {
        if (taskId != null) 'task_id': taskId.toString(),
        if (academicYearId != null)
          'academic_year_id': academicYearId.toString(),
      },
    );
    final response = await _client.get(uri, headers: _headers);
    return _decodeList(response)
        .map((json) => Submission.fromJson(json))
        .toList();
  }

  Future<DownloadedSubmissionFile> downloadSubmissionFile(
    Submission submission,
  ) async {
    final downloadUrl = submission.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw const ApiException('Pengumpulan ini tidak memiliki file.');
    }

    final uri = _absoluteUri(downloadUrl);

    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
      throw ApiException('Unduhan gagal (${response.statusCode}).');
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
      throw const ApiException('File yang dipilih tidak tersedia.');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return response;
  }

  Future<Submission> gradeSubmission({
    required int submissionId,
    required int grade,
    String? feedback,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/grade'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'submission_id': submissionId,
        'grade': grade,
        if (feedback != null && feedback.trim().isNotEmpty)
          'feedback': feedback.trim(),
      }),
    );
    return Submission.fromJson(_decodeObject(response));
  }

  Future<List<Map<String, dynamic>>> adminListUsers() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<List<Map<String, dynamic>>> adminListStudents() async {
    final users = await adminListUsers();
    return users.where((u) => u['role'] == 'student').toList();
  }

  Future<List<Map<String, dynamic>>> adminListTeachers() async {
    final users = await adminListUsers();
    return users.where((u) => u['role'] == 'teacher').toList();
  }

  Future<List<Map<String, dynamic>>> adminListAcademicYears() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/admin/academic-years'),
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> adminCreateAcademicYear({
    required String name,
    String? startsAt,
    String? endsAt,
    bool isActive = false,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/academic-years'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        if (startsAt != null && startsAt.trim().isNotEmpty)
          'starts_at': startsAt.trim(),
        if (endsAt != null && endsAt.trim().isNotEmpty)
          'ends_at': endsAt.trim(),
        'is_active': isActive,
      }),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminActivateAcademicYear(int yearId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/academic-years/$yearId/activate'),
      headers: _headers,
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminPreviewPromotion({
    required int sourceAcademicYearId,
    required int targetAcademicYearId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/promotions/preview'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'source_academic_year_id': sourceAcademicYearId,
        'target_academic_year_id': targetAcademicYearId,
      }),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminCommitPromotion({
    required int sourceAcademicYearId,
    required int targetAcademicYearId,
    required List<int> notPromotedStudentIds,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/promotions/commit'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'source_academic_year_id': sourceAcademicYearId,
        'target_academic_year_id': targetAcademicYearId,
        'not_promoted_student_ids': notPromotedStudentIds,
      }),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminCreateTeacher({
    required String nip,
    required String name,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/teachers'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'nip': nip, 'name': name}),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminCreateStudent({
    required String nisn,
    required String name,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/students'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'nisn': nisn, 'name': name}),
    );
    return _decodeObject(response);
  }

  Future<void> adminDeleteUser(int userId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/admin/users/$userId'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      _decode(response);
    }
  }

  Future<List<Map<String, dynamic>>> adminListClasses({
    bool includeArchived = false,
    int? academicYearId,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/classes').replace(
      queryParameters: {
        if (includeArchived) 'include_archived': 'true',
        if (academicYearId != null)
          'academic_year_id': academicYearId.toString(),
      },
    );
    final response = await _client.get(
      uri,
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> adminCreateClass({
    required String name,
    required String code,
    String? gradeLevel,
    String? major,
    String? section,
    int? academicYearId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/classes'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'code': code,
        if (gradeLevel != null) 'grade_level': gradeLevel,
        if (major != null) 'major': major,
        if (section != null) 'section': section,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      }),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminUpdateClass({
    required int classId,
    String? name,
    String? code,
    String? gradeLevel,
    String? major,
    String? section,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/admin/classes/$classId'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (name != null) 'name': name,
        if (code != null) 'code': code,
        if (gradeLevel != null) 'grade_level': gradeLevel,
        if (major != null) 'major': major,
        if (section != null) 'section': section,
      }),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminArchiveClass(int classId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/classes/$classId/archive'),
      headers: _headers,
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminUnarchiveClass(int classId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/classes/$classId/unarchive'),
      headers: _headers,
    );
    return _decodeObject(response);
  }

  Future<void> adminDeleteClass(int classId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/admin/classes/$classId'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      _decode(response);
    }
  }

  Future<void> adminAssignStudentToClass({
    required int classId,
    required int studentId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/classes/$classId/students/$studentId'),
      headers: _headers,
    );
    _decodeObject(response);
  }

  Future<Map<String, dynamic>> adminImportStudentsToClass({
    required int classId,
    required PlatformFile file,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/classes/$classId/students/import');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);

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
      throw const ApiException('File Excel tidak bisa dibaca.');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decodeObject(response);
  }

  Future<void> adminRemoveStudentFromClass({
    required int classId,
    required int studentId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/admin/classes/$classId/students/$studentId'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      _decode(response);
    }
  }

  Future<List<Map<String, dynamic>>> adminListClassTeachers(int classId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/admin/classes/$classId/teachers'),
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<void> adminAssignTeacherToClass({
    required int classId,
    required int teacherId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/classes/$classId/teachers/$teacherId'),
      headers: _headers,
    );
    _decodeObject(response);
  }

  Future<void> adminRemoveTeacherFromClass({
    required int classId,
    required int teacherId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/admin/classes/$classId/teachers/$teacherId'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      _decode(response);
    }
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
    throw const ApiException('Respons server tidak sesuai.');
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    final data = _decode(response);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    throw const ApiException('Respons server tidak sesuai.');
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
        'Kesalahan server (${response.statusCode}). Coba lagi nanti.',
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

    throw ApiException('Permintaan gagal (${response.statusCode}).');
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
