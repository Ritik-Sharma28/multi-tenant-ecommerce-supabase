CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    vendor_id UUID NOT NULL
        REFERENCES vendors(id)
        ON DELETE CASCADE,

    category_id UUID NOT NULL
        REFERENCES categories(id)
        ON DELETE RESTRICT,

    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,

    base_price NUMERIC(12,2) NOT NULL
        CHECK (base_price >= 0),

    status TEXT NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    deleted_at TIMESTAMPTZ,

    UNIQUE (vendor_id, slug)
);