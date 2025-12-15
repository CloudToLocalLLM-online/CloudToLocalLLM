# CRITICAL SECURITY ISSUE: Conversation User Isolation

## Problem Identified

**SEVERITY: CRITICAL** 🚨

Local conversations are NOT isolated by user account. All users share the same conversation database without any user filtering.

### Technical Details

1. **Missing User ID Column**: Conversation table has no `user_id` field
2. **No User Filtering**: `loadConversations()` loads ALL conversations regardless of current user
3. **Shared Storage**: All users see each other's private conversations
4. **Privacy Violation**: Sensitive conversation data exposed across user accounts

### Current Schema (BROKEN)
```sql
CREATE TABLE conversations (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  model TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_encrypted INTEGER DEFAULT 0,
  storage_location TEXT DEFAULT 'local'
  -- MISSING: user_id TEXT NOT NULL
);
```

### Current Query (BROKEN)
```dart
// This loads ALL conversations for ALL users!
final conversationRows = await _database!.query(
  _conversationsTable,
  orderBy: 'updated_at DESC',
);
```

## Required Fix

### 1. Database Schema Migration
- Add `user_id` column to conversations table
- Add `user_id` column to messages table  
- Create database migration for existing data

### 2. User Filtering
- Filter all queries by current user ID
- Ensure conversation isolation per user
- Add user validation to all CRUD operations

### 3. Data Migration
- Existing conversations need user assignment
- Consider data cleanup for mixed user data

## Impact

- **Privacy**: Users can see other users' private conversations
- **Security**: Sensitive data exposed across accounts
- **Compliance**: Violates data protection principles
- **Trust**: Major breach of user expectations

## Immediate Action Required

This issue must be fixed before any production deployment with multiple users.