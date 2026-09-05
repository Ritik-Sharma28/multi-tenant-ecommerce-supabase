-- ==============================================================================
-- SECTION 21: JSONB OPERATIONS (jsonb.sql)
-- Demonstrates: JSON extraction, filtering, containment, updates, and indexing[cite: 4].
-- ==============================================================================

-- ==============================================================================
-- 1. JSONB INDEXING
-- Requirement: Create JSONB indexes[cite: 4]
-- A GIN (Generalized Inverted Index) is critical for querying inside JSONB columns.
-- jsonb_path_ops is highly optimized specifically for the '@>' (containment) operator.
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_product_variants_attributes 
ON public.product_variants USING GIN (attributes jsonb_path_ops);


-- ==============================================================================
-- 2. JSON CONTAINMENT & FILTERING (Required Queries)
-- Requirement: Find all black products, XL products, 256GB storage products[cite: 4]
-- The '@>' operator checks if the JSONB on the left contains the JSON structure on the right.
-- ==============================================================================

-- Find all black products
SELECT 
    p.name AS product_name,
    pv.name AS variant_name,
    pv.sku,
    pv.attributes
FROM public.product_variants pv
JOIN public.products p ON pv.product_id = p.id
WHERE pv.attributes @> '{"color": "black"}'::jsonb
LIMIT 10;

-- Find all XL products
SELECT 
    p.name AS product_name,
    pv.name AS variant_name,
    pv.sku,
    pv.attributes
FROM public.product_variants pv
JOIN public.products p ON pv.product_id = p.id
WHERE pv.attributes @> '{"size": "XL"}'::jsonb
LIMIT 10;

-- Find all products with 256GB storage
SELECT 
    p.name AS product_name,
    pv.name AS variant_name,
    pv.sku,
    pv.attributes
FROM public.product_variants pv
JOIN public.products p ON pv.product_id = p.id
WHERE pv.attributes @> '{"size": "256GB"}'::jsonb  -- Using 'size' key as defined in our seed script
LIMIT 10;


-- ==============================================================================
-- 3. JSON EXTRACTION
-- Requirement: JSON extraction[cite: 4]
-- The '->>' operator extracts a specific JSON key as raw text, which allows us 
-- to sort, group, or filter mathematically.
-- ==============================================================================

-- Extract and group by color to see inventory distribution
SELECT 
    attributes->>'color' AS extracted_color,
    COUNT(*) AS variant_count
FROM public.product_variants
WHERE attributes ? 'color' -- The '?' operator checks if the top-level key exists
GROUP BY attributes->>'color'
ORDER BY variant_count DESC;


-- ==============================================================================
-- 4. JSON UPDATE
-- Requirement: JSON update[cite: 4]
-- ==============================================================================

-- Update Strategy A: The '||' Concatenation Operator
-- This merges new keys into the JSONB object, or overwrites existing keys.
-- We will add a new "material" key to 5 specific variants.
WITH TargetVariants AS (
    SELECT id FROM public.product_variants LIMIT 5
)
UPDATE public.product_variants
SET attributes = attributes || '{"material": "cotton", "eco_friendly": true}'::jsonb
WHERE id IN (SELECT id FROM TargetVariants)
RETURNING sku, attributes;

-- Update Strategy B: The jsonb_set() Function
-- Safely updating an existing nested value. If a variant is 'black', change it to 'midnight black'.
UPDATE public.product_variants
SET attributes = jsonb_set(attributes, '{color}', '"midnight black"', false)
WHERE attributes @> '{"color": "black"}'::jsonb
RETURNING sku, attributes;