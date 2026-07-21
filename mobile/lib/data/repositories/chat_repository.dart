import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../models/chat_model.dart';
import '../sources/api_client.dart';
import '../sources/mock_data.dart';

class ChatSessionState {
  const ChatSessionState({required this.sessionId, required this.messages});

  final int sessionId;
  final List<ChatMessage> messages;
}

class ChatStreamEvent {
  const ChatStreamEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;
}

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<ChatSessionState> start({
    required int caseId,
    int? assignmentInstanceId,
  }) async {
    if (AppConfig.mockEnabled) {
      return ChatSessionState(
        sessionId: 1,
        messages: MockData.chatMessages.toList(),
      );
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/student/sessions',
        data: <String, dynamic>{
          'caseId': caseId,
          if (assignmentInstanceId != null)
            'assignmentInstanceId': assignmentInstanceId,
        },
      );
      final Map<String, dynamic> data = unwrapEnvelope(response.data);
      return ChatSessionState(
        sessionId: (data['sessionId'] as num).toInt(),
        messages: const <ChatMessage>[],
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<ChatSessionState> load(int sessionId) async {
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('/api/v1/student/sessions/$sessionId');
      final Map<String, dynamic> data = unwrapEnvelope(response.data);
      final List<dynamic> rows = data['messages'] is List
          ? List<dynamic>.from(data['messages'] as List)
          : const <dynamic>[];
      return ChatSessionState(
        sessionId: sessionId,
        messages: rows.whereType<Map>().map((Map row) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(row);
          return ChatMessage(
            by: item['sender']?.toString().toLowerCase() ?? 'system',
            text: item['content']?.toString() ?? '',
            timestamp: DateTime.tryParse(item['createdAt']?.toString() ?? ''),
          );
        }).toList(),
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> finish(int sessionId) async {
    if (AppConfig.mockEnabled) return;
    try {
      await _dio.post<dynamic>('/api/v1/student/sessions/$sessionId/finish');
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Stream<ChatStreamEvent> send({
    required int caseId,
    required int sessionId,
    required List<ChatMessage> messages,
  }) async* {
    if (AppConfig.mockEnabled) {
      yield const ChatStreamEvent(
        'message',
        <String, dynamic>{'delta': '好的，我尽量回答。具体是哪方面的问题？'},
      );
      yield const ChatStreamEvent(
        'done',
        <String, dynamic>{'session_id': 1},
      );
      return;
    }
    try {
      final Response<ResponseBody> response = await _dio.post<ResponseBody>(
        '${AppConfig.aiBaseUrl}/v1/ai/chat/stream',
        data: <String, dynamic>{
          'case_id': caseId,
          'session_id': sessionId,
          'messages': messages
              .map((ChatMessage message) => <String, dynamic>{
                    'role': message.by,
                    'content': message.text,
                  })
              .toList(),
        },
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 2),
          headers: const <String, String>{'Accept': 'text/event-stream'},
        ),
      );
      String event = 'message';
      final List<String> dataLines = <String>[];
      await for (final String line in response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (dataLines.isNotEmpty) {
            final dynamic decoded = jsonDecode(dataLines.join('\n'));
            yield ChatStreamEvent(
              event,
              decoded is Map
                  ? Map<String, dynamic>.from(decoded)
                  : <String, dynamic>{'value': decoded},
            );
          }
          event = 'message';
          dataLines.clear();
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }
    } catch (error) {
      throw mapDioException(error);
    }
  }
}

final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));
