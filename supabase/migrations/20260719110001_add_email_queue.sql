/*
Add email_queue table for queuing transactional emails.

1. New Tables
- `email_queue` — Stores pending transactional emails to be sent.
  - `id` (uuid, primary key)
  - `type` (text, not null) — 'welcome', 'purchase_confirmation', 'blog_notification'
  - `to_email` (text, not null) — recipient email
  - `subject` (text, not null) — email subject line
  - `metadata` (jsonb) — additional data (product name, url, etc.)
  - `status` (text, default 'pending') — 'pending', 'sent', 'failed'
  - `error_message` (text) — error details if send failed
  - `created_at` (timestamptz, default now())
  - `sent_at` (timestamptz)

2. Security
- anon + authenticated can INSERT/SELECT/UPDATE (client queues emails, admin processes).
*/

CREATE TABLE IF NOT EXISTS email_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  to_email text NOT NULL,
  subject text NOT NULL,
  metadata jsonb DEFAULT '{}',
  status text DEFAULT 'pending',
  error_message text,
  created_at timestamptz DEFAULT now(),
  sent_at timestamptz
);

-- Index for efficient polling of pending emails
CREATE INDEX IF NOT EXISTS idx_email_queue_status ON email_queue(status);
CREATE INDEX IF NOT EXISTS idx_email_queue_created ON email_queue(created_at);

-- RLS
ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon can manage email queue" ON email_queue;
DROP POLICY IF EXISTS "authenticated can manage email queue" ON email_queue;

CREATE POLICY "anon can manage email queue" ON email_queue
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "authenticated can manage email queue" ON email_queue
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
