CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES profiles(id)
        ON DELETE CASCADE,

    address_line_1 TEXT NOT NULL,
    address_line_2 TEXT,

    city TEXT NOT NULL,
    state TEXT NOT NULL,
    country TEXT NOT NULL,
    postal_code TEXT NOT NULL,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX one_default_address_per_user
ON addresses (user_id)
WHERE is_default = TRUE;