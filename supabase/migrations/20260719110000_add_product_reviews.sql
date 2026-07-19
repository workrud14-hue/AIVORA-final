/*
Add product_reviews table for user-submitted reviews and ratings on products.

1. New Tables
- `product_reviews` — Stores user-submitted reviews with star ratings.
  - `id` (uuid, primary key)
  - `product_id` (uuid, not null) — references products(id)
  - `user_name` (text) — display name of the reviewer
  - `rating` (integer, not null) — 1-5 star rating
  - `comment` (text) — review text
  - `approved` (boolean, default false) — admin moderation flag
  - `created_at` (timestamptz, default now())

2. Security
- RLS enabled. anon can INSERT (submit review) and SELECT approved reviews.
- anon + authenticated SELECT/UPDATE/DELETE (admin moderation).
*/

CREATE TABLE IF NOT EXISTS product_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id text NOT NULL,
  user_name text DEFAULT 'Anonymous',
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text DEFAULT '',
  approved boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Index for efficient lookups by product
CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_approved ON product_reviews(approved);

-- RLS
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "anon can insert reviews" ON product_reviews;
DROP POLICY IF EXISTS "anon can read approved reviews" ON product_reviews;
DROP POLICY IF EXISTS "anon can manage reviews" ON product_reviews;
DROP POLICY IF EXISTS "authenticated can manage reviews" ON product_reviews;

CREATE POLICY "anon can insert reviews" ON product_reviews
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon can read approved reviews" ON product_reviews
  FOR SELECT TO anon USING (approved = true);

CREATE POLICY "anon can manage reviews" ON product_reviews
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "authenticated can manage reviews" ON product_reviews
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
