CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name TEXT NOT NULL,

    slug TEXT NOT NULL UNIQUE,

    parent_id UUID 
       REFERENCES categories(id) 
       ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT NOW()
)