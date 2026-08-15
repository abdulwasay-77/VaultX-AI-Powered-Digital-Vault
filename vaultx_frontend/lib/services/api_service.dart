import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static void _ensureInitialized() {
    if (_prefs == null) {
      throw Exception(
          'ApiService not initialized. Call ApiService.init() first.');
    }
  }

  Future<String?> getToken() async {
    _ensureInitialized();
    return _prefs!.getString('jwt_token');
  }

  Future<void> saveToken(String token) async {
    _ensureInitialized();
    await _prefs!.setString('jwt_token', token);
  }

  Future<void> clearToken() async {
    _ensureInitialized();
    await _prefs!.remove('jwt_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final String? token = await getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ==================== AUTH ====================

  Future<LoginResponse> login(String email, String masterPassword) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'email': email,
              'master_password': masterPassword
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isEmpty) {
        throw Exception(
            'Server returned empty response. Make sure backend is running on port 8000');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        await saveToken(data['token'] as String);
        return LoginResponse.fromJson(data);
      } else {
        throw Exception('Invalid email or password');
      }
    } catch (e) {
      throw Exception('Connection failed: ${e.toString()}');
    }
  }

  Future<LoginResponse> loginWithPin(String email, String pin) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$baseUrl/auth/login-pin'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{'email': email, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isEmpty) {
        throw Exception(
            'Server returned empty response. Make sure backend is running on port 8000');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        await saveToken(data['token'] as String);
        return LoginResponse.fromJson(data);
      } else {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'PIN login failed');
      }
    } catch (e) {
      throw Exception('Connection failed: ${e.toString()}');
    }
  }

  Future<RegisterResponse> register(
      String masterPassword, String username, String email,
      {String? pin}) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'master_password': masterPassword,
        'username': username,
        'email': email,
      };
      if (pin != null) {
        body['pin'] = pin;
      }

      final http.Response response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isEmpty) {
        throw Exception(
            'Server returned empty response. Make sure backend is running on port 8000');
      }

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        await saveToken(data['token'] as String);
        return RegisterResponse.fromJson(data);
      } else {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Connection failed: ${e.toString()}');
    }
  }

  // ==================== SETTINGS ====================

  Future<Map<String, dynamic>> getAccountInfo() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$baseUrl/auth/me'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to load account info');
      }
    } catch (e) {
      throw Exception('Connection failed: ${e.toString()}');
    }
  }

  Future<void> changeMasterPassword(
      String currentPassword, String newPassword) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$baseUrl/auth/change-password'),
            headers: await _getHeaders(),
            body: jsonEncode(<String, String>{
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to change password');
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> setOrChangePin(String masterPassword, String newPin) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$baseUrl/auth/pin'),
            headers: await _getHeaders(),
            body: jsonEncode(<String, String>{
              'master_password': masterPassword,
              'new_pin': newPin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to update PIN');
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ==================== PASSWORDS ====================

  Future<List<PasswordEntry>> getPasswords() async {
    try {
      final Map<String, String> headers = await _getHeaders();
      final http.Response response = await http
          .get(
            Uri.parse('$baseUrl/passwords'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((dynamic e) =>
                PasswordEntry.fromListItem(e as Map<String, dynamic>))
            .toList();
      }
      return <PasswordEntry>[];
    } catch (e) {
      return <PasswordEntry>[];
    }
  }

  Future<PasswordEntry> getPasswordById(int id) async {
    final Map<String, String> headers = await _getHeaders();
    final http.Response response = await http
        .get(
          Uri.parse('$baseUrl/passwords/$id'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return PasswordEntry.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception('Failed to load password details');
    }
  }

  Future<void> createPassword(PasswordCreateRequest request) async {
    final Map<String, String> headers = await _getHeaders();
    final http.Response response = await http.post(
      Uri.parse('$baseUrl/passwords'),
      headers: headers,
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create password');
    }
  }

  Future<void> updatePassword(int id, Map<String, dynamic> updates) async {
    final Map<String, String> headers = await _getHeaders();
    final http.Response response = await http.put(
      Uri.parse('$baseUrl/passwords/$id'),
      headers: headers,
      body: jsonEncode(updates),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update password');
    }
  }

  Future<void> deletePassword(int id) async {
    final Map<String, String> headers = await _getHeaders();
    final http.Response response = await http.delete(
      Uri.parse('$baseUrl/passwords/$id'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete password');
    }
  }

  // ==================== IRBE ====================

  Future<PasswordStrengthResponse> checkPasswordStrength(
      String password) async {
    final http.Response response = await http.post(
      Uri.parse('$baseUrl/irbe/password-strength'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{'password': password}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return PasswordStrengthResponse.fromJson(data);
    }
    throw Exception('Failed to check password strength');
  }

  Future<PasswordGenerateResponse> generatePassword() async {
    final http.Response response = await http.post(
      Uri.parse('$baseUrl/irbe/password-generate'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'length': 16,
        'use_uppercase': true,
        'use_lowercase': true,
        'use_numbers': true,
        'use_symbols': true,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return PasswordGenerateResponse.fromJson(data);
    }
    throw Exception('Failed to generate password');
  }

  // ==================== DOCUMENTS ====================

  Future<DocumentSensitivityResponse> analyzeFileSensitivity(
      String fileName) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/irbe/file-sensitivity'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'file_name': fileName}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return DocumentSensitivityResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to analyze file sensitivity');
  }

  Future<DocumentUploadResponse> uploadDocument({
    required String filePath,
    required String category,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/documents/upload'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['category'] = category;
    request.fields['delete_original'] = 'true';

    final streamedResponse = await request.send().timeout(
          const Duration(minutes: 10),
        );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return DocumentUploadResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 413) {
      throw Exception('File too large. Maximum size is 500 MB.');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Upload failed');
    }
  }

  Future<List<Document>> getDocuments() async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/documents'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Document.fromJson(json)).toList();
    }
    return [];
  }

  Future<Document> getDocumentMetadata(int documentId) async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/documents/$documentId'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return Document.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load document metadata');
  }

  Future<Uint8List> previewDocument(int documentId) async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/documents/$documentId/preview'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to preview document');
  }

  Future<void> downloadDocument(int documentId, String savePath) async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/documents/$documentId/download'),
          headers: headers,
        )
        .timeout(const Duration(minutes: 10));

    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download document');
    }
  }

  Future<void> deleteDocument(int documentId) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(
          Uri.parse('$baseUrl/documents/$documentId'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete document');
    }
  }

  // ==================== NOTES ====================

  Future<List<NoteListItem>> getNotes({String? folder}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/notes';
    if (folder != null && folder.isNotEmpty) {
      url += '?folder=$folder';
    }

    final response = await http
        .get(
          Uri.parse(url),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => NoteListItem.fromJson(json)).toList();
    }
    return [];
  }

  Future<Note> getNote(int id) async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/notes/$id'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return Note.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load note');
  }

  Future<Note> createNote(String title, String content,
      {String? folder}) async {
    final headers = await _getHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/notes'),
          headers: headers,
          body: jsonEncode({
            'title': title,
            'content': content,
            'folder': folder,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create note');
    }
    return Note.fromJson(jsonDecode(response.body));
  }

  Future<void> updateNote(int id,
      {String? title, String? content, String? folder}) async {
    final headers = await _getHeaders();
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (folder != null) body['folder'] = folder;

    final response = await http
        .put(
          Uri.parse('$baseUrl/notes/$id'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to update note');
    }
  }

  Future<void> deleteNote(int id) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(
          Uri.parse('$baseUrl/notes/$id'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete note');
    }
  }

  // ==================== FOLDERS ====================

  Future<List<String>> getFolders() async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/notes/folders/all'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Backend returns: {"folders": [{"id":1,"name":"X","created_at":"..."}]}
      if (data is Map && data.containsKey('folders')) {
        final foldersList = data['folders'];
        if (foldersList is List) {
          return foldersList
              .map((item) {
                // Handle object format {"id":1,"name":"X"} or plain string
                if (item is Map) {
                  return item['name']?.toString() ?? '';
                }
                return item.toString();
              })
              .where((name) => name.isNotEmpty)
              .toList();
        }
      }

      // Fallback: plain list of strings
      if (data is List) {
        return data
            .map((item) {
              if (item is Map) return item['name']?.toString() ?? '';
              return item.toString();
            })
            .where((name) => name.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  Future<void> createFolder(String folderName) async {
    final headers = await _getHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/notes/folders'),
          headers: headers,
          body: jsonEncode({'name': folderName}),
        )
        .timeout(const Duration(seconds: 10));

    // Backend returns 201 Created on success
    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMsg = 'Failed to create folder';
      try {
        final error = jsonDecode(response.body);
        errorMsg = error['detail'] ?? errorMsg;
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<void> moveNoteToFolder(int id, String folder) async {
    final headers = await _getHeaders();
    final response = await http
        .put(
          Uri.parse('$baseUrl/notes/$id/folder'),
          headers: headers,
          body: jsonEncode({'folder': folder}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to move note');
    }
  }

  Future<void> deleteFolder(String folderName, {String? moveTo}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/notes/folders/$folderName';
    if (moveTo != null) {
      url += '?move_to=$moveTo';
    }

    final response = await http
        .delete(
          Uri.parse(url),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete folder');
    }
  }

  // ==================== RISK DASHBOARD ====================

  Future<RiskReport> getRiskReport() async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/irbe/risk-report'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return RiskReport.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception('Failed to load risk report');
    }
  }

  // ==================== SMART SEARCH ====================

  Future<SearchResponse> search(String query, {int limit = 30}) async {
    if (query.isEmpty || query.trim().isEmpty) {
      return SearchResponse(
        query: query,
        expandedQuery: [],
        results: [],
        total: 0,
        tookMs: 0,
      );
    }

    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse(
              '$baseUrl/search?q=${Uri.encodeComponent(query)}&limit=$limit'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return SearchResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception('Failed to search');
    }
  }

  Future<List<String>> getSearchSuggestions(String query,
      {int limit = 10}) async {
    if (query.isEmpty || query.trim().length < 2) {
      return [];
    }

    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse(
              '$baseUrl/search/suggestions?q=${Uri.encodeComponent(query)}&limit=$limit'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['suggestions']);
    }
    return [];
  }

  // ==================== BACKUP METHODS ====================

  Future<BackupExportResponse> exportBackup() async {
    final headers = await _getHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/backup/export'),
          headers: headers,
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      return BackupExportResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception('Failed to export backup');
    }
  }

  Future<BackupRestoreResponse> restoreBackup({
    required String backupFilePath,
    required String masterPassword,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/backup/restore'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['backup_file_path'] = backupFilePath;
    request.fields['master_password'] = masterPassword;

    final streamedResponse = await request.send().timeout(
          const Duration(minutes: 10),
        );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return BackupRestoreResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Invalid master password');
    } else if (response.statusCode == 403) {
      throw Exception('Backup belongs to a different user');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Restore failed');
    }
  }

  Future<List<BackupHistoryItem>> getBackupHistory() async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/backup/history'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BackupHistoryItem.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> deleteBackupRecord(int backupId,
      {bool deleteFile = true}) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(
          Uri.parse(
              '$baseUrl/backup/history/$backupId?delete_file=$deleteFile'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete backup record');
    }
  }

  Future<void> downloadBackupFile(int backupId, String savePath) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/backup/download/$backupId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download backup file');
    }
  }

  Future<BackupVerifyResponse> verifyBackup({
    required String backupFilePath,
    required String masterPassword,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/backup/verify'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['backup_file_path'] = backupFilePath;
    request.fields['master_password'] = masterPassword;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return BackupVerifyResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to verify backup');
    }
  }
}

final ApiService apiService = ApiService();
