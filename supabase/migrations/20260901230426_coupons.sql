CREATE TABLE coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    discount_type TEXT NOT NULL,
    discount_value NUMERIC(12,2) NOT NULL CHECK (discount_value >= 0),
    minimum_order_amount NUMERIC(12,2) CHECK (minimum_order_amount >= 0),
    maximum_discount NUMERIC(12,2) CHECK (maximum_discount >= 0),
    starts_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    usage_limit INTEGER CHECK (usage_limit >= 0),
    usage_count INTEGER NOT NULL DEFAULT 0 CHECK (usage_count >= 0),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (vendor_id, code),

    CHECK (expires_at IS NULL OR expires_at > starts_at),
    CHECK (usage_limit IS NULL OR usage_count <= usage_limit)
);
