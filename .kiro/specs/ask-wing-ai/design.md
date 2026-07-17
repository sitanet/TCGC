# Ask Wing AI - Technical Design Document

## Overview

Ask Wing AI is an AI-powered question-answering system integrated into the TCGC mobile app, enabling users to ask questions about sermons and receive accurate answers with citations. This design document provides comprehensive technical specifications for implementation across Flutter frontend, Django backend, and cloud infrastructure components.

The system leverages OpenAI's GPT-4 for intelligent response generation, vector embeddings for semantic search across sermon transcripts, and a Django REST backend to orchestrate the retrieval-augmented generation (RAG) pipeline.

**Key Characteristics:**
- RAG-based architecture combining document retrieval with LLM generation
- Vector embeddings stored in PostgreSQL with pgvector extension
- Real-time processing with <10 second response times
- Session-based chat history with moderation logging
- Rate-limited access with comprehensive security controls

---

## Architecture

### System Architecture Overview

```mermaid
graph TB
    subgraph "Client Layer"
        Flutter["Flutter App<br/>- Home Page FAB<br/>- Chat Interface<br/>- Message Display"]
    end
    
    subgraph "Upload Layer"
        Upload["Sermon Upload<br/>- Audio File Upload<br/>- Upload Status Tracking"]
    end
    
    subgraph "Transcription Layer"
        TranscribeService["Transcription Service<br/>- OpenAI Whisper<br/>- Audio Chunking<br/>- Status Tracking"]
    end
    
    subgraph "API Layer"
        DjangoAPI["Django REST API<br/>- Authentication<br/>- Question Submission<br/>- History Retrieval<br/>- Rate Limiting<br/>- Data Sanitization"]
    end
    
    subgraph "Processing Layer"
        EmbedService["Embedding Service<br/>- OpenAI Embeddings<br/>- Vector Generation"]
        SearchService["Vector Search Service<br/>- Semantic Similarity<br/>- Top-K Retrieval"]
        ResponseGen["Response Generator<br/>- GPT-4 Integration<br/>- Citation Building<br/>- Markdown Formatting"]
    end
    
    subgraph "Data Layer"
        PostgreSQL["PostgreSQL<br/>- pgvector Extension<br/>- Sermon Metadata<br/>- Embeddings<br/>- Chat History<br/>- Moderation Logs<br/>- Transcripts"]
    end
    
    subgraph "External Services"
        OpenAI["OpenAI API<br/>- GPT-4 Model<br/>- Embedding Model<br/>- Whisper (Transcription)<br/>- text-embedding-3-small"]
    end
    
    Upload -->|Audio File| TranscribeService
    TranscribeService -->|Whisper API| OpenAI
    OpenAI -->|Transcript Text| TranscribeService
    TranscribeService -->|Store Transcript| PostgreSQL
    TranscribeService -->|Trigger Indexing| EmbedService
    
    Flutter -->|JWT Auth| DjangoAPI
    DjangoAPI -->|Sanitize & Embed| EmbedService
    EmbedService -->|Vector Lookup| SearchService
    SearchService -->|Sermon Context| ResponseGen
    ResponseGen -->|GPT-4 Request| OpenAI
    OpenAI -->|Embeddings & Responses| ResponseGen
    DjangoAPI -->|Store/Retrieve| PostgreSQL
    SearchService -->|Query Vectors| PostgreSQL
```

**Architecture Components:**

1. **Client Layer (Flutter)**: UI components and state management
2. **API Layer (Django)**: REST endpoints, authentication, request/response handling
3. **Processing Layer**: Embedding generation, vector search, response generation
4. **Data Layer**: PostgreSQL with pgvector for vector search
5. **External Services**: OpenAI API for embeddings and LLM

---

## Transcription Service Architecture

### Sermon Audio Transcription Pipeline

```python
class TranscriptionService:
    """Handles automatic transcription of sermon audio using OpenAI Whisper"""
    
    MAX_FILE_SIZE_MB = 25  # OpenAI Whisper limit
    
    def transcribe_sermon(self, sermon_id: int, audio_file_path: str) -> Dict:
        """
        Transcribe sermon audio using OpenAI Whisper API
        
        Args:
            sermon_id: ID of the sermon being transcribed
            audio_file_path: Path to audio file
            
        Returns:
            Dict with transcript and metadata
        """
        import openai
        
        # Update sermon status to "processing"
        sermon = Message.objects.get(id=sermon_id)
        sermon.transcription_status = 'processing'
        sermon.save()
        
        try:
            # Check file size
            file_size_mb = os.path.getsize(audio_file_path) / (1024 * 1024)
            
            if file_size_mb > self.MAX_FILE_SIZE_MB:
                # Split into chunks for large files
                chunks = self._split_audio_file(audio_file_path, self.MAX_FILE_SIZE_MB)
                transcripts = []
                for chunk in chunks:
                    transcript = self._transcribe_chunk(chunk)
                    transcripts.append(transcript)
                full_transcript = ' '.join(transcripts)
            else:
                # Transcribe directly
                full_transcript = self._transcribe_chunk(audio_file_path)
            
            # Store transcript
            sermon.transcript = full_transcript
            sermon.transcription_status = 'completed'
            sermon.transcription_completed_at = timezone.now()
            sermon.save()
            
            # Trigger embedding indexing
            from .tasks import index_sermon_embeddings
            index_sermon_embeddings.delay(sermon_id)
            
            return {
                'sermon_id': sermon_id,
                'transcript': full_transcript,
                'status': 'completed',
                'character_count': len(full_transcript)
            }
            
        except Exception as e:
            # Retry logic with exponential backoff
            retry_count = getattr(sermon, 'transcription_retry_count', 0)
            if retry_count < 3:
                sermon.transcription_retry_count = retry_count + 1
                sermon.save()
                # Re-queue task with delay
                raise self.retry(exc=e, countdown=2 ** retry_count)
            else:
                # Give up after 3 retries
                sermon.transcription_status = 'failed'
                sermon.transcription_error = str(e)
                sermon.save()
                logger.error(f"Transcription failed for sermon {sermon_id} after 3 retries: {str(e)}")
                raise
    
    def _split_audio_file(self, file_path: str, chunk_size_mb: int = 25) -> List[str]:
        """
        Split large audio files into chunks for transcription
        
        Uses ffmpeg to split audio by time duration
        """
        import subprocess
        
        # Calculate duration in seconds
        result = subprocess.run(
            ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', 
             '-of', 'default=noprint_wrappers=1:nokey=1:nokey=1', file_path],
            capture_output=True,
            text=True
        )
        duration = float(result.stdout)
        
        # Estimate chunk duration based on file size
        # Rough estimate: 1 hour audio ≈ 50 MB
        chunk_duration = (chunk_size_mb / 50) * 3600
        
        chunks = []
        for i in range(0, int(duration), int(chunk_duration)):
            chunk_path = f"{file_path}.chunk_{i}.mp3"
            subprocess.run([
                'ffmpeg', '-i', file_path,
                '-ss', str(i), '-t', str(int(chunk_duration)),
                '-c:a', 'libmp3lame', '-q:a', '9',
                chunk_path
            ])
            chunks.append(chunk_path)
        
        return chunks
    
    def _transcribe_chunk(self, audio_file_path: str) -> str:
        """
        Transcribe a single audio chunk using OpenAI Whisper
        """
        import openai
        
        with open(audio_file_path, 'rb') as audio_file:
            transcript = openai.Audio.transcribe(
                model="whisper-1",
                file=audio_file,
                language="en"  # Can be made configurable
            )
        
        return transcript['text']
```

### Sermon Upload Workflow Integration

```python
# In Message/Sermon model
class Message(models.Model):
    # ... existing fields ...
    
    # Transcription fields
    transcript = models.TextField(null=True, blank=True)
    transcription_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('processing', 'Processing'),
            ('completed', 'Completed'),
            ('failed', 'Failed'),
        ],
        default='pending'
    )
    transcription_error = models.TextField(null=True, blank=True)
    transcription_retry_count = models.IntegerField(default=0)
    transcription_completed_at = models.DateTimeField(null=True, blank=True)

# In serializer for upload
class SermonUploadSerializer(serializers.ModelSerializer):
    audio_file = serializers.FileField(write_only=True)
    
    class Meta:
        model = Message
        fields = ['id', 'title', 'speaker', 'audio_file', 'date_uploaded']
    
    def create(self, validated_data):
        audio_file = validated_data.pop('audio_file')
        
        # Create sermon record
        sermon = Message.objects.create(**validated_data)
        
        # Save audio file
        file_path = f"sermons/{sermon.id}/audio.mp3"
        with open(file_path, 'wb+') as destination:
            for chunk in audio_file.chunks():
                destination.write(chunk)
        
        # Queue transcription task
        from .tasks import transcribe_sermon_audio
        transcribe_sermon_audio.delay(sermon.id, file_path)
        
        return sermon
```

### Celery Task for Transcription

```python
# In tasks.py
from celery import shared_task

@shared_task(bind=True, max_retries=3)
def transcribe_sermon_audio(self, sermon_id: int, audio_file_path: str):
    """
    Async Celery task to transcribe sermon audio
    
    Retry with exponential backoff on failure
    """
    try:
        service = TranscriptionService()
        result = service.transcribe_sermon(sermon_id, audio_file_path)
        return result
    except Exception as exc:
        # Exponential backoff: 2^retry_count seconds
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)
```

### Admin API for Upload Status

```python
class SermonUploadStatusView(APIView):
    """Check transcription status of uploaded sermons"""
    
    permission_classes = [IsAuthenticated, IsAdminOrReadOnly]
    
    def get(self, request, sermon_id):
        sermon = Message.objects.get(id=sermon_id)
        
        return Response({
            'sermon_id': sermon.id,
            'title': sermon.title,
            'transcription_status': sermon.transcription_status,
            'transcription_completed_at': sermon.transcription_completed_at,
            'transcript_length': len(sermon.transcript) if sermon.transcript else 0,
            'error_message': sermon.transcription_error,
        })
```

---

### Frontend Architecture (Flutter)

### Widget Structure

```
HomePage
├── FloatingActionButton (Ask Wing AI)
│   └── onPressed → _openChatInterface()
│
ChatInterfaceModal
├── Header
│   ├── Title ("Ask Wing AI")
│   └── CloseButton
├── MessageListView
│   ├── WelcomeMessage (when empty)
│   ├── MessageBubbles
│   │   ├── UserMessage (right-aligned, blue)
│   │   └── AIMessage (left-aligned, gray with citations)
│   └── LoadingIndicator (during processing)
└── InputSection
    ├── TextField (question input)
    ├── SendButton
    └── HelpButton (tooltip on long-press)
```

### State Management

```dart
class AskWingAICubit extends Cubit<AskWingAIState> {
  // State properties
  List<ChatMessage> messages = [];
  bool isLoading = false;
  int dailyQuestionsUsed = 0;
  int dailyQuestionsLimit = 50;
  String? error;
  
  // Methods
  Future<void> submitQuestion(String question) async {
    // 1. Validate authentication
    // 2. Check rate limit
    // 3. Sanitize input
    // 4. Send to backend
    // 5. Stream response
    // 6. Update UI
  }
  
  void clearHistory() {
    messages.clear();
    emit(AskWingAIInitial());
  }
}
```

### Key UI Considerations

1. **Responsive Design**: Adapts to portrait and landscape orientations
2. **Accessibility**: Large touch targets, high contrast text, semantic labels
3. **Performance**: Message virtualization for large histories, lazy loading
4. **Error States**: Graceful error messages with retry options
5. **Loading Feedback**: Real-time typing indicator during processing

### Backend Architecture (Django)

### App Structure

```
ask_wing_ai/
├── __init__.py
├── models.py
│   ├── AskWingAIQuestion (stores questions for moderation)
│   ├── ChatSession (tracks session state)
│   └── SermonEmbedding (vector index metadata)
├── views.py
│   ├── SubmitQuestionView (POST /api/ask-wing-ai/questions)
│   ├── ChatHistoryView (GET /api/ask-wing-ai/history)
│   ├── ClearHistoryView (POST /api/ask-wing-ai/clear)
│   └── RateLimitCheckView (GET /api/ask-wing-ai/limits)
├── serializers.py
│   ├── QuestionSubmissionSerializer
│   ├── ChatMessageSerializer
│   └── ResponseSerializer
├── services.py
│   ├── AudioTranscriptionService
│   ├── EmbeddingService
│   ├── VectorSearchService
│   ├── ResponseGeneratorService
│   ├── DataSanitizationService
│   └── RateLimiterService
├── tasks.py (Celery async tasks)
│   ├── index_sermon_embeddings()
│   ├── generate_embedding()
│   └── process_question()
└── urls.py
```

### API Endpoints

**1. Submit Question**
```
POST /api/ask-wing-ai/questions
Content-Type: application/json
Authorization: Bearer {JWT_TOKEN}

Request:
{
  "question": "What does the Bible say about faith?",
  "previous_message_ids": [123, 124]  // optional, for context
}

Response (202 Accepted):
{
  "message_id": 456,
  "status": "processing",
  "timestamp": "2024-01-15T10:30:00Z"
}

Response (on completion, via polling or WebSocket):
{
  "message_id": 456,
  "question": "What does the Bible say about faith?",
  "response": "Based on sermon content...",
  "citations": [
    {
      "sermon_title": "Living by Faith",
      "speaker": "Pastor John",
      "timestamp": "24:35",
      "sermon_id": 123
    }
  ],
  "processing_time_ms": 8500,
  "timestamp": "2024-01-15T10:30:08Z"
}
```

**2. Get Chat History**
```
GET /api/ask-wing-ai/history?limit=50&offset=0
Authorization: Bearer {JWT_TOKEN}

Response:
{
  "messages": [
    {
      "message_id": 123,
      "type": "user",
      "content": "What is repentance?",
      "timestamp": "2024-01-15T10:00:00Z"
    },
    {
      "message_id": 124,
      "type": "ai",
      "content": "Repentance means...",
      "citations": [...],
      "timestamp": "2024-01-15T10:00:05Z"
    }
  ],
  "total": 24,
  "has_more": true
}
```

**3. Clear History**
```
POST /api/ask-wing-ai/clear
Authorization: Bearer {JWT_TOKEN}

Response:
{
  "status": "success",
  "message": "Chat history cleared"
}
```

**4. Rate Limit Status**
```
GET /api/ask-wing-ai/limits
Authorization: Bearer {JWT_TOKEN}

Response:
{
  "daily_limit": 50,
  "daily_used": 12,
  "daily_remaining": 38,
  "reset_time": "2024-01-16T00:00:00Z"
}
```

### Audio Transcription Service

```python
class AudioTranscriptionService:
    """Transcribe sermon audio files to text using OpenAI Whisper API"""
    
    def transcribe_sermon_audio(self, message_id: int, audio_file_path: str) -> str:
        """
        Transcribe sermon audio to text using OpenAI Whisper
        
        Args:
            message_id: ID of the sermon/message
            audio_file_path: Path to audio file in storage (S3, local, etc)
            
        Returns:
            Transcribed text
        """
        import openai
        import requests
        from django.core.files.storage import default_storage
        
        try:
            # Download audio file from storage
            with default_storage.open(audio_file_path, 'rb') as audio_file:
                # Call OpenAI Whisper API
                transcript_response = openai.Audio.transcribe(
                    model="whisper-1",
                    file=audio_file,
                    language="en"  # Can be made configurable
                )
            
            transcript_text = transcript_response['text']
            
            # Store transcript in database
            message = Message.objects.get(id=message_id)
            message.transcript = transcript_text
            message.transcription_status = 'completed'
            message.transcribed_at = timezone.now()
            message.save()
            
            # Trigger embedding indexing as background task
            from celery import current_app
            current_app.send_task(
                'ask_wing_ai.tasks.index_sermon_embeddings',
                args=(message_id,),
                countdown=5  # Slight delay to ensure transcript is saved
            )
            
            return transcript_text
            
        except openai.error.APIError as e:
            # Log transcription error
            message = Message.objects.get(id=message_id)
            message.transcription_status = 'failed'
            message.transcription_error = str(e)
            message.save()
            
            raise Exception(f"Whisper API error: {str(e)}")
    
    def transcribe_sermon_async(self, message_id: int, audio_file_path: str) -> None:
        """
        Async wrapper for transcription (called by Celery)
        
        Args:
            message_id: ID of the sermon/message
            audio_file_path: Path to audio file in storage
        """
        try:
            message = Message.objects.get(id=message_id)
            message.transcription_status = 'processing'
            message.save()
            
            self.transcribe_sermon_audio(message_id, audio_file_path)
            
        except Message.DoesNotExist:
            raise Exception(f"Message {message_id} not found")
```

**Transcription Workflow:**
1. When sermon audio is uploaded, create Message record with status 'pending_transcription'
2. Trigger `transcribe_sermon_async()` as Celery task
3. Whisper API processes audio and returns transcript
4. Store transcript in Message.transcript field
5. Update Message.transcription_status to 'completed'
6. Automatically trigger embedding indexing task
7. If transcription fails, store error message and allow retry

**Configuration:**
- Whisper model: "whisper-1" (OpenAI's latest)
- Language: English (can be extended for multilingual)
- Audio format support: MP3, MP4, MPEG, MPGA, M4A, WAV, WEBM
- Maximum file size: 25MB (OpenAI limit)
- Timeout: 60 seconds per file

**Cost Considerations:**
- Whisper API: $0.006 per minute of audio
- Batch processing for efficiency
- Monitor total transcription time and costs

---

### Vector Search Implementation

### Embedding Pipeline

```python
class EmbeddingService:
    """Manages vector embeddings for semantic search"""
    
    def generate_embedding(self, text: str) -> List[float]:
        """
        Generate vector embedding using OpenAI's text-embedding-3-small
        
        Args:
            text: Input text to embed
            
        Returns:
            768-dimensional vector
        """
        response = openai.Embedding.create(
            model="text-embedding-3-small",
            input=text
        )
        return response['data'][0]['embedding']
    
    def chunk_transcript(self, transcript: str, chunk_size: int = 1000, overlap: int = 200) -> List[str]:
        """
        Split transcript into overlapping chunks for better search precision
        
        Args:
            transcript: Full sermon transcript
            chunk_size: Characters per chunk (approximately)
            overlap: Characters of overlap between chunks
            
        Returns:
            List of text chunks with overlap
        """
        chunks = []
        sentences = transcript.split('. ')
        
        current_chunk = ""
        for sentence in sentences:
            if len(current_chunk) + len(sentence) < chunk_size:
                current_chunk += sentence + ". "
            else:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                # Start new chunk with overlap
                current_chunk = current_chunk[-overlap:] + sentence + ". "
        
        if current_chunk:
            chunks.append(current_chunk.strip())
        
        return chunks
    
    def index_sermon(self, sermon_id: int, transcript: str) -> None:
        """
        Generate and store embeddings for a sermon transcript
        
        Args:
            sermon_id: ID of the sermon
            transcript: Full sermon transcript text
        """
        chunks = self.chunk_transcript(transcript)
        
        for chunk_idx, chunk in enumerate(chunks):
            # Generate embedding
            vector = self.generate_embedding(chunk)
            
            # Store in PostgreSQL with pgvector
            SermonEmbedding.objects.create(
                sermon_id=sermon_id,
                chunk_index=chunk_idx,
                text_chunk=chunk,
                embedding=vector,
                chunk_start_position=self._calculate_position(transcript, chunk)
            )
```

### Vector Search

```python
class VectorSearchService:
    """Semantic search using vector embeddings"""
    
    def search(self, question: str, top_k: int = 5, min_similarity: float = 0.7) -> List[Dict]:
        """
        Find semantically similar sermon chunks
        
        Args:
            question: User question
            top_k: Number of results to return
            min_similarity: Minimum cosine similarity threshold (0-1)
            
        Returns:
            List of relevant sermon chunks with metadata
        """
        # Generate embedding for question
        question_vector = EmbeddingService().generate_embedding(question)
        
        # Search using pgvector's cosine similarity
        from django.db import connection
        from django.db.models import F
        
        results = SermonEmbedding.objects.raw("""
            SELECT 
                se.*,
                m.title,
                m.speaker_id,
                s.name as speaker_name,
                (1 - (se.embedding <=> %s::vector)) as similarity
            FROM sermon_embeddings se
            JOIN messages m ON se.sermon_id = m.id
            JOIN speakers s ON m.speaker_id = s.id
            WHERE (1 - (se.embedding <=> %s::vector)) > %s
            ORDER BY similarity DESC
            LIMIT %s
        """, [question_vector, question_vector, min_similarity, top_k])
        
        # Format results with timestamp calculation
        formatted_results = []
        for result in results:
            formatted_results.append({
                'sermon_id': result.sermon_id,
                'sermon_title': result.title,
                'speaker_name': result.speaker_name,
                'speaker_id': result.speaker_id,
                'text_chunk': result.text_chunk,
                'chunk_index': result.chunk_index,
                'estimated_timestamp': self._calculate_timestamp(
                    result.chunk_start_position,
                    result.sermon_id
                ),
                'similarity_score': float(result.similarity)
            })
        
        return formatted_results
    
    def _calculate_timestamp(self, position: int, sermon_id: int) -> str:
        """
        Estimate timestamp based on text position and sermon duration
        
        Assuming average speaking rate of ~130 words per minute
        """
        message = Message.objects.get(id=sermon_id)
        duration_seconds = message.duration_minutes * 60
        
        # Estimate words from position (rough: 5 chars per word)
        estimated_words = position // 5
        estimated_seconds = int((estimated_words / 130) * 60)
        estimated_seconds = min(estimated_seconds, duration_seconds)
        
        minutes = estimated_seconds // 60
        seconds = estimated_seconds % 60
        return f"{minutes:02d}:{seconds:02d}"
```

---

## Data Models

### Database Schema

### Core Models

```python
class SermonEmbedding(models.Model):
    """Vector embeddings for semantic search"""
    sermon = models.ForeignKey(Message, on_delete=models.CASCADE, related_name='embeddings')
    chunk_index = models.IntegerField()
    text_chunk = models.TextField()
    embedding = VectorField(dimensions=1536)  # OpenAI embedding dimension
    chunk_start_position = models.IntegerField()  # Character position in transcript
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'sermon_embeddings'
        unique_together = ['sermon', 'chunk_index']
        indexes = [
            models.Index(fields=['sermon']),
        ]

class AskWingAIQuestion(models.Model):
    """User questions for moderation and analytics"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ask_wing_questions')
    question = models.TextField()
    question_sanitized = models.TextField()  # Personally identifiable info removed
    response_summary = models.TextField(blank=True, null=True)
    flagged_for_review = models.BooleanField(default=False)
    flag_reason = models.CharField(max_length=255, blank=True, null=True)
    processing_time_ms = models.IntegerField()  # For performance monitoring
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'ask_wing_ai_questions'
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['flagged_for_review']),
        ]

class ChatSession(models.Model):
    """Session-based chat history tracking"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='chat_sessions')
    session_id = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_activity = models.DateTimeField(auto_now=True)
    expires_at = models.DateTimeField()  # Session expiration time
    
    class Meta:
        db_table = 'chat_sessions'
        indexes = [
            models.Index(fields=['user', 'created_at']),
        ]

class ChatMessage(models.Model):
    """Individual messages in a chat session"""
    MESSAGE_TYPE_CHOICES = [
        ('user', 'User Question'),
        ('ai', 'AI Response'),
    ]
    
    session = models.ForeignKey(ChatSession, on_delete=models.CASCADE, related_name='messages')
    message_type = models.CharField(max_length=10, choices=MESSAGE_TYPE_CHOICES)
    content = models.TextField()
    processing_time_ms = models.IntegerField(null=True, blank=True)
    error_message = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'chat_messages'
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['session', 'created_at']),
        ]

class Citation(models.Model):
    """Citations for AI responses"""
    chat_message = models.ForeignKey(ChatMessage, on_delete=models.CASCADE, related_name='citations')
    sermon = models.ForeignKey(Message, on_delete=models.CASCADE)
    speaker = models.ForeignKey(Speaker, on_delete=models.CASCADE)
    text_chunk = models.TextField()
    estimated_timestamp = models.CharField(max_length=10)  # MM:SS format
    similarity_score = models.FloatField()
    
    class Meta:
        db_table = 'citations'
        indexes = [
            models.Index(fields=['chat_message']),
        ]

class Message(models.Model):
    """Extended Message model with transcription fields for Ask Wing AI"""
    # Original fields (from existing Message model)
    title = models.CharField(max_length=255)
    speaker = models.ForeignKey(Speaker, on_delete=models.SET_NULL, null=True, related_name='messages')
    date = models.DateTimeField()
    duration_minutes = models.IntegerField()
    audio_url = models.URLField()
    
    # Audio transcription fields
    transcript = models.TextField(null=True, blank=True)  # Full sermon transcript
    transcription_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending Transcription'),
            ('processing', 'Processing'),
            ('completed', 'Completed'),
            ('failed', 'Failed'),
        ],
        default='pending'
    )
    transcription_error = models.TextField(null=True, blank=True)  # Error details if failed
    transcribed_at = models.DateTimeField(null=True, blank=True)  # When transcription completed
    
    # Indexing status
    indexing_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending Indexing'),
            ('processing', 'Processing'),
            ('completed', 'Completed'),
            ('failed', 'Failed'),
        ],
        default='pending'
    )
    indexed_at = models.DateTimeField(null=True, blank=True)  # When embeddings were created
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'messages'
        indexes = [
            models.Index(fields=['speaker', 'date']),
            models.Index(fields=['transcription_status']),
            models.Index(fields=['indexing_status']),
        ]
```

### Database Indexes

```sql
-- Vector search index for performance
CREATE INDEX idx_sermon_embeddings_vector ON sermon_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Question lookup by user and date
CREATE INDEX idx_ask_wing_questions_user_date ON ask_wing_ai_questions(user_id, created_at DESC);

-- Session lookup by expiration
CREATE INDEX idx_chat_sessions_expiry ON chat_sessions(expires_at);
```



### Data Flow Diagrams

#### Question Submission Flow

```
User submits question
        ↓
[Flutter] Emit AskWingAICubit.submitQuestion()
        ↓
[Flutter] Check authentication (JWT token valid?)
        ↓
[Flutter] Display loading indicator
        ↓
[Django API] POST /api/ask-wing-ai/questions (with JWT)
        ↓
[Django] Middleware: Verify JWT token
        ↓
[Django] Rate Limiter: Check daily question count
        ↓
[Django] Data Sanitizer: Remove PII from question
        ↓
[Django] Store question in AskWingAIQuestion table
        ↓
[Embedding Service] Generate embedding for sanitized question
        ↓
[Vector Search] Find top-5 relevant sermon chunks
        ↓
[Response Generator] Build context from sermon chunks + citations
        ↓
[OpenAI] Call GPT-4 with context + system prompt
        ↓
[Response Generator] Format response with markdown + citations
        ↓
[Django] Store ChatMessage (AI response + citations)
        ↓
[Django] Return response to Flutter
        ↓
[Flutter] Parse response, display in ChatInterfaceModal
        ↓
User sees answer with clickable citations
```

#### Sermon Indexing Flow (Background)

```
Admin uploads sermon audio file
        ↓
[Django] Create Message object for sermon
        ↓
[Celery Task] transcribe_sermon_audio(message_id) triggered
        ↓
[Audio Transcription Service] Download audio from storage
        ↓
[OpenAI Whisper API] Transcribe audio to text
        ↓
[Django] Store transcript in Message.transcript field
        ↓
[Celery Task] index_sermon_embeddings(sermon_id) triggered
        ↓
[Embedding Service] Retrieve sermon transcript
        ↓
[Embedding Service] Split transcript into chunks (1000 chars + 200 overlap)
        ↓
For each chunk:
  [OpenAI Embeddings] Generate embedding for chunk
  [Django] Store SermonEmbedding (chunk + vector)
        ↓
[Search Index] Update pgvector IVFFlat index
        ↓
[Background Job] Complete - sermon now searchable
```

---

### Integration with OpenAI

#### GPT-4 Integration

```python
class ResponseGeneratorService:
    """Generate AI responses using GPT-4"""
    
    SYSTEM_PROMPT = """
You are Ask Wing AI, an expert assistant helping church members find answers from sermons.

INSTRUCTIONS:
1. Answer questions ONLY based on the provided sermon content
2. If information is not in the sermons, say so explicitly
3. Include citations after each statement sourced from sermons
4. Use markdown for formatting (bold, italics, bullet points)
5. Keep responses concise (2-4 paragraphs maximum)
6. Be respectful and encouraging in tone
7. Never make assumptions beyond what's stated in sermons

CITATION FORMAT:
Use this format for citations: [Sermon Title by Speaker Name at MM:SS]
Always include timestamps when specific content is referenced.

CONTEXT: The following sermon content is provided:
{context}

CONVERSATION HISTORY:
{conversation_history}

Answer the user's question:
"""
    
    def generate_response(self, question: str, sermon_context: List[Dict], conversation_history: List[Dict]) -> Dict:
        """
        Generate response using GPT-4
        
        Args:
            question: User's sanitized question
            sermon_context: Retrieved sermon chunks with metadata
            conversation_history: Previous messages for context
            
        Returns:
            Dict with response, citations, and metadata
        """
        import openai
        import time
        
        start_time = time.time()
        
        # Build context string from sermon chunks
        context_str = self._build_context(sermon_context)
        
        # Build conversation history for follow-up questions
        history_str = self._build_conversation_history(conversation_history)
        
        # Fill system prompt
        system_prompt = self.SYSTEM_PROMPT.format(
            context=context_str,
            conversation_history=history_str
        )
        
        # Call GPT-4
        try:
            response = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": question}
                ],
                temperature=0.7,
                max_tokens=1000,
                timeout=30
            )
            
            response_text = response['choices'][0]['message']['content']
            processing_time = int((time.time() - start_time) * 1000)
            
            # Extract citations from sermon context
            citations = self._extract_citations(sermon_context)
            
            return {
                'response': response_text,
                'citations': citations,
                'processing_time_ms': processing_time,
                'model': 'gpt-4',
                'tokens_used': response['usage']['total_tokens']
            }
            
        except openai.error.RateLimitError:
            raise Exception("OpenAI API rate limit exceeded. Please try again later.")
        except openai.error.APIError as e:
            raise Exception(f"OpenAI API error: {str(e)}")
    
    def _build_context(self, sermon_context: List[Dict]) -> str:
        """Format sermon chunks into readable context"""
        context_parts = []
        for i, chunk in enumerate(sermon_context, 1):
            part = f"""
SERMON {i}: {chunk['sermon_title']} by {chunk['speaker_name']}
Timestamp: {chunk['estimated_timestamp']}
Relevance: {chunk['similarity_score']:.2%}

{chunk['text_chunk']}
---"""
            context_parts.append(part)
        
        return "\n".join(context_parts)
    
    def _extract_citations(self, sermon_context: List[Dict]) -> List[Dict]:
        """Extract structured citations from sermon context"""
        return [
            {
                'sermon_id': chunk['sermon_id'],
                'sermon_title': chunk['sermon_title'],
                'speaker_name': chunk['speaker_name'],
                'speaker_id': chunk['speaker_id'],
                'timestamp': chunk['estimated_timestamp'],
                'relevance': chunk['similarity_score']
            }
            for chunk in sermon_context
        ]
```

### Prompt Engineering Strategy

**System Prompt Design:**
1. **Clear Role Definition**: Explicitly state the assistant is a sermon Q&A helper
2. **Citation Requirement**: Mandate citations for all sermon-sourced information
3. **Boundary Setting**: Restrict answers to sermon content
4. **Tone**: Set appropriate church/spiritual tone
5. **Format**: Define citation format and markdown usage
6. **Error Handling**: Specify response when information unavailable

**Few-Shot Examples (optional enhancement):**
Can add example Q&A pairs to the system prompt for consistency

**Temperature Setting**: 0.7 (balanced between creativity and consistency)

**Token Limits**: Max 1000 tokens to ensure timely responses

---

#### Embedding Model Selection

**Model: `text-embedding-3-small`**
- Dimension: 1536
- Cost: ~1/5th of text-embedding-3-large
- Performance: Sufficient for semantic search
- Latency: ~100-200ms per embedding

**Alternative Considered: `text-embedding-3-large`**
- Dimension: 3072
- Superior accuracy but higher cost and latency
- Recommended if accuracy becomes critical

### Security Considerations

### Authentication & Authorization

```python
class AskWingAIPermission(permissions.BasePermission):
    """Only authenticated users can access Ask Wing AI"""
    
    def has_permission(self, request, view):
        # Require JWT authentication
        return bool(request.user and request.user.is_authenticated)

class IsOwnerOrAdmin(permissions.BasePermission):
    """Users can only access their own chat history"""
    
    def has_object_permission(self, request, view, obj):
        return obj.user == request.user or request.user.is_staff
```

**Authentication Flow:**
1. User authenticates via email/password
2. Backend issues JWT token (24-hour lifetime)
3. Token included in Authorization header for all Ask Wing AI requests
4. Middleware validates token on each request
5. Token refresh endpoint available for extended sessions
6. Session logout clears authentication

### API Key Management

```python
# .env file (NEVER in source code)
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxx
OPENAI_ORGANIZATION_ID=org-xxxxxxxxxxxxx
OPENAI_MAX_TOKENS_PER_MINUTE=90000

# settings.py
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
if not OPENAI_API_KEY:
    raise ImproperlyConfigured('OPENAI_API_KEY environment variable not set')

# views.py - Never log API keys
import logging
logger = logging.getLogger('api')

# BAD - Don't do this!
# logger.info(f"OpenAI API call with key: {OPENAI_API_KEY}")

# GOOD - Log safely
logger.info("OpenAI API call completed successfully")
```

**Key Security Practices:**
1. Store in environment variables, never hardcode
2. Use AWS Secrets Manager for production
3. Implement key rotation policy (quarterly)
4. Monitor API key usage via OpenAI dashboard
5. Set organization-level spending limits
6. Use separate keys for dev/staging/production
7. Revoke compromised keys immediately

### Data Sanitization

```python
import re
from typing import Tuple

class DataSanitizationService:
    """Remove personally identifiable information before external processing"""
    
    PII_PATTERNS = {
        'email': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
        'phone': r'(\+\d{1,3}[-.]?)?\d{3}[-.]?\d{3}[-.]?\d{4}',
        'account': r'\b\d{10,20}\b',  # Account numbers
        'name': r'\b[A-Z][a-z]+ [A-Z][a-z]+\b',  # Common names
        'nin': r'\b\d{11}\b',  # Nigerian NIN
        'bvn': r'\b\d{11}\b',  # BVN
    }
    
    def sanitize_question(self, question: str) -> Tuple[str, bool]:
        """
        Remove PII from user question
        
        Returns:
            (sanitized_question, contains_pii)
        """
        sanitized = question
        contains_pii = False
        
        for pii_type, pattern in self.PII_PATTERNS.items():
            matches = re.findall(pattern, question)
            if matches:
                contains_pii = True
                # Replace each match with placeholder
                sanitized = re.sub(pattern, f'[{pii_type.upper()}]', sanitized)
        
        return sanitized, contains_pii
    
    def needs_user_rephrase(self, sanitized: str, original: str) -> bool:
        """
        Check if sanitization changed meaning too much
        """
        # If more than 30% of original was PII, ask user to rephrase
        replacements = len(re.findall(r'\[[A-Z]+\]', sanitized))
        original_length = len(original.split())
        replacement_ratio = replacements / max(original_length, 1)
        
        return replacement_ratio > 0.30

# Usage in view
question = request.data.get('question')
sanitizer = DataSanitizationService()
sanitized_q, has_pii = sanitizer.sanitize_question(question)

if sanitizer.needs_user_rephrase(sanitized_q, question):
    return Response({
        'error': 'Your question contains sensitive information. Please rephrase without personal details.',
        'suggestion': sanitized_q  # Show user the placeholder version
    }, status=status.HTTP_400_BAD_REQUEST)

# Proceed with sanitized question
```

### Input Validation

```python
from rest_framework import serializers

class QuestionSubmissionSerializer(serializers.Serializer):
    question = serializers.CharField(
        max_length=500,  # Reasonable max length
        min_length=5,    # Prevent trivial questions
    )
    previous_message_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        max_length=10  # Max context messages
    )
    
    def validate_question(self, value):
        # Remove extra whitespace
        cleaned = ' '.join(value.split())
        
        # Check for suspicious patterns
        if cleaned.count('?') > 3:
            raise serializers.ValidationError('Question contains too many question marks')
        
        # Prevent injection attacks
        if any(sql_keyword in cleaned.lower() for sql_keyword in ['DROP', 'DELETE', 'INSERT']):
            raise serializers.ValidationError('Invalid question format')
        
        return cleaned
```

### HTTPS/TLS Encryption

```python
# settings.py
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_SECURITY_POLICY = {
    'default-src': ("'self'",),
}
```

**Production Deployment:**
- All API traffic over HTTPS/TLS 1.2+
- Certificate pinning in Flutter app for OpenAI endpoints
- DNS security (DNSSEC)

### Performance Optimization

### Caching Strategy

```python
from django.core.cache import cache
from functools import wraps

class CacheService:
    """Intelligent caching for performance"""
    
    # Cache duration constants
    EMBEDDING_CACHE_TIME = 86400 * 7  # 7 days
    SEARCH_RESULTS_CACHE_TIME = 3600  # 1 hour
    USER_LIMIT_CACHE_TIME = 300  # 5 minutes
    
    def cache_embedding(self, text: str, embedding: List[float]) -> None:
        """Cache generated embeddings to avoid redundant API calls"""
        cache_key = f"embedding:{hash(text)}"
        cache.set(cache_key, embedding, self.EMBEDDING_CACHE_TIME)
    
    def get_cached_embedding(self, text: str) -> Optional[List[float]]:
        cache_key = f"embedding:{hash(text)}"
        return cache.get(cache_key)
    
    def cache_search_results(self, question: str, results: List[Dict]) -> None:
        """Cache search results for identical questions"""
        cache_key = f"search:{hash(question)}"
        cache.set(cache_key, results, self.SEARCH_RESULTS_CACHE_TIME)
    
    def get_cached_search_results(self, question: str) -> Optional[List[Dict]]:
        cache_key = f"search:{hash(question)}"
        return cache.get(cache_key)

# Usage in service
def search_with_cache(question: str) -> List[Dict]:
    cache_service = CacheService()
    
    # Check cache first
    cached_results = cache_service.get_cached_search_results(question)
    if cached_results:
        logger.info(f"Cache hit for question: {question[:50]}...")
        return cached_results
    
    # Cache miss - perform search
    results = VectorSearchService().search(question)
    cache_service.cache_search_results(question, results)
    
    return results
```

### Response Time Targets

| Operation | Target Time | Timeout |
|-----------|------------|---------|
| Vector embedding | < 1 second | 3 seconds |
| Vector search (top-5) | < 2 seconds | 5 seconds |
| GPT-4 response generation | < 8 seconds | 30 seconds |
| Full pipeline end-to-end | < 10 seconds | 15 seconds |

### Database Query Optimization

```python
# Use select_related for foreign keys
SermonEmbedding.objects.select_related(
    'sermon',
    'sermon__speaker',
    'sermon__category'
).filter(sermon__is_active=True)

# Use prefetch_related for reverse relations
Message.objects.prefetch_related(
    'embeddings',
    'speaker'
).all()

# Use values() to fetch only needed fields
Message.objects.values('id', 'title', 'speaker__name').filter(
    embeddings__isnull=False
)

# Pagination for large result sets
from rest_framework.pagination import PageNumberPagination

class ChatMessagePagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = 'page_size'
    max_page_size = 100
```

### Asynchronous Processing

```python
from celery import shared_task
import logging

logger = logging.getLogger('ask_wing_ai')

@shared_task(bind=True, max_retries=3)
def index_sermon_embeddings(self, sermon_id: int):
    """Background task to index sermon embeddings"""
    try:
        message = Message.objects.get(id=sermon_id)
        
        if not message.transcript:
            logger.warning(f"Sermon {sermon_id} has no transcript")
            return
        
        service = EmbeddingService()
        service.index_sermon(sermon_id, message.transcript)
        
        logger.info(f"Successfully indexed sermon {sermon_id}")
        
    except Exception as exc:
        logger.error(f"Error indexing sermon {sermon_id}: {str(exc)}")
        # Retry with exponential backoff: 60s, 120s, 240s
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))
```

---

## Error Handling

### Error Handling Strategy

### Error Hierarchy

```python
class AskWingAIException(Exception):
    """Base exception for Ask Wing AI"""
    pass

class AuthenticationError(AskWingAIException):
    """User not authenticated"""
    pass

class RateLimitExceeded(AskWingAIException):
    """User exceeded daily question limit"""
    pass

class EmbeddingError(AskWingAIException):
    """Error generating embedding"""
    pass

class SearchError(AskWingAIException):
    """Error searching vector index"""
    pass

class ResponseGenerationError(AskWingAIException):
    """Error generating AI response"""
    pass

class DataSanitizationError(AskWingAIException):
    """Error sanitizing user data"""
    pass
```

### Error Responses

```python
# Comprehensive error handling in views

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

class SubmitQuestionView(APIView):
    def post(self, request):
        try:
            # Main logic here
            pass
            
        except AuthenticationError:
            logger.warning(f"Auth failed for user: {request.user}")
            return Response({
                'error': 'Authentication failed',
                'detail': 'Please log in again'
            }, status=status.HTTP_401_UNAUTHORIZED)
        
        except RateLimitExceeded:
            logger.info(f"Rate limit exceeded for user: {request.user.id}")
            return Response({
                'error': 'Daily limit reached',
                'detail': 'You have reached your daily question limit. Try again tomorrow.'
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)
        
        except EmbeddingError as e:
            logger.error(f"Embedding error: {str(e)}")
            return Response({
                'error': 'Service temporarily unavailable',
                'detail': 'Unable to process your question. Please try again later.'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        
        except ResponseGenerationError as e:
            logger.error(f"Response generation error: {str(e)}")
            return Response({
                'error': 'AI response generation failed',
                'detail': 'Unable to generate a response. Please try a different question.'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}", exc_info=True)
            return Response({
                'error': 'An unexpected error occurred',
                'detail': 'Please contact support if this continues'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
```

### Timeout Handling

```python
import signal
import time

class TimeoutHandler:
    """Handle timeouts gracefully"""
    
    def __init__(self, timeout_seconds=30):
        self.timeout_seconds = timeout_seconds
    
    def __enter__(self):
        signal.signal(signal.SIGALRM, self._timeout_handler)
        signal.alarm(self.timeout_seconds)
        return self
    
    def __exit__(self, *args):
        signal.alarm(0)
    
    @staticmethod
    def _timeout_handler(signum, frame):
        raise TimeoutError("Operation exceeded maximum time limit")

# Usage
try:
    with TimeoutHandler(timeout_seconds=30):
        response = generate_ai_response(question, context)
except TimeoutError:
    logger.error("Response generation timed out")
    return Response({
        'error': 'Response generation took too long',
        'suggestion': 'Try rephrasing your question'
    }, status=status.HTTP_504_GATEWAY_TIMEOUT)
```

---

## Testing Strategy

### Unit Tests

```python
from django.test import TestCase
from rest_framework.test import APITestCase
from unittest.mock import patch, MagicMock

class EmbeddingServiceTests(TestCase):
    def test_generate_embedding_returns_vector(self):
        service = EmbeddingService()
        text = "What is faith?"
        
        with patch('openai.Embedding.create') as mock_embed:
            mock_embed.return_value = {
                'data': [{'embedding': [0.1] * 1536}]
            }
            embedding = service.generate_embedding(text)
        
        self.assertEqual(len(embedding), 1536)
    
    def test_chunk_transcript_respects_overlap(self):
        service = EmbeddingService()
        text = "Word. " * 500  # Approximately 2500 chars
        
        chunks = service.chunk_transcript(text, chunk_size=1000, overlap=200)
        
        self.assertGreater(len(chunks), 1)
        # Verify overlap exists
        for i in range(len(chunks) - 1):
            self.assertTrue(chunks[i][-200:] in chunks[i+1])

class DataSanitizationTests(TestCase):
    def test_removes_email_addresses(self):
        service = DataSanitizationService()
        question = "My email is test@example.com. What about faith?"
        
        sanitized, has_pii = service.sanitize_question(question)
        
        self.assertTrue(has_pii)
        self.assertNotIn('test@example.com', sanitized)
        self.assertIn('[EMAIL]', sanitized)
    
    def test_removes_nin(self):
        service = DataSanitizationService()
        question = "My NIN is 12345678901 and I want to know about repentance"
        
        sanitized, has_pii = service.sanitize_question(question)
        
        self.assertTrue(has_pii)
        self.assertNotIn('12345678901', sanitized)
```

#### Integration Tests

```python
class AskWingAIIntegrationTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='test@tcgc.com',
            password='testpass123',
            is_active=True
        )
        
        self.speaker = Speaker.objects.create(
            name='Pastor John',
            title='Pastor'
        )
        
        self.message = Message.objects.create(
            title='Living by Faith',
            description='A sermon about faith',
            speaker=self.speaker,
            category=MessageCategory.objects.create(name='Faith'),
            transcript='This is a sermon about faith and how to live it daily.',
            date=timezone.now(),
            duration_minutes=30
        )
    
    @patch('services.OpenAIClient.generate_response')
    @patch('services.VectorSearchService.search')
    def test_submit_question_end_to_end(self, mock_search, mock_generate):
        # Setup mocks
        mock_search.return_value = [
            {
                'sermon_id': self.message.id,
                'sermon_title': 'Living by Faith',
                'speaker_name': 'Pastor John',
                'text_chunk': 'Faith is trust in God',
                'estimated_timestamp': '05:30'
            }
        ]
        
        mock_generate.return_value = {
            'response': 'Faith means trusting God...',
            'citations': [
                {
                    'sermon_title': 'Living by Faith',
                    'speaker_name': 'Pastor John',
                    'timestamp': '05:30'
                }
            ]
        }
        
        # Login
        self.client.force_authenticate(user=self.user)
        
        # Submit question
        response = self.client.post(
            '/api/ask-wing-ai/questions',
            {'question': 'What does the Bible say about faith?'},
            format='json'
        )
        
        self.assertEqual(response.status_code, 200)
        self.assertIn('response', response.data)
        self.assertIn('citations', response.data)
```

##### Property-Based Tests

```python
from hypothesis import given, strategies as st
from hypothesis.strategies import sampled_from

class PropertyBasedTests(TestCase):
    @given(st.text(min_size=5, max_size=500))
    def test_sanitization_preserves_meaning(self, question):
        """Sanitization should remove PII but preserve general meaning"""
        service = DataSanitizationService()
        sanitized, _ = service.sanitize_question(question)
        
        # Original and sanitized should have similar word count
        original_words = len(question.split())
        sanitized_words = len(sanitized.split())
        
        # Allow up to 50% word reduction (for PII replacement)
        self.assertGreater(sanitized_words, original_words * 0.5)
    
    @given(st.integers(min_value=100, max_value=50000))
    def test_embedding_generation_consistency(self, seed):
        """Same text should generate identical embeddings"""
        service = EmbeddingService()
        text = f"Test question {seed}"
        
        with patch('openai.Embedding.create') as mock_embed:
            embedding1 = [0.1] * 1536
            embedding2 = [0.1] * 1536
            
            mock_embed.return_value = {'data': [{'embedding': embedding1}]}
            result1 = service.generate_embedding(text)
            
            mock_embed.return_value = {'data': [{'embedding': embedding2}]}
            result2 = service.generate_embedding(text)
        
        self.assertEqual(result1, result2)
```



### Deployment Architecture

#### Production Deployment Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    Cloud Infrastructure                      │
├─────────────────────────────────────────────────────────────┤
│  AWS / DigitalOcean / Cloud Provider (Choose One)           │
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ Application      │         │   Database       │          │
│  │ Servers (4-6)    │         │   PostgreSQL     │          │
│  │ - Django + Gunic │◄───────►│ + pgvector       │          │
│  │ - Auto-scaling   │         │ + IVFFlat Index  │          │
│  └──────────────────┘         └──────────────────┘          │
│         ▲                               ▲                     │
│         │ Load Balancer                │ Primary             │
│         │                              │                     │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ CDN (CloudFront) │         │   Read Replica   │          │
│  │ Cache responses  │         │   (optional)     │          │
│  └──────────────────┘         └──────────────────┘          │
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ Message Queue    │         │ Cache Layer      │          │
│  │ (Celery+Redis)   │         │ (Redis)          │          │
│  │ - Background     │         │ - Session cache  │          │
│  │   jobs           │         │ - Search cache   │          │
│  └──────────────────┘         └──────────────────┘          │
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ Monitoring       │         │ Log Aggregation  │          │
│  │ (CloudWatch/     │         │ (ELK Stack or    │          │
│  │  DataDog)        │         │  CloudWatch)     │          │
│  └──────────────────┘         └──────────────────┘          │
│                                                               │
│  ┌──────────────────────────────────────────────┐            │
│  │  External Services Integration                │            │
│  │  - OpenAI API (with circuit breaker)         │            │
│  │  - Firebase Cloud Messaging (notifications)  │            │
│  └──────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

#### Environment Configuration

**Development:**
```bash
# .env.development
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
OPENAI_API_KEY=sk-test-xxxxx
DB_ENGINE=django.db.backends.postgresql
DB_HOST=localhost
DB_PORT=5432
DB_NAME=tcgc_dev
CELERY_BROKER_URL=redis://localhost:6379/0
```

**Staging:**
```bash
# .env.staging
DEBUG=False
ALLOWED_HOSTS=staging-api.tcgc.thecitygatechurch.org
OPENAI_API_KEY=sk-test-xxxxx
DB_ENGINE=django.db.backends.postgresql
DB_HOST=staging-db.c123456.ng.0001.use1.cache.amazonaws.com
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
```

**Production:**
```bash
# .env.production (stored in AWS Secrets Manager)
DEBUG=False
ALLOWED_HOSTS=api.thecitygatechurch.org
OPENAI_API_KEY=sk-prod-xxxxx
DB_ENGINE=django.db.backends.postgresql
DB_HOST=prod-db-cluster.c123456.ng.0001.use1.cache.amazonaws.com
DB_PORT=5432
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
```

#### Deployment Process

**1. Code Deployment**
```bash
# Push code to main branch
git push origin main

# CI/CD pipeline triggers
# - Run linting & tests
# - Build Docker image
# - Push to container registry
# - Deploy to staging
# - Run integration tests
# - Deploy to production (with canary/blue-green)
```

**2. Database Deployment**
```bash
# Run migrations
python manage.py migrate

# Create/update pgvector indices
python manage.py db_shell << EOF
CREATE INDEX idx_sermon_embeddings_vector 
ON sermon_embeddings 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
EOF
```

**3. Background Worker Deployment**
```bash
# Deploy Celery workers
celery -A tcgc_backend worker -l info --concurrency=4

# Deploy Celery beat scheduler
celery -A tcgc_backend beat -l info
```

#### Scaling Considerations

**Horizontal Scaling:**
- Application servers scale behind load balancer
- Database read replicas for heavy query loads
- Redis cluster for cache/session scalability
- Celery worker scaling via container orchestration (ECS/Kubernetes)

**Vertical Scaling Limits:**
- PostgreSQL: Up to ~32 connections per application instance
- Redis: Up to 10,000 concurrent clients per instance
- API response time vs database query time tradeoffs

**Auto-Scaling Policies:**
```python
# CloudWatch Auto-Scaling
ASG_MIN_CAPACITY = 4
ASG_MAX_CAPACITY = 12
ASG_TARGET_CPU_UTILIZATION = 70%
ASG_SCALE_UP_THRESHOLD = 80%
ASG_SCALE_DOWN_THRESHOLD = 40%
```

### Rate Limiting Implementation

### Daily Question Limits

```python
class RateLimiterService:
    """Enforce question submission limits"""
    
    DAILY_LIMIT = 50  # Configurable per user tier
    WINDOW_SECONDS = 86400  # 24 hours
    
    def check_rate_limit(self, user_id: int) -> Tuple[bool, Dict]:
        """
        Check if user can submit another question
        
        Returns:
            (is_allowed, limit_info)
        """
        cache_key = f"rate_limit:{user_id}"
        current_count = cache.get(cache_key, 0)
        
        remaining = self.DAILY_LIMIT - current_count
        
        if remaining <= 0:
            reset_time = cache.ttl(cache_key)
            return False, {
                'remaining': 0,
                'limit': self.DAILY_LIMIT,
                'reset_time': reset_time,
                'message': f'Daily limit reached. Reset in {reset_time} seconds.'
            }
        
        return True, {
            'remaining': remaining,
            'limit': self.DAILY_LIMIT,
            'reset_time': self.WINDOW_SECONDS,
            'message': f'You have {remaining} questions remaining today.'
        }
    
    def increment_usage(self, user_id: int) -> None:
        """Record a question submission"""
        cache_key = f"rate_limit:{user_id}"
        cache.incr(cache_key)
        cache.expire(cache_key, self.WINDOW_SECONDS)
```

### Premium Tier Benefits (Future)

```python
RATE_LIMIT_TIERS = {
    'free': {'daily': 10, 'monthly': 100},
    'premium': {'daily': 100, 'monthly': 2000},
    'enterprise': {'daily': 1000, 'monthly': 50000},
}
```

### Monitoring and Analytics

### Key Metrics to Track

```python
class MetricsCollector:
    """Collect performance and usage metrics"""
    
    # Response time metrics
    METRIC_RESPONSE_TIME = 'ask_wing_ai.response_time_ms'
    METRIC_SEARCH_TIME = 'ask_wing_ai.search_time_ms'
    METRIC_EMBEDDING_TIME = 'ask_wing_ai.embedding_time_ms'
    METRIC_LLM_TIME = 'ask_wing_ai.llm_time_ms'
    
    # Usage metrics
    METRIC_QUESTIONS_SUBMITTED = 'ask_wing_ai.questions_submitted'
    METRIC_RATE_LIMIT_HITS = 'ask_wing_ai.rate_limit_exceeded'
    METRIC_AUTHENTICATION_FAILURES = 'ask_wing_ai.auth_failures'
    
    # Quality metrics
    METRIC_RESPONSE_ACCURACY = 'ask_wing_ai.response_accuracy'
    METRIC_USER_SATISFACTION = 'ask_wing_ai.user_satisfaction'
    METRIC_API_ERRORS = 'ask_wing_ai.api_errors'
    
    def record_response_time(self, duration_ms: int, tags: Dict = None):
        """Record API response time"""
        statsd.timer(self.METRIC_RESPONSE_TIME, duration_ms, tags=tags)
    
    def record_question_submitted(self, user_id: int):
        """Record question submission"""
        statsd.increment(self.METRIC_QUESTIONS_SUBMITTED, tags={'user_id': user_id})
    
    def record_error(self, error_type: str, message: str):
        """Record API error"""
        statsd.increment(self.METRIC_API_ERRORS, tags={'error_type': error_type})
```

### Logging Best Practices

```python
import structlog

# Structured logging with context
logger = structlog.get_logger(__name__)

logger.info(
    'question_submitted',
    user_id=request.user.id,
    question_length=len(question),
    session_id=session.id,
    timestamp=timezone.now().isoformat()
)

logger.warning(
    'rate_limit_exceeded',
    user_id=user_id,
    daily_used=daily_used,
    daily_limit=daily_limit,
    timestamp=timezone.now().isoformat()
)

logger.error(
    'openai_api_error',
    error_type='RateLimitError',
    retry_after=retry_after,
    timestamp=timezone.now().isoformat()
)
```

### Alerting Rules

```yaml
# Prometheus alert rules
groups:
  - name: ask_wing_ai
    rules:
      - alert: HighResponseTime
        expr: rate(ask_wing_ai_response_time_ms[5m]) > 10000
        for: 5m
        annotations:
          summary: "Ask Wing AI response time > 10 seconds"
      
      - alert: HighErrorRate
        expr: rate(ask_wing_ai_errors_total[5m]) > 0.05
        for: 5m
        annotations:
          summary: "Ask Wing AI error rate > 5%"
      
      - alert: OpenAIRateLimitApproaching
        expr: openai_requests_per_minute > 80
        for: 2m
        annotations:
          summary: "OpenAI rate limit threshold (90 RPM) approaching"
```

### API Documentation

### OpenAPI/Swagger Integration

```python
# settings.py
INSTALLED_APPS = [
    # ... other apps
    'drf_spectacular',
]

SPECTACULAR_SETTINGS = {
    'TITLE': 'Ask Wing AI API',
    'DESCRIPTION': 'AI-powered sermon Q&A system',
    'VERSION': '1.0.0',
    'SERVERS': [
        {'url': 'https://api.thecitygatechurch.org', 'description': 'Production'},
        {'url': 'https://staging-api.thecitygatechurch.org', 'description': 'Staging'},
    ],
}

# urls.py
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema')),
]
```

### Request/Response Examples

**Example 1: Simple Question**
```bash
curl -X POST https://api.thecitygatechurch.org/api/ask-wing-ai/questions \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5..." \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What does the Bible say about forgiveness?"
  }'

# Response
{
  "message_id": 789,
  "question": "What does the Bible say about forgiveness?",
  "response": "The Bible teaches extensively about forgiveness...",
  "citations": [
    {
      "sermon_title": "The Power of Forgiveness",
      "speaker": "Pastor Mark",
      "timestamp": "12:45",
      "sermon_id": 123
    }
  ],
  "processing_time_ms": 7250,
  "timestamp": "2024-01-15T10:45:32Z"
}
```

**Example 2: Follow-up Question**
```bash
curl -X POST https://api.thecitygatechurch.org/api/ask-wing-ai/questions \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5..." \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How do I practice forgiveness in my daily life?",
    "previous_message_ids": [788, 789]
  }'
```

### Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
1. Set up database schema (models + indexes)
2. Implement authentication/authorization
3. Build basic API endpoints structure
4. Set up Celery for background jobs

### Phase 2: Core RAG Pipeline (Weeks 3-4)
1. Implement embedding service (OpenAI integration)
2. Implement vector search (pgvector queries)
3. Implement response generation (GPT-4 integration)
4. Build data sanitization service

### Phase 3: Frontend Integration (Weeks 5-6)
1. Design FAB and chat interface
2. Implement state management (Cubit)
3. Build message display with citations
4. Implement message persistence (local/session)

### Phase 4: Quality & Polish (Weeks 7-8)
1. Rate limiting implementation
2. Error handling & recovery
3. Performance optimization
4. Security audit & fixes
5. Comprehensive testing
6. Documentation completion

### Phase 5: Deployment & Monitoring (Week 9)
1. Set up production infrastructure
2. Implement monitoring & alerting
3. Load testing
4. Staged rollout (canary → production)

### Maintenance & Operations

### Backup Strategy

```bash
# Daily automated backups
0 2 * * * pg_dump -h $DB_HOST -U $DB_USER $DB_NAME | \
  gzip | \
  aws s3 cp - s3://backups/tcgc-db-$(date +%Y%m%d).sql.gz

# Retention: 30 days in S3, 7 days in S3 Glacier
```

### Index Maintenance

```sql
-- Rebuild pgvector indices monthly
REINDEX INDEX CONCURRENTLY idx_sermon_embeddings_vector;

-- Analyze table statistics
ANALYZE sermon_embeddings;

-- Vacuum for cleanup
VACUUM (ANALYZE) sermon_embeddings;
```

### Log Retention

- Application logs: 30 days in CloudWatch
- Moderation logs: 90 days (for compliance)
- Error logs: Indefinite (S3 archive)

### Cost Estimation

### Monthly Costs (Estimated)

| Component | Usage | Cost |
|-----------|-------|------|
| OpenAI GPT-4 | 5,000 questions @ $0.03/1K tokens | $150 |
| OpenAI Embeddings | 10,000 embeddings @ $0.02/1M | $0.20 |
| PostgreSQL (database) | 100GB, t3.large instance | $400 |
| Compute (Django servers) | 6 × t3.medium | $600 |
| Redis cache | r6g.large | $200 |
| Data transfer | 50GB outbound | $100 |
| **Total Estimated** | | **$1,450/month** |

**Cost Optimization:**
- Use OpenAI batch API for off-peak indexing
- Implement aggressive caching (reduces API calls)
- Use PostgreSQL read replicas only if needed

### Future Enhancements

1. **Multi-language Support**: Translate questions and responses
2. **Audio Playback Integration**: Direct links to sermon player at timestamp
3. **Smart Suggestions**: Suggest related questions based on history
4. **User Feedback Loop**: Rate response accuracy for continuous improvement
5. **Advanced Analytics**: User engagement metrics and trending questions
6. **Team Q&A Mode**: Moderators can provide canonical answers
7. **Sermon Series Context**: Understand series themes for better context
8. **Mobile Optimization**: Specifically optimized mobile UI/UX

### Conclusion

This design document provides comprehensive technical specifications for implementing Ask Wing AI. The architecture prioritizes security, performance, and maintainability while leveraging proven technologies (Django, PostgreSQL, OpenAI, React Native).

**Key Success Factors:**
1. Robust data sanitization to protect user privacy
2. Efficient vector search to maintain response times
3. Comprehensive monitoring for operational visibility
4. Staged rollout for risk mitigation
5. Strong error handling for reliability

The implementation can proceed in phases, with foundational work in weeks 1-2, followed by core features in weeks 3-6, and final deployment in week 9.


---

## Correctness Properties

### Overview and Property-Based Testing Assessment

This feature is primarily an integration between multiple systems (Flutter UI, Django API, OpenAI, PostgreSQL vector database). Most acceptance criteria test UI interactions, infrastructure setup, and API contracts—areas where property-based testing (PBT) is not ideal.

However, **specific pure logic components ARE suitable for PBT**:
- **Data sanitization**: Pattern matching and PII removal
- **Vector search ranking**: Semantic similarity ordering
- **Citation formatting**: Format consistency rules
- **Rate limiting**: Counter management and reset logic
- **Chat history management**: Message ordering and persistence
- **Message validation**: Input constraints

These core logic components can be tested with universal properties, while infrastructure and UI aspects should use example-based tests, integration tests, and E2E tests.

### Testable Properties for Pure Logic Components

### Property 1: Data Sanitization Removes All PII Types

*For any* question text containing personally identifiable information (email addresses, phone numbers, account numbers, NIN, or names), the sanitization function SHALL remove or replace each PII instance with a placeholder token, and the output SHALL NOT contain the original PII value.

**Validates: Requirements 14.1, 14.2, 14.3, 14.6**

### Property 2: Sanitized Questions Preserve Core Meaning

*For any* valid question text that contains PII, after sanitization, the question SHALL remain semantically meaningful (word count reduction should not exceed 40% of original, ensuring the actual question is not destroyed by sanitization).

**Validates: Requirements 14.5**

### Property 3: Vector Search Returns Results Ordered by Similarity

*For any* valid question and sermon embedding database, the vector search results SHALL be ordered by descending cosine similarity score, such that result[i].similarity >= result[i+1].similarity for all consecutive pairs in the top-k results.

**Validates: Requirements 5.4**

### Property 4: Citations Include Required Metadata

*For any* generated AI response that references sermon content, each citation object SHALL contain all required fields: sermon_title, speaker_name, timestamp in MM:SS format, and sermon_id. If any field is missing, the citation SHALL be excluded from the response.

**Validates: Requirements 6.2, 6.7, 7.1**

### Property 5: Timestamps Respect Sermon Duration Bounds

*For any* sermon with a known duration_minutes field, all generated timestamps SHALL be less than or equal to duration_minutes * 60 seconds, and greater than or equal to 0 seconds. Timestamps outside this range SHALL be rejected.

**Validates: Requirements 7.4**

### Property 6: Citation Format Is Consistent

*For any* two different citations in the same response, both SHALL follow the identical format pattern: "[Sermon Title] by [Speaker Name] at [MM:SS]". No two citations in the same response SHALL have different formatting styles.

**Validates: Requirements 6.3, 7.2**

### Property 7: Messages Added to Session Are Retrievable

*For any* chat session, after adding a message (question or AI response) with content C, retrieving the session history SHALL return a message with identical content C. Messages added SHALL not be lost or modified.

**Validates: Requirements 9.1, 9.3**

### Property 8: Chat History Maintains Chronological Order

*For any* chat session with multiple messages, retrieving the chat history SHALL return messages in strict chronological order (oldest message first, newest message last). No reordering OR mixing of message sequence SHALL occur.

**Validates: Requirements 9.5, 17.5**

### Property 9: Rate Limit Counter Prevents Exceeding Daily Limit

*For any* user with a daily_limit of N questions, submitting N+1 questions within a 24-hour window SHALL result in the (N+1)th submission being rejected with a rate limit error. No more than N questions per user per day SHALL be accepted.

**Validates: Requirements 11.1, 11.3, 11.6**

### Property 10: Rate Limit Resets Exactly Once Per Day

*For any* user's rate limit counter on a given calendar day, incrementing questions from 0 to N within that day SHALL reach N. On the next calendar day (after midnight UTC), incrementing a fresh question SHALL succeed and reset the counter to 1, regardless of the previous day's count.

**Validates: Requirements 11.7**

### Property 11: Unauthenticated Requests Denied Access

*For any* HTTP request to Ask Wing AI endpoints without a valid JWT authentication token, the system SHALL return a 401 Unauthorized response. Unauthenticated requests SHALL NEVER reach the business logic layer.

**Validates: Requirements 2.1, 2.5**

### Property 12: Authenticated Users Gain Chat Access

*For any* user with a valid, non-expired JWT token, the authentication check SHALL succeed and the Chat_Interface SHALL become accessible. All authenticated users (regardless of other attributes) SHALL have access to Ask Wing AI.

**Validates: Requirements 2.3, 2.6**

### Property 13: Markdown Formatting Renders Correctly

*For any* valid markdown syntax (bold: **text**, italics: *text*, bullets: - item, numbered: 1. item), the response formatter SHALL parse and convert to proper display representations. Test by round-tripping: parse(format(markdown)) == markdown.

**Validates: Requirements 8.1, 8.2, 8.4, 8.5**

### Property 14: Empty Question Submission Rejected

*For any* input question that is empty, all-whitespace, or below the minimum length (< 5 characters), the system SHALL reject submission with a validation error. No empty questions SHALL ever reach the embedding or search services.

**Validates: Requirements 4.4**

### Property 15: Input Validation Prevents SQL Injection

*For any* user question containing SQL keywords (DROP, DELETE, INSERT, etc.) or suspicious patterns, the validation layer SHALL detect and reject the input before forwarding to the database or external APIs. Dangerous SQL keywords SHALL not reach backend services.

**Validates: Requirements 12.4, 13.6**

### Property 16: Questions Logged With User ID and Timestamp

*For any* submitted question, the moderation log entry SHALL contain the question text, associated user_id, and a valid ISO 8601 timestamp. All three fields SHALL be present and non-null in stored log records.

**Validates: Requirements 10.1, 10.4**

### Property 17: Follow-up Questions Include Previous Context

*For any* chat session with previous messages and a new follow-up question referencing a previous context, the context manager SHALL include the full previous message thread in the GPT-4 request. The context list SHALL have length > 0 when follow-up messages are submitted.

**Validates: Requirements 17.1, 17.3**

### Property 18: Credentials Never Appear in Logs

*For any* log entry containing request/response data, the log line SHALL NOT contain the literal OpenAI API key, database password, or JWT tokens in plain text. Credential strings SHALL be masked (e.g., "sk-xxx...xxx") or excluded from logs entirely.

**Validates: Requirements 13.3, 13.4**

### Property 19: Embedding Vectors Have Correct Dimension

*For any* question submitted to the embedding service, the resulting embedding vector SHALL have exactly 1536 dimensions (matching OpenAI's text-embedding-3-small output). Embeddings with incorrect dimensions SHALL be rejected immediately.

**Validates: Requirements 5.1**

### Property 20: Session-Only Chat History Clears on Close

*For any* chat session that is closed, reopening a NEW session for the same user SHALL start with an empty message history. Previous session's messages SHALL not carry over to new sessions.

**Validates: Requirements 9.4, 23.3, 23.5**

---

## Testing Strategy (Detailed)

### Unit Tests (Pure Logic Components)

**Test Data Sanitization**
```python
# Property-based test
@given(st.text(min_size=5, max_size=500))
def test_sanitization_removes_pii(question):
    sanitizer = DataSanitizationService()
    sanitized, has_pii = sanitizer.sanitize_question(question)
    
    # If input contains known PII patterns, output should not
    if '@' in question:  # Email pattern
        assert '@' not in sanitized
    if any(char.isdigit() for char in question):  # Potential NIN
        # Verify PII placeholders used
        assert '[' in sanitized or not has_pii

# Example-based test
def test_sanitization_email():
    sanitizer = DataSanitizationService()
    sanitized, has_pii = sanitizer.sanitize_question('My email is test@example.com')
    assert 'test@example.com' not in sanitized
    assert has_pii
```

**Test Vector Search Ordering**
```python
# Property test
@given(st.integers(min_value=1, max_value=10))
def test_search_results_ordered_by_similarity(k):
    service = VectorSearchService()
    results = service.search("test question", top_k=k)
    
    # Check ordering
    for i in range(len(results) - 1):
        assert results[i]['similarity_score'] >= results[i+1]['similarity_score']
```

**Test Rate Limiting**
```python
# Property test
@given(st.integers(min_value=5, max_value=50))
def test_rate_limit_enforced(daily_limit):
    limiter = RateLimiterService(daily_limit=daily_limit)
    user_id = 1
    
    # Should succeed for 0 to daily_limit questions
    for i in range(daily_limit):
        allowed, _ = limiter.check_rate_limit(user_id)
        assert allowed
        limiter.increment_usage(user_id)
    
    # Should fail for daily_limit + 1
    allowed, _ = limiter.check_rate_limit(user_id)
    assert not allowed
```

### Integration Tests

```python
class AskWingAIIntegrationTests(APITestCase):
    """End-to-end tests for question submission pipeline"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            email='test@tcgc.com',
            password='testpass123'
        )
        self.sermon = create_test_sermon_with_embeddings()
    
    def test_question_submission_end_to_end(self):
        """Full pipeline: submit question → search → generate response"""
        self.client.force_authenticate(user=self.user)
        
        response = self.client.post(
            '/api/ask-wing-ai/questions',
            {'question': 'What is faith?'},
            format='json'
        )
        
        self.assertEqual(response.status_code, 200)
        self.assertIn('response', response.data)
        self.assertIn('citations', response.data)
        self.assertTrue(len(response.data['citations']) > 0)
    
    def test_authentication_required(self):
        """Unauthenticated requests should be rejected"""
        response = self.client.post(
            '/api/ask-wing-ai/questions',
            {'question': 'What is faith?'},
            format='json'
        )
        
        self.assertEqual(response.status_code, 401)
    
    def test_rate_limiting_enforced(self):
        """User cannot exceed daily question limit"""
        self.client.force_authenticate(user=self.user)
        
        # Submit exactly limit questions
        for i in range(50):
            response = self.client.post(
                '/api/ask-wing-ai/questions',
                {'question': f'Question {i}?'},
                format='json'
            )
            self.assertEqual(response.status_code, 200)
        
        # One more should fail
        response = self.client.post(
            '/api/ask-wing-ai/questions',
            {'question': 'One too many?'},
            format='json'
        )
        self.assertEqual(response.status_code, 429)  # Too Many Requests
```

### E2E Tests (Flutter)

```dart
void main() {
  group('Ask Wing AI Feature', () {
    testWidgets('User can submit question through chat interface', (WidgetTester tester) async {
      // Build app and trigger frame
      await tester.pumpWidget(const MyApp());
      
      // Tap FAB
      await tester.tap(find.byIcon(Icons.comment));
      await tester.pumpAndSettle();
      
      // Type question
      await tester.enterText(
        find.byType(TextField),
        'What is repentance?'
      );
      
      // Tap send
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 15));
      
      // Verify response appears
      expect(find.byType(ChatMessage), findsWidgets);
      expect(find.text('repentance'), findsWidgets);
    });
    
    testWidgets('Unauthenticated user cannot access chat', (WidgetTester tester) async {
      // Mock auth as logged out
      when(() => authRepository.isAuthenticated()).thenReturn(false);
      
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.byIcon(Icons.comment));
      await tester.pumpAndSettle();
      
      // Should redirect to login
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
```

### Performance Tests

```python
def test_response_time_under_10_seconds():
    """Response time should be < 10 seconds"""
    question = "What is faith?"
    start = time.time()
    
    service = AskWingAIService()
    response = service.process_question(question)
    
    duration = time.time() - start
    assert duration < 10, f"Response took {duration}s, expected < 10s"
```

### Security Tests

```python
def test_pii_not_sent_to_openai():
    """Verify PII is removed before OpenAI call"""
    question = "My email is test@example.com. What is faith?"
    
    with patch('openai.ChatCompletion.create') as mock_openai:
        service = ResponseGeneratorService()
        service.generate_response(question, [], [])
        
        # Get the actual call arguments
        call_args = mock_openai.call_args
        messages = call_args[1]['messages']
        full_text = ' '.join([m['content'] for m in messages])
        
        # Verify PII not present
        assert 'test@example.com' not in full_text
        assert '[EMAIL]' in full_text or '@' not in full_text
```

---

## Summary

**Ask Wing AI** is a comprehensive feature integrating:
- Flutter UI components with state management
- Django REST API with authentication and rate limiting
- OpenAI integration (GPT-4 + embeddings)
- PostgreSQL with pgvector for semantic search
- Background job processing (Celery)

**Design Approach:**
- Security-first: Authentication, authorization, data sanitization
- Performance-optimized: Vector caching, query optimization, async processing
- User-centric: Clear error messages, loading states, helpful guidance
- Monitoring-ready: Comprehensive logging, metrics, alerting

**Testing Strategy:**
- Property-based tests for pure logic (sanitization, ranking, formatting, rate limiting)
- Example-based unit tests for API contracts and error cases
- Integration tests for end-to-end question-answer flows
- E2E tests for UI interactions
- Performance and security tests for SLA verification

**Implementation Timeline:** 9 weeks (foundation → core → frontend → polish → deployment)

The design is implementation-ready and provides clear guidance for the development team across all layers of the system.
