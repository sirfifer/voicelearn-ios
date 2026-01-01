# Feedback Feature Architecture Overview

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (Swift)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐         ┌──────────────────┐               │
│  │ SettingsView  │────────▶│  FeedbackView    │               │
│  │               │         │  (SwiftUI Form)  │               │
│  │ - New section │         │  - Category      │               │
│  │ - Nav link    │         │  - Rating (opt)  │               │
│  └───────────────┘         │  - Message       │               │
│                            │  - Submit button │               │
│                            └────────┬─────────┘               │
│                                     │                          │
│                                     ▼                          │
│                          ┌──────────────────┐                 │
│                          │ FeedbackViewModel│                 │
│                          │  (@MainActor)    │                 │
│                          │  - Validation    │                 │
│                          │  - Submission    │                 │
│                          └────────┬─────────┘                 │
│                                   │                            │
│                    ┌──────────────┴──────────────┐            │
│                    ▼                              ▼            │
│         ┌──────────────────┐          ┌─────────────────┐    │
│         │  Core Data       │          │ FeedbackService │    │
│         │  (Feedback)      │          │  (Actor)        │    │
│         │  - Local storage │          │  - HTTP POST    │    │
│         │  - Persistence   │          │  - JSON encode  │    │
│         └──────────────────┘          └────────┬────────┘    │
│                                                 │             │
└─────────────────────────────────────────────────┼─────────────┘
                                                  │
                                                  │ HTTP POST
                                                  │ /api/feedback
                                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│              Management Console (Python/aiohttp)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │             API Endpoint Handler                    │       │
│  │  handle_receive_feedback(request)                   │       │
│  │  - Extract client headers                           │       │
│  │  - Parse JSON payload                               │       │
│  │  - Create FeedbackEntry                             │       │
│  └────────────┬──────────────────┬─────────────────────┘       │
│               │                  │                              │
│               ▼                  ▼                              │
│  ┌─────────────────┐   ┌──────────────────┐                   │
│  │ ManagementState │   │ JSON File        │                   │
│  │ - feedback deque│   │ data/feedback.json│                  │
│  │ - Max 1000      │   │ - Persistent     │                   │
│  └────────┬────────┘   └──────────────────┘                   │
│           │                                                     │
│           │ WebSocket Broadcast                                │
│           ▼                                                     │
│  ┌──────────────────┐                                          │
│  │ WebSocket Server │                                          │
│  │ - Real-time push │                                          │
│  └────────┬─────────┘                                          │
└───────────┼─────────────────────────────────────────────────────┘
            │
            │ WebSocket
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Admin UI (HTML/JavaScript)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────┐            │
│  │         Feedback Tab (index.html)              │            │
│  │  - Category filter dropdown                    │            │
│  │  - Real-time feedback cards                    │            │
│  │  - Device info display                         │            │
│  │  - Rating stars                                │            │
│  └────────────────────────────────────────────────┘            │
│                                                                 │
│  ┌────────────────────────────────────────────────┐            │
│  │         JavaScript (app.js)                    │            │
│  │  - loadFeedback() - Fetch from API             │            │
│  │  - displayFeedback() - Render cards            │            │
│  │  - WebSocket listener - Live updates           │            │
│  └────────────────────────────────────────────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Feedback Submission Flow

```
User fills form → ViewModel validates → Save to Core Data
                                              │
                                              ├─ Success: Mark unsent
                                              │
                                              ▼
                                      Try upload to server
                                              │
                                    ┌─────────┴─────────┐
                                    │                   │
                              Success               Failure
                                    │                   │
                                    ▼                   ▼
                          Mark as submitted    Leave as unsent
                          Show success         Show warning
                          Clear form           (will retry later)
```

### 2. Server Processing Flow

```
POST /api/feedback
      │
      ├─ Extract headers (X-Client-ID, X-Client-Name)
      │
      ├─ Parse JSON body
      │
      ├─ Create FeedbackEntry
      │
      ├─ Append to in-memory deque
      │
      ├─ Broadcast via WebSocket
      │
      ├─ Save to JSON file
      │
      └─ Return 200 OK with {status: "ok", id: "..."}
```

### 3. Admin UI Update Flow

```
Admin opens browser → Load initial feedback via GET /api/feedback
                               │
                               ▼
                      Display feedback cards
                               │
                               ▼
                      WebSocket connected
                               │
                  ┌────────────┴────────────┐
                  │                         │
            New feedback          Filter change
            arrives               selected
                  │                         │
                  ▼                         ▼
         Broadcast event          Fetch filtered data
                  │                         │
                  └────────────┬────────────┘
                               │
                               ▼
                      Update UI in real-time
```

## Data Model Relationships

```
┌──────────────────┐
│    Feedback      │
├──────────────────┤
│ id: UUID         │
│ timestamp: Date  │
│ category: String │───┐ "Bug Report"
│ rating: Int16?   │   │ "Feature Request"
│ message: String  │   │ "Curriculum Content"
│ deviceModel      │   │ "Performance Issue"
│ iOSVersion       │   │ "Audio Quality"
│ appVersion       │   │ "User Interface"
│ submitted: Bool  │   │ "Other"
│ submittedAt      │   │
└────────┬─────────┘   │
         │             │
         │ Optional    │
         │ Relationships
         │             │
    ┌────┴─────┐       │
    │          │       │
    ▼          ▼       │
┌─────────┐ ┌───────┐ │
│ Session │ │ Topic │ │
└─────────┘ └───────┘ │
                       │
          Categories <─┘
```

## API Contract

### POST /api/feedback

**Request Headers**:
```
Content-Type: application/json
X-Client-ID: <UUID from identifierForVendor>
X-Client-Name: <User's device name>
```

**Request Body**:
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "timestamp": "2025-12-30T10:30:00Z",
  "category": "Bug Report",
  "rating": 4,
  "message": "The audio cuts out intermittently during sessions...",
  "sessionId": "abc...",
  "topicId": "def...",
  "deviceModel": "iPhone 17 Pro",
  "iOSVersion": "18.2",
  "appVersion": "1.0.0"
}
```

**Response** (200 OK):
```json
{
  "status": "ok",
  "id": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Response** (400 Bad Request):
```json
{
  "error": "Invalid request: message is required"
}
```

### GET /api/feedback

**Query Parameters**:
- `limit` (optional, default: 100): Maximum number of entries
- `category` (optional): Filter by category

**Response**:
```json
{
  "feedback": [
    {
      "id": "123...",
      "timestamp": "2025-12-30T10:30:00Z",
      "client_id": "ABC123...",
      "client_name": "John's iPhone",
      "category": "Bug Report",
      "rating": 4,
      "message": "The audio cuts out...",
      "device_model": "iPhone 17 Pro",
      "ios_version": "18.2",
      "app_version": "1.0.0",
      "session_id": null,
      "topic_id": null,
      "received_at": 1735558200.123
    }
  ],
  "total": 42,
  "categories": ["Bug Report", "Feature Request", "Audio Quality"]
}
```

### DELETE /api/feedback/{id}

**Response** (200 OK):
```json
{
  "status": "ok"
}
```

## UI Components Breakdown

### iOS FeedbackView

```
┌─────────────────────────────────────────┐
│ ◁  Send Feedback               Cancel   │
├─────────────────────────────────────────┤
│                                         │
│ What is this about?                     │
│ ┌─────────────────────────────────────┐ │
│ │ 🐞 Bug Report               ▾       │ │
│ └─────────────────────────────────────┘ │
│ Select the category that best describes│
│ your feedback.                          │
│                                         │
│ Rating (Optional)                       │
│ Rating   ☆ ☆ ☆ ☆ ☆                    │
│ How would you rate this aspect?        │
│                                         │
│ Your Feedback                           │
│ ┌─────────────────────────────────────┐ │
│ │                                     │ │
│ │ [User types here]                   │ │
│ │                                     │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│ Please share your thoughts, ideas,      │
│ or issues. Be as detailed as you like.  │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │       Submit Feedback                │ │
│ └─────────────────────────────────────┘ │
│ Your feedback helps us improve.         │
│ Device info included automatically.     │
└─────────────────────────────────────────┘
```

### Admin UI Feedback Tab

```
┌─────────────────────────────────────────────────────────┐
│  Logs   Metrics   Clients   Servers   [Feedback]        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Beta Tester Feedback          [All Categories ▾]      │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │ 🐞 Bug Report  ★★★★☆         2 minutes ago       │ │
│  │                                                   │ │
│  │ The audio cuts out intermittently during long    │ │
│  │ sessions. Happens about every 20 minutes.        │ │
│  │                                                   │ │
│  │ 📱 iPhone 17 Pro (iOS 18.2)  👤 John's iPhone    │ │
│  │ 📦 v1.0.0                                         │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │ 💡 Feature Request              10 minutes ago    │ │
│  │                                                   │ │
│  │ Would love to see offline mode for downloaded    │ │
│  │ curriculum!                                       │ │
│  │                                                   │ │
│  │ 📱 iPad Pro 13" (iOS 18.1)  👤 Sarah's iPad      │ │
│  │ 📦 v1.0.0                                         │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## State Management

### iOS ViewModel States

```swift
@Published var category: FeedbackCategory = .other
@Published var rating: Int? = nil           // Optional 1-5
@Published var message: String = ""
@Published var isSubmitting: Bool = false
@Published var showError: Bool = false
@Published var errorMessage: String = ""
@Published var showSuccess: Bool = false
```

### Core Data Entity States

```
New feedback created:
  submitted = false
  submittedAt = nil

After successful upload:
  submitted = true
  submittedAt = Date()

After failed upload:
  submitted = false  (remains)
  submittedAt = nil  (remains)
  [Will retry in background sync - future enhancement]
```

### Server State Management

```python
class ManagementState:
    feedback: deque(maxlen=1000)  # In-memory, last 1000
    # Persistent storage in data/feedback.json
```

## File Structure

```
unamentis/
├── UnaMentis/                           # iOS App
│   ├── Core/
│   │   ├── Feedback/
│   │   │   └── FeedbackModels.swift     [NEW] Enums & types
│   │   └── Persistence/
│   │       └── ManagedObjects/
│   │           └── Feedback+CoreDataClass.swift [NEW]
│   ├── Services/
│   │   └── Feedback/
│   │       └── FeedbackService.swift    [NEW] API client
│   ├── UI/
│   │   ├── Feedback/
│   │   │   ├── FeedbackView.swift       [NEW] SwiftUI form
│   │   │   └── FeedbackViewModel.swift  [NEW] Business logic
│   │   └── Settings/
│   │       └── SettingsView.swift       [MODIFY] Add nav link
│   └── UnaMentis.xcdatamodeld/
│       └── UnaMentis.xcdatamodel/
│           └── contents                 [MODIFY] Add entity
│
├── server/
│   └── management/
│       ├── server.py                    [MODIFY] Add endpoints
│       ├── data/
│       │   └── feedback.json            [NEW] Persistent storage
│       └── static/
│           ├── index.html               [MODIFY] Add tab
│           └── app.js                   [MODIFY] Add logic
│
└── UnaMentisTests/
    └── FeedbackTests.swift              [NEW] Unit tests
```

## Key Design Decisions

### 1. Local-First Architecture
- Feedback saved to Core Data immediately
- Upload attempted but not required for success
- Graceful degradation when server unavailable
- Future: Background sync for unsent feedback

### 2. Minimal User Friction
- No account required
- No login needed
- Optional rating
- Simple form (3 fields)
- One-tap submit

### 3. Privacy-Conscious
- Anonymous device ID (not linked to Apple ID)
- User-chosen device name (can be generic)
- No email, phone, or personal info
- Transparent about data collected (footer text)

### 4. Admin-Friendly
- Real-time updates via WebSocket
- Category filtering
- Rich metadata display
- Persistent storage for analysis

### 5. Scalability
- Deque with max size (memory bounded)
- JSON file persistence (simple, no DB needed)
- WebSocket for efficiency
- Future: Export to CSV for long-term analysis

## Testing Checklist

### Unit Tests
- [ ] FeedbackCategory enum values
- [ ] FeedbackViewModel validation
- [ ] FeedbackService URL construction
- [ ] Core Data entity creation
- [ ] JSON encoding/decoding

### Integration Tests
- [ ] Submit feedback to mock server
- [ ] Handle network errors gracefully
- [ ] Persist feedback to Core Data
- [ ] Load feedback in admin UI

### UI Tests
- [ ] Form renders correctly
- [ ] Category picker works
- [ ] Rating selection works
- [ ] Submit button enables/disables
- [ ] Success/error alerts display

### Accessibility Tests
- [ ] VoiceOver labels correct
- [ ] Dynamic Type support
- [ ] Touch target sizes ≥44pt
- [ ] Color contrast ratios

### Manual Tests
- [ ] Submit from iPhone simulator
- [ ] Submit from iPad simulator
- [ ] View in admin UI (Chrome)
- [ ] Filter by category
- [ ] WebSocket real-time update
- [ ] Offline submission
- [ ] Device info accuracy

## Performance Considerations

### iOS App
- Core Data save: <10ms
- HTTP POST: <500ms (typical)
- UI render: 60fps (no lag)
- Memory: <1MB for feedback feature

### Backend
- API endpoint: <50ms response time
- WebSocket broadcast: <10ms
- JSON file write: <100ms (async)
- Memory: ~100KB per 1000 entries

### Admin UI
- Initial load: <500ms
- Filter operation: <50ms
- WebSocket message: <10ms to update DOM
- Rendering: 1000 feedback cards in <200ms

## Security Considerations

### iOS App
- HTTPS for production (HTTP for dev)
- No sensitive data in feedback
- Device UUID not personally identifiable
- Feedback stored in app sandbox

### Backend
- No authentication (trusted network)
- Input validation on all fields
- JSON size limits (prevent DoS)
- CORS configured for dev/prod

### Admin UI
- View-only (no sensitive operations)
- No XSS vulnerabilities (proper escaping)
- No injection attacks (JSON only)

## Future Enhancements (Not in v1)

### Short-term
- Background sync for unsent feedback
- Screenshot attachment
- Feedback reply from admin
- Mark as resolved/archived

### Medium-term
- Export to CSV
- Feedback analytics (sentiment analysis)
- Tag/label system
- Search functionality

### Long-term
- Email notifications
- Slack integration
- Auto-categorization (ML)
- User feedback portal (view own submissions)

## Success Metrics (6 Months Post-Launch)

- **Adoption**: 60%+ of beta testers submit at least one feedback
- **Engagement**: Average 2.5 feedback submissions per active user
- **Quality**: Average message length >75 characters
- **Reliability**: 98%+ submission success rate
- **Speed**: <500ms median submission latency
- **Satisfaction**: Positive sentiment in meta-feedback about the feature

## Conclusion

This feedback feature is designed to be:
- **Simple**: Minimal friction for users
- **Reliable**: Local-first with graceful degradation
- **Scalable**: Bounded memory, persistent storage
- **Private**: Anonymous, minimal data collection
- **Actionable**: Rich context for admins to prioritize work

The architecture follows UnaMentis patterns (Actor-based services, SwiftUI + MVVM, local-first design) and integrates seamlessly with existing infrastructure.
