CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    variant_id UUID NOT NULL UNIQUE
        REFERENCES product_variants(id)
        ON DELETE CASCADE,

    quantity INTEGER NOT NULL DEFAULT 0
        CHECK (quantity >= 0),

    reserved_quantity INTEGER NOT NULL DEFAULT 0
        CHECK (reserved_quantity >= 0),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (reserved_quantity <= quantity)
);