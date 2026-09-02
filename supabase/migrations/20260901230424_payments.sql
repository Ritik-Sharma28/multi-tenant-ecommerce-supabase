CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    transaction_id TEXT UNIQUE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    status TEXT NOT NULL DEFAULT 'pending',
    payment_method TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
