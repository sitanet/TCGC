# Implementation Plan: Ask Wing AI

## Overview

Ask Wing AI is an AI-powered Q&A system for sermon content. This implementation plan breaks down the feature into logical phases: infrastructure setup, backend services, frontend UI, integration, and comprehensive testing. Tasks build incrementally, with infrastructure and backend services established first, followed by frontend integration and verification.

**Key Implementation Approach:**
- Backend-first development (services, API, database)
- Infrastructure setup with PostgreSQL pgvector extension
- Frontend UI implementation with state management
- Integration testing and performance validation
- Moderation and monitoring tools

---

## Tasks

### Phase 1: Infrastructure and Database Setup

- [x] 1.1 Set up PostgreSQL with pgvector extension
  - Install PostgreSQL 14+ and pgvector extension
  - Create database schema with vector index support
  - Set up connection pooling for production
  - _Requirements: 5.6, 20.6_

- [x] 1.2 Create core database models
  - Implement SermonEmbedding model with vector field
  - Implement AskWingAIQuestion model for moderation logging
  - Implement ChatSession and ChatMessage models
  - Implement Citation model for response tracking
  - Add transcription fields to Message model (transcript, transcription_status, transcription_error, transcription_retry_count, transcription_completed_at)
  - Add indexing status fields to Message model (indexing_status, indexed_at)
  - Add database indexes for performance (pgvector IVFFlat)
  - _Requirements: 5.3, 10.1, 10.2, 21.1, 21.2, 25.9_

- [x] 1.3 Configure Django models with relationships
  - Add foreign keys linking chat sessions to users
  - Add foreign keys linking messages to sermons and speakers
  - Configure cascade deletion and related names
  - Create database migrations
  - _Requirements: 9.1, 9.2, 21.3, 21.4_

- [x] 1.4 Set up environment variables and secrets management
  - Create .env template with all required secrets
  - Configure Django settings to read from environment
  - Set up AWS Secrets Manager (or equivalent) for production
  - Document all environment variables required
  - _Requirements: 13.1, 13.2, 13.5_

---

### Phase 2: Backend Authentication and Authorization

- [x] 2.1 Implement JWT authentication middleware
  - Add JWT verification to all Ask Wing AI endpoints
  - Create custom permission classes for authentication checks
  - Implement token validation and expiration handling
  - Add authentication error responses
  - _Requirements: 2.1, 2.2, 2.3, 2.5_

- [x] 2.2 Create authentication token refresh mechanism
  - Implement token refresh endpoint
  - Set token expiration times (24-hour default)
  - Handle expired token scenarios during chat sessions
  - Display re-authentication prompts to users
  - _Requirements: 2.4, 18.3, 18.4_

- [x] 2.3 Implement IsOwnerOrAdmin permission checks
  - Restrict users to accessing only their own chat history
  - Allow admin access to all moderation records
  - Validate user ownership in list and detail views
  - _Requirements: 2.5, 19.6_

---

### Phase 3: Backend Rate Limiting and Security

- [x] 3.1 Implement rate limiting service
  - Create RateLimiterService for daily question quotas
  - Track question counts per user ID
  - Implement daily reset mechanism (configurable timezone)
  - Store rate limit state in Redis or cache backend
  - _Requirements: 11.1, 11.3, 11.6, 11.7_

- [x] 3.2 Create rate limiting middleware and views
  - Add rate limit checks to question submission endpoint
  - Return remaining question count in responses
  - Display rate limit status in chat interface
  - Handle rate limit exceeded scenarios gracefully
  - _Requirements: 11.2, 11.4, 11.5_

- [x] 3.3 Implement data sanitization service
  - Create DataSanitizationService with PII detection patterns
  - Detect and mask emails, phone numbers, names, account numbers
  - Sanitize questions before sending to OpenAI
  - Store both original (local) and sanitized (external) versions
  - _Requirements: 14.1, 14.2, 14.3, 14.5_

- [x] 3.4 Implement input validation and security checks
  - Create QuestionSubmissionSerializer with validation rules
  - Prevent SQL injection, XSS, and other attacks
  - Validate question length, format, and content
  - Add CSRF protection to POST endpoints
  - _Requirements: 4.4, 4.5, 13.3, 13.6_

- [x] 3.5 Set up HTTPS/TLS encryption configuration
  - Enable SSL redirect in Django settings
  - Configure secure cookies and CSRF protection
  - Add security headers (CSP, X-Frame-Options, etc.)
  - Document certificate requirements for production
  - _Requirements: 13.2, 13.3_

---

### Phase 4: Backend Embedding and Vector Search Services

- [x] 4.0 Implement audio transcription service
  - Create AudioTranscriptionService for OpenAI Whisper API integration
  - Implement async transcription task with Celery
  - Handle audio file download from storage (S3/local)
  - Store transcripts in Message.transcript field
  - Add error handling and retry logic for failed transcriptions
  - Automatically trigger embedding indexing after transcription completes
  - _Requirements: Audio must be transcribed when uploaded_

- [x] 4.1 Implement embedding generation service
  - Create EmbeddingService for OpenAI API integration
  - Implement text-embedding-3-small model calls
  - Add error handling and retry logic for API failures
  - Cache embeddings to reduce API calls
  - _Requirements: 5.1, 5.6, 20.1_

- [x] 4.2 Implement transcript chunking logic
  - Create chunk_transcript() method with configurable sizes
  - Implement overlapping chunks for better context
  - Add chunk position tracking for timestamp calculation
  - Test chunking with various transcript lengths
  - _Requirements: 5.2, 20.2_

- [x] 4.3 Implement vector search service
  - Create VectorSearchService with semantic similarity search
  - Implement pgvector cosine similarity queries
  - Return top-K results with metadata and similarity scores
  - Filter by minimum similarity threshold
  - _Requirements: 5.2, 5.3, 5.4, 5.5_

- [x] 4.4 Implement timestamp calculation from chunks
  - Create algorithm to estimate timestamps from text position
  - Validate timestamps against sermon duration
  - Handle cases where exact position unavailable
  - Format timestamps as MM:SS
  - _Requirements: 7.1, 7.2, 7.4, 7.5_

---

### Phase 5: Backend Sermon Transcription and Indexing (Celery Tasks)

- [x] 5.1 Set up Celery task queue
  - Configure Celery with Redis or RabbitMQ
  - Create async task base configuration
  - Set up task result backend for monitoring
  - Implement task retry logic with exponential backoff
  - _Requirements: 20.4, 20.5, 25.4_

- [x] 5.2 Implement TranscriptionService with OpenAI Whisper
  - Create TranscriptionService for audio-to-text conversion
  - Integrate with OpenAI Whisper API
  - Implement audio file chunking for files > 25MB
  - Handle transcription with proper error handling
  - Store transcripts in Message/Sermon record
  - _Requirements: 25.1, 25.2, 25.3, 25.5_

- [x] 5.3 Implement transcription status tracking model fields
  - Add transcription_status field to Message model (pending, processing, completed, failed)
  - Add transcription_error field for error logging
  - Add transcription_retry_count field for retry tracking
  - Add transcription_completed_at timestamp field
  - _Requirements: 25.9_

- [x] 5.4 Implement transcription Celery task
  - Create transcribe_sermon_audio() async task
  - Queue task automatically on sermon audio upload
  - Update sermon transcription_status during processing
  - Implement retry logic (up to 3 attempts with exponential backoff)
  - Automatically queue embedding indexing after successful transcription
  - _Requirements: 25.4, 25.6, 25.8_

- [x] 5.5 Implement partial transcription handling
  - Handle cases where transcription partially succeeds (some chunks fail)
  - Store available transcript with warning flag
  - Log partial failure details for admin review
  - Queue retry for failed chunks
  - _Requirements: 25.7_

- [x] 5.6 Implement sermon upload status endpoint
  - Create GET /api/admin/sermons/{id}/transcription-status endpoint
  - Return transcription_status, progress, and completed_at timestamp
  - Display transcript length and error messages
  - Restrict access to admin users
  - _Requirements: 25.10_

- [x] 5.7 Implement sermon transcription integration with upload flow
  - Modify sermon upload serializer to accept audio files
  - Automatically trigger transcribe_sermon_audio task on upload
  - Update UI to show transcription progress
  - Handle upload and transcription status together
  - _Requirements: 25.1, 25.4_

- [x] 5.8 Implement sermon indexing Celery task
  - Create index_sermon_embeddings() async task
  - Generate embeddings for sermon transcripts using EmbeddingService
  - Store embeddings in SermonEmbedding table with chunks
  - Handle large transcripts by splitting into chunks
  - _Requirements: 20.1, 20.2, 20.6_

- [x] 5.9 Implement sermon metadata update handling
  - Update embeddings when sermon metadata changes (title, speaker)
  - Handle sermon deletion with cascade cleanup of embeddings
  - Log indexing errors and track failed sermons
  - Implement recovery mechanism for failed indexing
  - _Requirements: 20.3, 20.5, 20.7_

---

### Phase 5.10: Long Audio File Handling Enhancement

- [x] 5.10.1 Implement proper audio chunking for large files
  - Enhance `_split_audio_into_chunks()` method to use ffmpeg for actual file splitting
  - Implement time-based chunking (10-minute segments) for files > 25MB
  - Add audio format detection and conversion if needed
  - Handle chunk file cleanup after successful transcription
  - _Requirements: Handle 3-hour audio files that exceed OpenAI Whisper 25MB limit_

- [x] 5.10.2 Add ffmpeg dependency and configuration
  - Install ffmpeg system dependency on production server
  - Add FFMPEG_PATH configuration to Django settings
  - Implement ffmpeg availability check with graceful fallback
  - Add audio duration detection using ffprobe
  - _Requirements: System must have ffmpeg installed for audio processing_

- [x] 5.10.3 Enhance chunk processing with timestamp tracking
  - Add start_time and end_time metadata to each chunk
  - Implement proper transcript reassembly with timestamp preservation
  - Handle overlapping chunks to prevent loss of content at boundaries
  - Add chunk validation to ensure no gaps in audio coverage
  - _Requirements: Maintain audio content integrity across chunk boundaries_

- [x] 5.10.4 Implement intelligent chunk size optimization
  - Calculate optimal chunk duration based on file size and estimated bitrate
  - Implement adaptive chunking that avoids cutting mid-sentence
  - Add silence detection to chunk at natural speaking breaks
  - Optimize chunk size to maximize transcription accuracy
  - _Requirements: Improve transcription quality by chunking at optimal points_

- [x] 5.10.5 Add comprehensive error handling for large files
  - Handle ffmpeg errors gracefully with detailed logging
  - Implement chunk-level retry with exponential backoff
  - Add disk space validation before chunking large files
  - Implement timeout handling for very large file processing
  - _Requirements: Robust error handling for 3-hour+ audio files_

- [x] 5.10.6 Add progress tracking for long transcriptions
  - Implement transcription progress percentage calculation
  - Add progress updates for dashboard/admin interface
  - Track processing time per chunk for performance monitoring
  - Add estimated completion time calculation
  - _Requirements: Admin visibility into long-running transcription progress_

---

### Phase 6: Backend Response Generation (GPT-4 Integration)

- [x] 6.1 Implement response generator service
  - Create ResponseGeneratorService with GPT-4 integration
  - Implement system prompt with citation requirements
  - Build context from retrieved sermon chunks
  - Format conversation history for follow-ups
  - _Requirements: 6.1, 6.2, 6.6_

- [x] 6.2 Implement citation extraction and formatting
  - Extract sermon metadata from search results
  - Format citations as "[Sermon Title] by [Speaker] at [timestamp]"
  - Validate timestamps against sermon duration
  - Build citation block for response end
  - _Requirements: 6.1, 6.3, 6.7, 7.1, 7.2, 7.3_

- [x] 6.3 Implement markdown response formatting
  - Support markdown formatting in responses (bold, italics, lists)
  - Ensure proper formatting for citations block
  - Test markdown rendering in Flutter UI
  - Add fallback for unsupported markdown features
  - _Requirements: 8.1, 8.2, 8.3, 8.5_

- [x] 6.4 Implement conversational context handling
  - Load previous messages from ChatSession
  - Include context in GPT-4 system prompt
  - Resolve pronouns using conversation history
  - Implement context summarization for long conversations
  - _Requirements: 17.1, 17.2, 17.3, 17.4_

---

### Phase 7: Backend API Endpoints

- [x] 7.1 Create question submission endpoint
  - Implement POST /api/ask-wing-ai/questions
  - Accept question and previous message IDs
  - Return 202 Accepted with processing status
  - Implement async response handling (polling or WebSocket)
  - _Requirements: 18.1, 18.2, 18.3_

- [x] 7.2 Create chat history retrieval endpoint
  - Implement GET /api/ask-wing-ai/history
  - Support pagination with limit and offset
  - Filter by authenticated user
  - Return messages in chronological order
  - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.6_

- [x] 7.3 Create clear history endpoint
  - Implement POST /api/ask-wing-ai/clear
  - Clear session chat history only
  - Keep moderation records intact
  - Return success confirmation
  - _Requirements: 23.1, 23.2, 23.3_

- [x] 7.4 Create rate limit status endpoint
  - Implement GET /api/ask-wing-ai/limits
  - Return daily limit, used count, and remaining
  - Include reset time in response
  - _Requirements: 11.4_

---

### Phase 8: Backend Moderation and Logging

- [x] 8.1 Implement question logging service
  - Store all questions with user ID and timestamp
  - Sanitize PII before storage
  - Store response summary (not full response)
  - Create moderation table for admin review
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [x] 8.2 Implement moderation alert system
  - Detect potential policy violations in questions
  - Flag inappropriate content for admin review
  - Create admin dashboard query for flagged items
  - Log flag reason and timestamp
  - _Requirements: 10.5_

- [x] 8.3 Implement comprehensive backend logging
  - Log all API requests with user ID and status
  - Record embedding generation times
  - Track vector search performance metrics
  - Store error logs with full context
  - _Requirements: 22.1, 22.2, 22.3, 22.4_

- [x] 8.4 Create monitoring and alerting
  - Set up metrics collection (response times, error rates)
  - Create admin dashboard with real-time metrics
  - Implement alerting for degraded performance
  - Monitor API rate limits and cost tracking
  - _Requirements: 22.5, 22.6, 22.7_

---

### Phase 9: Backend Error Handling

- [x] 9.1 Implement comprehensive error handling
  - Handle OpenAI API unavailability gracefully
  - Catch vector search failures with fallback messages
  - Handle embedding generation failures
  - Return user-friendly error messages
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [x] 9.2 Implement error logging and diagnostics
  - Log all errors with technical details
  - Mask sensitive information in error messages
  - Create error tracking dashboard
  - Implement automatic error recovery mechanisms
  - _Requirements: 12.5, 12.6, 12.7_

- [x] 9.3 Implement OpenAI rate limit handling
  - Catch rate limit errors from OpenAI API
  - Display graceful message to users
  - Implement exponential backoff retry logic
  - Alert administrators when limits approached
  - _Requirements: 12.7_

- [x] 9.4 Implement timeout handling
  - Set appropriate timeouts for API calls (30 seconds)
  - Handle timeout scenarios gracefully
  - Display timeout messages to users
  - Implement automatic retry for transient failures
  - _Requirements: 15.5, 15.6, 16.6_

---

### Phase 10: Frontend - Project Setup and State Management

- [x] 10.1 Set up Flutter project structure
  - Create ask_wing_ai feature module structure
  - Add directory structure (models, views, cubit, services)
  - Configure pubspec.yaml with dependencies
  - Set up architecture layers (presentation, business, data)
  - _Requirements: 1.1_

- [x] 10.2 Create AskWingAICubit and state classes
  - Implement AskWingAICubit with state management
  - Create state classes (Initial, Loading, Success, Error)
  - Implement submitQuestion() method
  - Implement clearHistory() method
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 10.3 Create data models and serializers
  - Create ChatMessage model with JSON serialization
  - Create Citation model for response citations
  - Create AskWingAIResponse model with all fields
  - Implement fromJson/toJson for API parsing
  - _Requirements: 9.1, 9.2, 9.3_

- [x] 10.4 Implement API client service
  - Create AskWingAIService for HTTP requests
  - Implement question submission endpoint call
  - Implement history retrieval endpoint call
  - Implement clear history endpoint call
  - _Requirements: 18.1, 19.1, 23.1_

---

### Phase 11: Frontend - Floating Action Button

- [x] 11.1 Create floating action button widget
  - Add FAB to HomePage in bottom-right corner
  - Display "Ask Wing AI" text or icon
  - Implement onPressed to open chat interface
  - Handle orientation changes (portrait/landscape)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6_

- [x] 11.2 Implement FAB authentication check
  - Verify user authentication before opening chat
  - Display login redirect if not authenticated
  - Re-enable FAB after successful authentication
  - Handle token expiration during session
  - _Requirements: 2.1, 2.2, 2.3_

---

### Phase 12: Frontend - Chat Interface UI

- [x] 12.1 Create chat interface modal/full-screen view
  - Create ChatInterfaceView widget
  - Implement header with "Ask Wing AI" title and close button
  - Add message list area with scrolling support
  - Add input field with send button
  - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.7_

- [x] 12.2 Implement welcome message display
  - Display welcome prompt when chat history is empty
  - Show example questions to get started
  - Display help information
  - Make welcome message dismissible
  - _Requirements: 3.4, 24.3_

- [x] 12.3 Create message bubble components
  - Create user message bubble (right-aligned, blue)
  - Create AI message bubble (left-aligned, gray)
  - Implement markdown formatting for AI responses
  - Add timestamp display to messages
  - _Requirements: 4.6, 8.2, 8.3_

- [x] 12.4 Implement loading indicator
  - Create typing animation/loading indicator
  - Display during AI response generation
  - Position indicator in message list
  - Allow cancel operation (optional)
  - _Requirements: 4.7, 15.1, 15.2, 15.3_

---

### Phase 13: Frontend - Input Handling and Submission

- [x] 13.1 Create message input field
  - Implement TextField for question input
  - Add send button (button or icon)
  - Clear field after submission
  - Disable send button when input is empty
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 13.2 Implement input validation
  - Check for empty message submission
  - Display error if message is empty
  - Validate maximum message length
  - Show character count (optional)
  - _Requirements: 4.4_

- [x] 13.3 Implement question submission flow
  - Emit submitQuestion() on send button tap
  - Show loading indicator immediately
  - Display user message in chat
  - Send sanitized question to backend
  - _Requirements: 4.2, 4.5, 4.7_

---

### Phase 14: Frontend - Response Display and Citations

- [x] 14.1 Implement response rendering with markdown
  - Parse and render markdown in AI response
  - Format bold, italics, lists, headers
  - Display citations block at end of response
  - Link to sermon player (future enhancement)
  - _Requirements: 8.1, 8.2, 8.4, 8.5_

- [x] 14.2 Create citation display component
  - Display citations in structured format
  - Show sermon title, speaker, timestamp
  - Make timestamps copyable or tappable
  - Format as list or card layout
  - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2, 7.3_

- [x] 14.3 Implement auto-scroll to latest message
  - Scroll to bottom when new message added
  - Scroll smoothly with animation
  - Allow manual scrolling to history
  - Re-scroll to bottom on new AI response
  - _Requirements: 9.5, 9.6_

---

### Phase 15: Frontend - Chat History and Session Management

- [x] 15.1 Implement chat history persistence (session)
  - Store messages in ChatHistory during session
  - Load history on chat interface open
  - Display all messages in conversation order
  - Clear history when session ends
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 15.2 Implement clear history functionality
  - Create clear history button/option
  - Show confirmation dialog before clearing
  - Clear local chat history on confirmation
  - Display welcome message after clearing
  - _Requirements: 23.1, 23.2, 23.3, 23.4_

- [x] 15.3 Implement rate limit display
  - Show remaining question count
  - Display daily limit status in header or settings
  - Update count after each question
  - Show warning when approaching limit
  - _Requirements: 11.4_

---

### Phase 16: Frontend - Error Handling and Loading States

- [x] 16.1 Implement error message display
  - Show user-friendly error messages in chat
  - Suggest retry option on failures
  - Display "contact support" for persistent errors
  - Handle different error types appropriately
  - _Requirements: 12.1, 12.2, 12.4, 12.5_

- [x] 16.2 Implement timeout and performance feedback
  - Display "response taking longer than expected" message
  - Show estimated wait time (optional)
  - Offer cancel or retry options
  - Handle timeout gracefully
  - _Requirements: 15.4, 15.5, 15.6_

- [x] 16.3 Implement authentication error handling
  - Catch 401 Unauthorized responses
  - Show re-authentication prompt
  - Redirect to login when needed
  - Maintain chat state after re-auth
  - _Requirements: 2.4_

---

### Phase 17: Frontend - Help and Documentation

- [x] 17.1 Create help button and interface
  - Add help button/icon to chat interface
  - Create help overlay with tips and examples
  - Display example questions
  - Make help dismissible
  - _Requirements: 24.1, 24.2, 24.3_

- [x] 17.2 Implement context-aware help
  - Show help tips on first launch
  - Display help when user gets no results
  - Suggest rephrasing for failed questions
  - Link to documentation (optional)
  - _Requirements: 24.4, 24.5_

- [x] 17.3 Implement localization for help content
  - Extract help text to localization files
  - Support multiple languages
  - Match app language settings
  - _Requirements: 24.6_

---

### Phase 18: Frontend - Responsive Design and Orientation

- [x] 18.1 Implement responsive layout
  - Test on various device sizes
  - Ensure FAB visible in all orientations
  - Adapt chat interface for landscape
  - Test with keyboard visible/hidden
  - _Requirements: 1.2, 1.3, 1.6_

- [x] 18.2 Implement orientation change handling
  - Handle device rotation gracefully
  - Maintain scroll position during rotation
  - Reposition FAB for landscape
  - Preserve message list state
  - _Requirements: 1.2, 1.3_

- [x] 18.3 Test accessibility features
  - Ensure semantic labels on buttons
  - Test with screen readers
  - Verify touch target sizes (min 48x48dp)
  - Test color contrast ratios
  - _Requirements: 1.1, 1.4_

---

### Phase 19: Integration and API Communication

- [x] 19.1 Implement async question processing
  - Implement polling mechanism for response status
  - Alternative: WebSocket for real-time updates
  - Handle network interruptions gracefully
  - Implement exponential backoff for polling
  - _Requirements: 7.1, 18.2, 18.7_

- [x] 19.2 Integrate authentication with API calls
  - Include JWT token in all requests
  - Handle token refresh automatically
  - Update token storage on refresh
  - Retry failed requests with new token
  - _Requirements: 2.1, 18.3, 18.4_

- [x] 19.3 Implement error response handling
  - Parse backend error messages
  - Display appropriate UI for each error type
  - Implement retry logic for transient errors
  - Log errors for debugging
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

---

### Phase 20: Testing and Quality Assurance

- [x] 20.1* Implement unit tests for backend services
  - Test EmbeddingService (mock OpenAI API)
  - Test VectorSearchService with mock database
  - Test ResponseGeneratorService (mock GPT-4)
  - Test DataSanitizationService
  - Test RateLimiterService
  - _Requirements: 5.1, 5.2, 6.1, 11.1, 14.1_

- [x] 20.2* Implement unit tests for frontend
  - Test AskWingAICubit state management
  - Test message submission logic
  - Test error handling
  - Test rate limit display
  - _Requirements: 4.1, 4.2, 11.4_

- [x] 20.3* Implement integration tests
  - Test full question-to-response flow with mocks
  - Test authentication and rate limiting flow
  - Test error scenarios (API failures, timeouts)
  - Test chat history retrieval and clearing
  - _Requirements: 18.1, 19.1, 19.2, 23.1_

- [x] 20.4* Implement performance testing
  - Test vector search performance (< 2 seconds)
  - Test embedding generation latency (< 3 seconds)
  - Test full response time (< 10 seconds)
  - Load test rate limiting with concurrent users
  - _Requirements: 16.2, 16.3, 16.4_

- [x] 20.5* Implement security testing
  - Test SQL injection prevention
  - Test XSS prevention in markdown rendering
  - Test rate limiting enforcement
  - Test authentication token validation
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.6_

- [x] 20.6* Test data sanitization
  - Test PII detection and removal
  - Test with real email addresses, phone numbers
  - Test with account numbers and sensitive data
  - Verify sanitized data not sent to OpenAI
  - _Requirements: 14.1, 14.2, 14.4, 14.6_

---

### Phase 21: Checkpoint and System Verification

- [x] 21.1 Full end-to-end system test
  - Execute complete user flow from FAB to response
  - Verify authentication integration
  - Test rate limiting prevents abuse
  - Verify citations match source material
  - Test with various question types
  - Ensure all tests pass

- [x] 21.2 Performance and load testing
  - Verify response times within SLA (< 10 seconds)
  - Test with 100+ concurrent users
  - Monitor error rates under load
  - Check API usage and costs
  - Verify database performance with large datasets

- [x] 21.3 Security and compliance review
  - Verify no API keys in logs or source code
  - Confirm PII not transmitted to external services
  - Validate authentication on all endpoints
  - Review error messages for information leakage
  - Check HTTPS/TLS configuration

- [x] 21.4 Moderation and monitoring setup
  - Verify question logging working
  - Test moderation alert system
  - Confirm admin dashboard displays metrics
  - Test log retention and archiving
  - Verify alert notifications working

---

### Phase 22: Deployment Preparation

- [x] 22.1* Create deployment documentation
  - Document infrastructure requirements
  - Create deployment checklist
  - Document environment variables needed
  - Create rollback procedures
  - Document monitoring and alerting setup
  - _Requirements: 13.1, 13.5_

- [x] 22.2* Set up production monitoring
  - Configure CloudWatch or equivalent
  - Set up dashboards for key metrics
  - Create runbooks for common issues
  - Configure alerting for critical errors
  - Set up log aggregation
  - _Requirements: 22.5, 22.6, 22.7_

- [x] 22.3* Document API and system architecture
  - Create API documentation (OpenAPI/Swagger)
  - Document database schema and indexes
  - Document vector search tuning parameters
  - Create troubleshooting guide
  - Document known limitations and future work

---

## Implementation Notes

### Task Ordering and Dependencies

**Strict Ordering:** Tasks should be completed in phase order for maximum efficiency:
1. **Phase 1-5**: Backend infrastructure and services (must complete before testing)
2. **Phase 6-9**: Backend API and services (must complete before frontend integration)
3. **Phase 10-18**: Frontend UI and logic (can begin when Phase 7 endpoints are ready)
4. **Phase 19**: Integration (requires both backend and frontend)
5. **Phase 20-22**: Testing and deployment

### Optional Tasks

Tasks marked with `*` are optional sub-tasks that can be deferred for MVP:
- All testing tasks (20.1-20.6) can be completed incrementally
- Deployment documentation (22.1-22.3) can follow initial release

### Key Performance Metrics to Validate

- Embedding generation: < 3 seconds
- Vector search: < 2 seconds  
- Full response: < 10 seconds
- No API keys in logs or source code
- Rate limiting enforced per user per day
- PII not sent to external services

### Configuration Parameters (Admin Tunable)

- Daily question limit per user: 50 (configurable)
- Vector search top-K results: 5 (configurable)
- Minimum similarity threshold: 0.7 (configurable)
- Session timeout: 30 minutes (configurable)
- Response timeout: 30 seconds (configurable)

### Security Checklist

- [x] All API keys in environment variables only
- [x] HTTPS/TLS for all external API calls
- [x] JWT authentication on all endpoints
- [x] Input validation on all endpoints
- [x] Data sanitization before external services
- [x] No PII in logs or error messages
- [x] Rate limiting enforced
- [x] CSRF protection enabled
- [x] Security headers configured

---

## Success Criteria

The Ask Wing AI feature is complete and production-ready when:

✅ All requirements (1-25) implemented and verified
✅ Sermon audio automatically transcribed using OpenAI Whisper when uploaded
✅ Transcripts properly stored and linked to sermon metadata
✅ All tests passing (unit, integration, performance, security)
✅ Response time consistently < 10 seconds
✅ Transcription processing completes with retry logic
✅ Rate limiting working and preventing abuse
✅ No API keys or sensitive data in logs
✅ PII detection and removal working correctly
✅ Citations accurate and properly formatted
✅ Error handling graceful with helpful messages
✅ Monitoring and alerting operational
✅ Documentation complete and reviewed
