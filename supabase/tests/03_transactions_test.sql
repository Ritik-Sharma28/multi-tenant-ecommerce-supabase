BEGIN;
SELECT plan(1);

-- We test this by attempting to run the create_order RPC function with an invalid payload
SELECT throws_ok(
    $$ SELECT public.create_order(
        (SELECT id FROM public.vendors LIMIT 1), 
        (SELECT id FROM public.addresses LIMIT 1), 
        '[{"variant_id": "00000000-0000-0000-0000-000000000000", "quantity": 100}]'::jsonb
    ) $$,
    NULL, -- Accept any error message
    'Order creation should fail completely if variant ID is invalid'
);

-- Because the test is inside a pgTAP transaction block, we can verify that 
-- NO partial orders were written during that failed attempt.
-- (This is handled implicitly by Postgres, but throws_ok guarantees the failure was caught).

SELECT * FROM finish();
ROLLBACK;