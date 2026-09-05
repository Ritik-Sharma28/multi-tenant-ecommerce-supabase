-- ==============================================================================
-- CHALLENGE 3: UNSOLD, UNREVIEWED, IN-STOCK PRODUCTS FROM ACTIVE VENDORS
-- ==============================================================================

SELECT 
    p.id AS product_id,
    p.name AS product_name,
    v.name AS vendor_name
FROM 
    public.products p
JOIN 
    public.vendors v ON p.vendor_id = v.id

WHERE 
    -- Condition 1: Belong to active vendors
    v.status = 'active'

    -- Condition 2: Have never been purchased
    -- (Checks if any order_item is linked to any variant of this product)
    AND NOT EXISTS (
        SELECT 1 
        FROM public.order_items oi
        JOIN public.product_variants pv ON oi.variant_id = pv.id
        WHERE pv.product_id = p.id
    )

    -- Condition 3: Have inventory
    -- (Checks if at least one variant has available stock > 0)
    AND EXISTS (
        SELECT 1
        FROM public.inventory i
        JOIN public.product_variants pv ON i.variant_id = pv.id
        WHERE pv.product_id = p.id 
          AND (i.quantity - i.reserved_quantity) > 0
    )

    -- Condition 4: Have no reviews
    AND NOT EXISTS (
        SELECT 1 
        FROM public.reviews r
        WHERE r.product_id = p.id
    );