// ==================== AUTH MODELS ====================
import 'package:flutter/material.dart';

class LoginResponse {
  final String message;
  final int userId;
  final String username;
  final String token;

  LoginResponse.fromJson(Map<String, dynamic> json)
      : message = json['message'],
        userId = json['user_id'],
        username = json['username'],
        token = json['token'];
}

class RegisterResponse {
  final String message;
  final int userId;
  final String username;
  final String email;
  final String token;

  RegisterResponse.fromJson(Map<String, dynamic> json)
      : message = json['message'],
        userId = json['user_id'],
        username = json['username'],
        email = json['email'],
        token = json['token'];
}

// ==================== PASSWORD MODELS ====================

class PasswordEntry {
  final int id;
  final String title;
  final String? username;
  final String? password;
  final String? url;
  final String? tag;
  final int strengthScore;
  final bool riskFlag;
  final DateTime createdAt;

  PasswordEntry({
    required this.id,
    required this.title,
    this.username,
    this.password,
    this.url,
    this.tag,
    required this.strengthScore,
    required this.riskFlag,
    required this.createdAt,
  });

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
        id: json['id'],
        title: json['title'],
        username: json['username'],
        password: json['password'],
        url: json['url'],
        tag: json['tag'],
        strengthScore: json['strength_score'] ?? 0,
        riskFlag: json['risk_flag'] == true,
        createdAt: DateTime.parse(json['created_at']),
      );

  factory PasswordEntry.fromListItem(Map<String, dynamic> json) =>
      PasswordEntry(
        id: json['id'],
        title: json['title'],
        username: null,
        password: null,
        url: null,
        tag: json['tag'],
        strengthScore: json['strength_score'] ?? 0,
        riskFlag: json['risk_flag'] == true,
        createdAt: DateTime.parse(json['created_at']),
      );
}

class PasswordCreateRequest {
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? tag;

  PasswordCreateRequest({
    required this.title,
    required this.username,
    required this.password,
    this.url,
    this.tag,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'tag': tag,
      };
}

class PasswordStrengthResponse {
  final int score;
  final String category;
  final String color;
  final List<String> feedback;

  PasswordStrengthResponse.fromJson(Map<String, dynamic> json)
      : score = json['score'],
        category = json['category'],
        color = json['color'],
        feedback = List<String>.from(json['feedback']);
}

class PasswordGenerateResponse {
  final List<String> suggestions;
  final PasswordStrengthResponse strength;

  PasswordGenerateResponse.fromJson(Map<String, dynamic> json)
      : suggestions = List<String>.from(json['suggestions']),
        strength = PasswordStrengthResponse.fromJson(json['strength']);
}

// ==================== DOCUMENT MODELS ====================

class Document {
  final int id;
  final String fileName;
  final int fileSize;
  final String fileType;
  final String sensitivityScore;
  final String sensitivityColor;
  final String category;
  final DateTime uploadedAt;

  Document({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.sensitivityScore,
    required this.sensitivityColor,
    required this.category,
    required this.uploadedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'],
        fileName: json['file_name'],
        fileSize: json['file_size'],
        fileType: json['file_type'],
        sensitivityScore: json['sensitivity_score'],
        sensitivityColor: json['sensitivity_color'],
        category: json['category'] ?? 'Other',
        uploadedAt: DateTime.parse(json['uploaded_at']),
      );

  String getFormattedFileSize() {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024)
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData getFileIcon() {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audiotrack;
      case 'document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}

class DocumentSensitivityResponse {
  final String sensitivity;
  final String color;
  final String reason;
  final bool requiresConfirmation;

  DocumentSensitivityResponse.fromJson(Map<String, dynamic> json)
      : sensitivity = json['sensitivity'],
        color = json['color'],
        reason = json['reason'],
        requiresConfirmation = json['requires_confirmation'];
}

class DocumentUploadResponse {
  final int id;
  final String fileName;
  final int fileSize;
  final String fileType;
  final String sensitivityScore;
  final String sensitivityColor;
  final String sensitivityReason;
  final String category;
  final String message;

  DocumentUploadResponse.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        fileName = json['file_name'],
        fileSize = json['file_size'],
        fileType = json['file_type'],
        sensitivityScore = json['sensitivity_score'],
        sensitivityColor = json['sensitivity_color'],
        sensitivityReason = json['sensitivity_reason'],
        category = json['category'],
        message = json['message'];
}

// ==================== NOTE MODELS ====================

// ==================== NOTE MODELS ====================

class NoteListItem {
  final int id;
  final String title;
  final String? folder;
  final DateTime updatedAt;
  final DateTime createdAt;

  NoteListItem({
    required this.id,
    required this.title,
    this.folder,
    required this.updatedAt,
    required this.createdAt,
  });

  factory NoteListItem.fromJson(Map<String, dynamic> json) => NoteListItem(
        id: json['id'],
        title: json['title'],
        folder: json['folder'],
        updatedAt: DateTime.parse(json['updated_at']),
        createdAt: DateTime.parse(json['created_at']),
      );

  String getFormattedUpdatedAt() {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inDays > 7) {
      return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

class Note {
  final int id;
  final String title;
  final String content;
  final String? folder;
  final DateTime updatedAt;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.folder,
    required this.updatedAt,
    required this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'] ?? '',
        folder: json['folder'],
        updatedAt: DateTime.parse(json['updated_at']),
        createdAt: DateTime.parse(json['created_at']),
      );
}

// ==================== RISK DASHBOARD MODELS ====================

class WeakPasswordItem {
  final int id;
  final String title;
  final String? tag;
  final int strengthScore;
  final DateTime createdAt;

  WeakPasswordItem({
    required this.id,
    required this.title,
    this.tag,
    required this.strengthScore,
    required this.createdAt,
  });

  factory WeakPasswordItem.fromJson(Map<String, dynamic> json) =>
      WeakPasswordItem(
        id: json['id'],
        title: json['title'],
        tag: json['tag'],
        strengthScore: json['strength_score'],
        createdAt: DateTime.parse(json['created_at']),
      );

  String getStrengthLabel() {
    if (strengthScore >= 90) return 'Very Strong';
    if (strengthScore >= 70) return 'Strong';
    if (strengthScore >= 40) return 'Moderate';
    return 'Weak';
  }

  Color getStrengthColor() {
    if (strengthScore >= 90) return const Color(0xFF00C853);
    if (strengthScore >= 70) return const Color(0xFF22C55E);
    if (strengthScore >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class ReusedPasswordGroup {
  final String passwordHash;
  final List<Map<String, dynamic>> entries;
  final int count;

  ReusedPasswordGroup({
    required this.passwordHash,
    required this.entries,
    required this.count,
  });

  factory ReusedPasswordGroup.fromJson(Map<String, dynamic> json) =>
      ReusedPasswordGroup(
        passwordHash: json['password_hash'],
        entries: List<Map<String, dynamic>>.from(json['entries']),
        count: json['count'],
      );

  List<int> get entryIds => entries.map((e) => e['id'] as int).toList();
  List<String> get entryTitles =>
      entries.map((e) => e['title'] as String).toList();
}

class RiskReport {
  final int healthScore;
  final int totalPasswords;
  final List<WeakPasswordItem> weakPasswords;
  final List<ReusedPasswordGroup> reusedPasswords;
  final int strongPasswordsCount;
  final int moderatePasswordsCount;
  final int weakPasswordsCount;

  RiskReport({
    required this.healthScore,
    required this.totalPasswords,
    required this.weakPasswords,
    required this.reusedPasswords,
    required this.strongPasswordsCount,
    required this.moderatePasswordsCount,
    required this.weakPasswordsCount,
  });

  factory RiskReport.fromJson(Map<String, dynamic> json) => RiskReport(
        healthScore: json['health_score'],
        totalPasswords: json['total_passwords'],
        weakPasswords: (json['weak_passwords'] as List)
            .map((item) => WeakPasswordItem.fromJson(item))
            .toList(),
        reusedPasswords: (json['reused_passwords'] as List)
            .map((item) => ReusedPasswordGroup.fromJson(item))
            .toList(),
        strongPasswordsCount: json['strong_passwords_count'],
        moderatePasswordsCount: json['moderate_passwords_count'],
        weakPasswordsCount: json['weak_passwords_count'],
      );

  bool get hasWeakPasswords => weakPasswords.isNotEmpty;
  bool get hasReusedPasswords => reusedPasswords.isNotEmpty;
  bool get isHealthy => healthScore >= 70;
  bool get isModerate => healthScore >= 40 && healthScore < 70;
  bool get isCritical => healthScore < 40;

  Color getHealthColor() {
    if (healthScore >= 70) return const Color(0xFF22C55E);
    if (healthScore >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String getHealthLabel() {
    if (healthScore >= 90) return 'Excellent';
    if (healthScore >= 70) return 'Good';
    if (healthScore >= 40) return 'Fair';
    return 'Poor';
  }
}

// ==================== SEARCH MODELS ====================

class SearchResultItem {
  final String type; // 'password', 'document', 'note'
  final int id;
  final String title;
  final double relevanceScore;
  final String icon;
  final String? tag;
  final String? category;
  final String? fileType;
  final String? sensitivity;
  final String? folder;

  SearchResultItem({
    required this.type,
    required this.id,
    required this.title,
    required this.relevanceScore,
    required this.icon,
    this.tag,
    this.category,
    this.fileType,
    this.sensitivity,
    this.folder,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      type: json['type'],
      id: json['id'],
      title: json['title'],
      relevanceScore: (json['relevance_score'] as num).toDouble(),
      icon: json['icon'],
      tag: json['tag'],
      category: json['category'],
      fileType: json['file_type'],
      sensitivity: json['sensitivity'],
      folder: json['folder'],
    );
  }

  Color getRelevanceColor() {
    if (relevanceScore >= 80) return const Color(0xFF22C55E);
    if (relevanceScore >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class SearchResponse {
  final String query;
  final List<String> expandedQuery;
  final List<SearchResultItem> results;
  final int total;
  final double tookMs;

  SearchResponse({
    required this.query,
    required this.expandedQuery,
    required this.results,
    required this.total,
    required this.tookMs,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      query: json['query'],
      expandedQuery: List<String>.from(json['expanded_query']),
      results: (json['results'] as List)
          .map((item) => SearchResultItem.fromJson(item))
          .toList(),
      total: json['total'],
      tookMs: (json['took_ms'] as num).toDouble(),
    );
  }

  List<SearchResultItem> get passwords =>
      results.where((r) => r.type == 'password').toList();
  List<SearchResultItem> get documents =>
      results.where((r) => r.type == 'document').toList();
  List<SearchResultItem> get notes =>
      results.where((r) => r.type == 'note').toList();

  bool get hasPasswords => passwords.isNotEmpty;
  bool get hasDocuments => documents.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;
}

// ==================== BACKUP MODELS ====================

class BackupHistoryItem {
  final int id;
  final String backupFilePath;
  final int fileSize;
  final DateTime createdAt;

  BackupHistoryItem({
    required this.id,
    required this.backupFilePath,
    required this.fileSize,
    required this.createdAt,
  });

  factory BackupHistoryItem.fromJson(Map<String, dynamic> json) =>
      BackupHistoryItem(
        id: json['id'],
        backupFilePath: json['backup_file_path'],
        fileSize: json['file_size'],
        createdAt: DateTime.parse(json['created_at']),
      );

  String getFormattedFileSize() {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String getFormattedDate() {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

class BackupExportResponse {
  final String message;
  final String filePath;
  final int fileSize;
  final DateTime createdAt;
  final Map<String, int> includes;

  BackupExportResponse.fromJson(Map<String, dynamic> json)
      : message = json['message'],
        filePath = json['file_path'],
        fileSize = json['file_size'],
        createdAt = DateTime.parse(json['created_at']),
        includes = Map<String, int>.from(json['includes']);
}

class BackupRestoreResponse {
  final String message;
  final Map<String, int> restored;
  final String mode;

  BackupRestoreResponse.fromJson(Map<String, dynamic> json)
      : message = json['message'],
        restored = Map<String, int>.from(json['restored']),
        mode = json['mode'];
}

class BackupVerifyResponse {
  final bool valid;
  final String? version;
  final DateTime? exportedAt;
  final Map<String, int>? contains;
  final String? error;

  BackupVerifyResponse.fromJson(Map<String, dynamic> json)
      : valid = json['valid'],
        version = json['version'],
        exportedAt = json['exported_at'] != null
            ? DateTime.parse(json['exported_at'])
            : null,
        contains = json['contains'] != null
            ? Map<String, int>.from(json['contains'])
            : null,
        error = json['error'];
}
