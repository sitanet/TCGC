import 'package:fpdart/fpdart.dart';
import '../models/ask_wing_ai/chat_message_model.dart';
import '../models/ask_wing_ai/ask_wing_ai_response_model.dart';
import '../datasources/ask_wing_ai_remote_datasource.dart';
import '../../core/utils/failure.dart';

/// Abstract interface for Ask Wing AI repository
abstract class AskWingAIRepository {
  /// Submit a question and get the response
  Future<Either<Failure, AskWingAIResponseModel>> submitQuestion(
    String question, {
    List<String>? previousMessageIds,
  });

  /// Get chat history for the current session
  Future<Either<Failure, ChatHistoryModel>> getChatHistory({
    int limit = 50,
    int offset = 0,
  });

  /// Clear the current chat session
  Future<Either<Failure, void>> clearChatHistory();

  /// Get rate limit status
  Future<Either<Failure, RateLimitModel>> getRateLimitStatus();

  /// Check if user can ask more questions
  Future<Either<Failure, bool>> canAskQuestion();
}

/// Implementation of Ask Wing AI repository
class AskWingAIRepositoryImpl implements AskWingAIRepository {
  final AskWingAIRemoteDataSource remoteDataSource;

  AskWingAIRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, AskWingAIResponseModel>> submitQuestion(
    String question, {
    List<String>? previousMessageIds,
  }) async {
    try {
      // Input validation
      if (question.trim().isEmpty) {
        return Left(
          ValidationFailure('Question cannot be empty'),
        );
      }

      if (question.length > 2000) {
        return Left(
          ValidationFailure('Question is too long (max 2000 characters)'),
        );
      }

      final response = await remoteDataSource.submitQuestion(
        question,
        previousMessageIds: previousMessageIds,
      );

      return Right(response);
    } on UnauthorizedException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on RateLimitExceededException catch (e) {
      return Left(RateLimitFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on TimeoutException catch (e) {
      return Left(TimeoutFailure(e.message ?? 'Request timeout'));
    } catch (e) {
      return Left(ServerFailure('Failed to submit question: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ChatHistoryModel>> getChatHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final history = await remoteDataSource.getChatHistory(
        limit: limit,
        offset: offset,
      );

      return Right(history);
    } on UnauthorizedException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on TimeoutException catch (e) {
      return Left(TimeoutFailure(e.message ?? 'Request timeout'));
    } catch (e) {
      return Left(ServerFailure('Failed to retrieve chat history: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> clearChatHistory() async {
    try {
      await remoteDataSource.clearChatHistory();
      return const Right(null);
    } on UnauthorizedException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on TimeoutException catch (e) {
      return Left(TimeoutFailure(e.message ?? 'Request timeout'));
    } catch (e) {
      return Left(ServerFailure('Failed to clear chat history: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, RateLimitModel>> getRateLimitStatus() async {
    try {
      final rateLimit = await remoteDataSource.getRateLimitStatus();
      return Right(rateLimit);
    } on UnauthorizedException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on TimeoutException catch (e) {
      return Left(TimeoutFailure(e.message ?? 'Request timeout'));
    } catch (e) {
      return Left(ServerFailure('Failed to get rate limit: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> canAskQuestion() async {
    try {
      final rateLimit = await remoteDataSource.getRateLimitStatus();
      return Right(rateLimit.dailyRemaining > 0);
    } on UnauthorizedException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on TimeoutException catch (e) {
      return Left(TimeoutFailure(e.message ?? 'Request timeout'));
    } catch (e) {
      return Left(ServerFailure('Failed to check rate limit: ${e.toString()}'));
    }
  }
}
