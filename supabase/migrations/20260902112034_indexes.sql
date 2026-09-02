-- ==============================================================================
-- 19. INDEXING
-- Adding indexes to frequently queried columns to prevent Sequential Scans
-- ==============================================================================

-- Foreign Keys (Speeds up JOINs)
CREATE INDEX idx_products_vendor_id ON public.products(vendor_id);
CREATE INDEX idx_products_category_id ON public.products(category_id);
CREATE INDEX idx_orders_user_id ON public.orders(user_id);
CREATE INDEX idx_orders_vendor_id ON public.orders(vendor_id);
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX idx_order_items_variant_id ON public.order_items(variant_id);

-- Lookup fields (Speeds up WHERE clauses)
CREATE INDEX idx_product_variants_sku ON public.product_variants(sku);
CREATE INDEX idx_categories_slug ON public.categories(slug);
CREATE INDEX idx_products_slug ON public.products(slug);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_coupons_code ON public.coupons(code);

-- Composite Index (Required by assignment)
-- A composite index is used when a query frequently filters by TWO columns at the same time.
-- For example, our storefront will often query: WHERE vendor_id = 'X' AND status = 'active'
CREATE INDEX idx_products_vendor_status ON public.products(vendor_id, status);

-- Date Index (Speeds up date range queries, useful for our analytics views)
CREATE INDEX idx_orders_created_at ON public.orders(created_at);