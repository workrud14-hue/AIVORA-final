/*
# Add blog view tracking, contact messages, blog cover storage, and currency rates

1. New Tables
- `contact_messages` — Stores messages submitted via the storefront contact form.
  - `id` (uuid, primary key)
  - `name` (text, not null) — sender's name
  - `email` (text, not null) — sender's email
  - `subject` (text) — message subject
  - `message` (text, not null) — message body
  - `is_read` (boolean, default false) — admin read/unread flag
  - `created_at` (timestamptz, default now())
- `currency_rates` — Stores exchange rates vs USD for client-side price conversion.
  - `currency` (text, primary key) — ISO currency code, e.g. "USD", "EUR"
  - `rate` (numeric, default 1) — multiplier vs USD
  - `symbol` (text, default '$') — display symbol
  - `updated_at` (timestamptz, default now())

2. Modified Tables
- `blog_posts` — Added two new columns:
  - `views` (integer, default 0) — unique view counter
  - `last_viewed_at` (timestamptz, nullable) — timestamp of most recent view
  Both added idempotently via a DO block that checks information_schema.

3. Storage
- Creates a new `blog-covers` bucket for blog cover image uploads from the admin.
- Adds public-read + anon/authenticated upload/update/delete RLS policies on storage.objects
  scoped to the `blog-covers` bucket, mirroring the existing `product-covers` setup.

4. Security
- `contact_messages`: RLS enabled. anon INSERT allowed (storefront submits without sign-in).
  anon + authenticated SELECT/UPDATE/DELETE allowed (admin manages messages).
- `currency_rates`: RLS enabled. anon + authenticated SELECT allowed (storefront reads rates
  for conversion). anon + authenticated INSERT/UPDATE/DELETE allowed (admin edits rates).
- `blog-covers` storage policies: public read, anon/authenticated write/update/delete.
- This is a single-tenant app with no Supabase Auth sign-in, so policies use
  `TO anon, authenticated` with `USING (true)` / `WITH CHECK (true)` because the data is
  intentionally shared/public (the admin uses password-based session auth, not Supabase Auth).

5. Seed Data
- `currency_rates` seeded with common currencies: USD (1), EUR (0.92), GBP (0.79),
  INR (83.5), AUD (1.52), CAD (1.36), JPY (156), AED (3.67), SGD (1.35), NGN (1500).
  Inserted with ON CONFLICT (currency) DO NOTHING so re-runs are safe.

6. Important Notes
1. The storefront anon-key client can now INSERT into contact_messages and SELECT from
   currency_rates; the admin (also using anon key) can manage both tables.
2. Blog view increments are UPDATE operations on blog_posts, already covered by the existing
   anon UPDATE policy on that table.
3. The blog-covers bucket must be created via insert into storage.buckets; the storage.objects
   policies scope access to it.
4. All statements are idempotent (IF NOT EXISTS / ON CONFLICT / DROP POLICY IF EXISTS).
*/

-- CONTACT MESSAGES TABLE
CREATE TABLE IF NOT EXISTS contact_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text NOT NULL,
  subject text DEFAULT '',
  message text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_contact_messages" ON contact_messages;
CREATE POLICY "anon_select_contact_messages" ON contact_messages FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_contact_messages" ON contact_messages;
CREATE POLICY "anon_insert_contact_messages" ON contact_messages FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_contact_messages" ON contact_messages;
CREATE POLICY "anon_update_contact_messages" ON contact_messages FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_contact_messages" ON contact_messages;
CREATE POLICY "anon_delete_contact_messages" ON contact_messages FOR DELETE
  TO anon, authenticated USING (true);

-- CURRENCY RATES TABLE
CREATE TABLE IF NOT EXISTS currency_rates (
  currency text PRIMARY KEY,
  rate numeric DEFAULT 1,
  symbol text DEFAULT '$',
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE currency_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_currency_rates" ON currency_rates;
CREATE POLICY "anon_select_currency_rates" ON currency_rates FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_currency_rates" ON currency_rates;
CREATE POLICY "anon_insert_currency_rates" ON currency_rates FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_currency_rates" ON currency_rates;
CREATE POLICY "anon_update_currency_rates" ON currency_rates FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_currency_rates" ON currency_rates;
CREATE POLICY "anon_delete_currency_rates" ON currency_rates FOR DELETE
  TO anon, authenticated USING (true);

-- Seed common currency rates (vs USD). ON CONFLICT keeps re-runs safe.
INSERT INTO currency_rates (currency, rate, symbol) VALUES
  ('USD', 1, '$'),
  ('EUR', 0.92, '€'),
  ('GBP', 0.79, '£'),
  ('INR', 83.5, '₹'),
  ('AUD', 1.52, 'A$'),
  ('CAD', 1.36, 'C$'),
  ('JPY', 156, '¥'),
  ('AED', 3.67, 'د.إ'),
  ('SGD', 1.35, 'S$'),
  ('NGN', 1500, '₦')
ON CONFLICT (currency) DO NOTHING;

-- BLOG POSTS: add views + last_viewed_at columns idempotently
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'blog_posts' AND column_name = 'views'
  ) THEN
    ALTER TABLE blog_posts ADD COLUMN views integer DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'blog_posts' AND column_name = 'last_viewed_at'
  ) THEN
    ALTER TABLE blog_posts ADD COLUMN last_viewed_at timestamptz;
  END IF;
END $$;

-- BLOG-COVERS STORAGE BUCKET
INSERT INTO storage.buckets (id, name, public)
VALUES ('blog-covers', 'blog-covers', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read blog-covers" ON storage.objects;
CREATE POLICY "Public read blog-covers"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'blog-covers');

DROP POLICY IF EXISTS "Anon upload blog-covers" ON storage.objects;
CREATE POLICY "Anon upload blog-covers"
ON storage.objects FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'blog-covers');

DROP POLICY IF EXISTS "Anon update blog-covers" ON storage.objects;
CREATE POLICY "Anon update blog-covers"
ON storage.objects FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'blog-covers');

DROP POLICY IF EXISTS "Anon delete blog-covers" ON storage.objects;
CREATE POLICY "Anon delete blog-covers"
ON storage.objects FOR DELETE
TO anon, authenticated
USING (bucket_id = 'blog-covers');
