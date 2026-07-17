# Ask Wing AI - Flutter Integration Guide

## ✅ What's Been Created

### **Complete Flutter Implementation (Phases 10-13)**

**Data Models (3 files)**
- `lib/data/models/ask_wing_ai/chat_message_model.dart`
- `lib/data/models/ask_wing_ai/ask_wing_ai_response_model.dart`

**Services (1 file)**
- `lib/data/services/ask_wing_ai_service.dart`

**State Management (2 files)**
- `lib/presentation/bloc/ask_wing_ai/ask_wing_ai_state.dart`
- `lib/presentation/bloc/ask_wing_ai/ask_wing_ai_cubit.dart`

**Pages (1 file)**
- `lib/presentation/pages/ask_wing_ai/ask_wing_ai_chat_page.dart`

**Widgets (7 files)**
- `lib/presentation/widgets/ask_wing_ai/ask_wing_ai_fab.dart` ✅
- `lib/presentation/widgets/ask_wing_ai/chat_message_list.dart` ✅
- `lib/presentation/widgets/ask_wing_ai/chat_message_bubble.dart` ✅
- `lib/presentation/widgets/ask_wing_ai/chat_input_field.dart` ✅
- `lib/presentation/widgets/ask_wing_ai/welcome_message.dart` ✅
- `lib/presentation/widgets/ask_wing_ai/rate_limit_indicator.dart` ✅
- `lib/presentation/widgets/ask_wing_ai/citation_card.dart` ✅
- `lib/presentation/widgets/ask_wing_ai/loading_indicator.dart` ✅

---

## 📦 Step 1: Update pubspec.yaml

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  
  # HTTP & API
  http: ^1.1.0
  
  # Markdown Rendering
  flutter_markdown: ^0.6.18
  
  # Existing dependencies...
  # (keep all your current dependencies)
```

Then run:
```bash
flutter pub get
```

---

## 🔧 Step 2: Update API Constants

Create or update `lib/core/constants/api_constants.dart`:

```dart
class ApiConstants {
  static const String baseUrl = 'http://your-backend-url.com'; // Update this
  
  // Ask Wing AI endpoints
  static const String askWingAIFeatureStatus = '/api/ask-wing-ai/feature-status';
  static const String askWingAIQuestions = '/api/ask-wing-ai/questions';
  static const String askWingAIHistory = '/api/ask-wing-ai/history';
  static const String askWingAIClear = '/api/ask-wing-ai/clear';
  static const String askWingAILimits = '/api/ask-wing-ai/limits';
}
```

---

## 🚀 Step 3: Initialize the Cubit

### Option A: Global Initialization (in main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import 'data/services/ask_wing_ai_service.dart';
import 'core/services/token_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Your existing blocs...
        
        // Ask Wing AI Cubit
        BlocProvider(
          create: (context) => AskWingAICubit(
            service: AskWingAIService(
              tokenService: context.read<TokenService>(),
            ),
          )..initialize(), // Initialize on app start
        ),
      ],
      child: MaterialApp(
        title: 'TCGC App',
        home: HomePage(),
      ),
    );
  }
}
```

### Option B: Lazy Initialization (when needed)

```dart
// Initialize only when user opens Ask Wing AI
BlocProvider(
  create: (context) => AskWingAICubit(
    service: AskWingAIService(
      tokenService: context.read<TokenService>(),
    ),
  ),
  child: AskWingAIChatPage(),
)
```

---

## 🏠 Step 4: Add FAB to Home Page

Update your `HomePage` to include the Ask Wing AI FAB:

```dart
import 'package:flutter/material.dart';
import 'presentation/widgets/ask_wing_ai/ask_wing_ai_fab.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: YourHomeContent(),
      
      // Add Ask Wing AI FAB
      floatingActionButton: AskWingAIFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
```

---

## 🔐 Step 5: Connect Authentication (Optional)

Update `ask_wing_ai_fab.dart` to check your authentication:

```dart
void _onPressed(BuildContext context, AskWingAIState state) {
  // Check authentication using your auth system
  final authState = context.read<AuthCubit>().state;
  final isAuthenticated = authState is AuthAuthenticated;
  
  if (!isAuthenticated) {
    _showLoginPrompt(context);
    return;
  }

  // ... rest of the code
}
```

---

## 🧪 Step 6: Test Without OpenAI Key

You can test the UI without an OpenAI API key:

### What Works Without API Key:
✅ FAB displays and navigation works
✅ Chat page UI renders correctly
✅ Welcome message displays
✅ Input field works
✅ Feature status check works
✅ Rate limit UI works
✅ Error handling works

### What Needs API Key:
❌ Actual question submission
❌ AI responses
❌ Transcription
❌ Citations

### Testing Steps:

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Test navigation:**
   - Tap the "Ask Wing AI" FAB
   - Chat page should open with welcome message

3. **Test UI:**
   - Type in the input field
   - Send button should enable/disable based on text
   - Menu options should work (Clear History, Help)

4. **Test feature toggle:**
   - If backend feature is disabled, FAB should hide
   - If disabled, appropriate message should show

---

## 🎨 Step 7: Customization

### Change Colors

Update colors in the widgets to match your theme:

```dart
// In chat_message_bubble.dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).primaryColor, // Use your theme color
    borderRadius: BorderRadius.circular(16),
  ),
  // ...
)
```

### Change FAB Text

```dart
// In ask_wing_ai_fab.dart
FloatingActionButton.extended(
  icon: const Icon(Icons.chat_bubble_outline),
  label: const Text('Ask Pastor'), // Change this
  // ...
)
```

### Update Welcome Message

Edit `welcome_message.dart` to customize the welcome screen.

---

## 🐛 Step 8: Troubleshooting

### Problem: "No TokenService found"

**Solution:** Make sure TokenService is provided in your app:

```dart
BlocProvider(
  create: (context) => AskWingAICubit(
    service: AskWingAIService(
      tokenService: TokenService(), // Your existing token service
    ),
  ),
)
```

### Problem: "API call fails"

**Solution:** Check your backend URL in `api_constants.dart`:

```dart
static const String baseUrl = 'http://10.0.2.2:8000'; // For Android emulator
// OR
static const String baseUrl = 'http://localhost:8000'; // For iOS simulator
// OR
static const String baseUrl = 'https://your-domain.com'; // For production
```

### Problem: "Feature toggle doesn't work"

**Solution:** Run the backend migration first:

```bash
cd TCGC_BACKEND
python manage.py makemigrations
python manage.py migrate
```

---

## ✅ Step 9: Verification Checklist

- [ ] Dependencies installed (`flutter pub get`)
- [ ] API constants updated with correct backend URL
- [ ] Cubit initialized in app
- [ ] FAB added to HomePage
- [ ] App runs without errors
- [ ] Can navigate to chat page
- [ ] Welcome message displays
- [ ] Input field works
- [ ] Send button enables/disables correctly
- [ ] Menu options work
- [ ] No compilation errors

---

## 🚀 Step 10: Ready for OpenAI Integration

Once you have an OpenAI API key:

1. **Add to backend .env:**
   ```bash
   OPENAI_API_KEY=sk-your-api-key-here
   ```

2. **Run backend:**
   ```bash
   python manage.py runserver
   ```

3. **Test full flow:**
   - Submit a question in the app
   - Should see "Thinking..." animation
   - Should receive AI response with citations
   - Rate limit should update

---

## 📊 Progress Summary

### ✅ Completed:
- Backend API (100%)
- Backend Feature Toggle (100%)
- Flutter Data Models (100%)
- Flutter Services (100%)
- Flutter State Management (100%)
- Flutter UI Components (100%)
- Flutter Pages (100%)

### ⏳ Remaining:
- Backend testing with OpenAI key
- End-to-end integration testing
- Performance optimization
- Production deployment

---

## 📞 Need Help?

### Common Issues:

**Issue:** FAB not showing
- Check if cubit is initialized
- Check if feature toggle is enabled on backend

**Issue:** Can't submit questions
- Check authentication
- Check network connection
- Check backend is running

**Issue:** Errors in console
- Check backend URL is correct
- Check token service is provided
- Check all dependencies are installed

---

## 🎉 You're Ready!

The Flutter UI is **100% complete** and ready to use! Just:

1. Update `api_constants.dart` with your backend URL
2. Add the FAB to your HomePage
3. Run the app and test the UI

The full feature will work once you:
- Get an OpenAI API key
- Add it to your backend
- Connect your app to the backend

---

**Built with ❤️ for The Covenant Gospel Church**
