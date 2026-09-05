-- ==============================================================================
-- SECTION 10: RECURSIVE CTE (recursive_cte.sql)
-- Demonstrates: WITH RECURSIVE, hierarchical data traversal, dynamic paths
-- ==============================================================================

-- ==============================================================================
-- 1. DATA PREPARATION (Injecting the requested hierarchy)
-- ==============================================================================
DO $$ 
DECLARE 
    v_elec UUID := gen_random_uuid();
    v_phones UUID := gen_random_uuid();
BEGIN
    -- Only insert if 'Electronics' doesn't already exist to prevent duplicate runs
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Electronics') THEN
        -- Level 1: Root
        INSERT INTO public.categories (id, name, slug, parent_id) 
        VALUES (v_elec, 'Electronics', 'electronics-demo', NULL);
        
        -- Level 2: Children of Electronics
        INSERT INTO public.categories (id, name, slug, parent_id) 
        VALUES (v_phones, 'Phones', 'phones-demo', v_elec);
        
        INSERT INTO public.categories (id, name, slug, parent_id) 
        VALUES (gen_random_uuid(), 'Laptops', 'laptops-demo', v_elec);
        
        -- Level 3: Children of Phones
        INSERT INTO public.categories (id, name, slug, parent_id) 
        VALUES (gen_random_uuid(), 'Android', 'android-demo', v_phones);
        
        INSERT INTO public.categories (id, name, slug, parent_id) 
        VALUES (gen_random_uuid(), 'iPhone', 'iphone-demo', v_phones);
    END IF;
END $$;


-- ==============================================================================
-- 2. THE RECURSIVE QUERY
-- Requirement: The hierarchy must be generated dynamically[cite: 4].
-- ==============================================================================
WITH RECURSIVE CategoryTree AS (
    -- --------------------------------------------------------------------------
    -- STEP A: The Base Case (Anchor Member)
    -- Select all top-level categories (those without a parent).
    -- We cast the initial name to TEXT to establish the datatype for the 'path' column.
    -- --------------------------------------------------------------------------
    SELECT 
        id,
        name,
        name::TEXT AS path,
        1 AS depth
    FROM public.categories
    WHERE parent_id IS NULL

    UNION ALL

    -- --------------------------------------------------------------------------
    -- STEP B: The Recursive Step (Recursive Member)
    -- Join the categories table back onto the CategoryTree CTE itself.
    -- This loops continuously, finding children of the previous level, 
    -- until it finds a level with zero children.
    -- --------------------------------------------------------------------------
    SELECT 
        child.id,
        child.name,
        (parent.path || ' > ' || child.name)::TEXT AS path,
        parent.depth + 1
    FROM public.categories child
    INNER JOIN CategoryTree parent ON child.parent_id = parent.id
)
-- --------------------------------------------------------------------------
-- STEP C: The Final Output
-- Select the dynamically generated path strings and sort them alphabetically.
-- --------------------------------------------------------------------------
SELECT 
    path,
    depth
FROM CategoryTree
WHERE path LIKE 'Electronics%' -- Filtering to show just the requested hierarchy
ORDER BY path ASC;