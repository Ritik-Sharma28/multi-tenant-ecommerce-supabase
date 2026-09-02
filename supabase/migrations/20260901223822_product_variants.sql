CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id UUID NOT NULL
        REFERENCES products(id)
        ON DELETE CASCADE,

    sku TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,

    price NUMERIC(12,2) NOT NULL
        CHECK (price >= 0),

    attributes JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);