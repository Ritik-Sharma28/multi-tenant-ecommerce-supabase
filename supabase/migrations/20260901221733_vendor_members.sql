CREATE TABLE vendor_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    vendor_id UUID NOT NULL
        REFERENCES vendors(id)
        ON DELETE CASCADE,

    user_id UUID NOT NULL
        REFERENCES profiles(id)
        ON DELETE CASCADE,

    role user_role NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (vendor_id, user_id)
);