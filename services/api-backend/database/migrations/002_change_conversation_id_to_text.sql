BEGIN;

-- Drop dependent foreign key
ALTER TABLE messages DROP CONSTRAINT IF EXISTS fk_messages_conversation;

-- Change conversations.id to TEXT (preserving existing UUIDs as text)
ALTER TABLE conversations ALTER COLUMN id TYPE TEXT USING id::TEXT;

-- Change messages.conversation_id to TEXT
ALTER TABLE messages ALTER COLUMN conversation_id TYPE TEXT USING conversation_id::TEXT;

-- Re-add foreign key constraint
ALTER TABLE messages ADD CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;

COMMIT;
