-- ==============================================================================
-- DATABASE WEBHOOKS (Section 37)
-- Trigger the order-webhook Edge Function when an order is updated
-- ==============================================================================

-- 1. Enable the network extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Create the Trigger Function
CREATE OR REPLACE FUNCTION public.trigger_order_webhook()
RETURNS TRIGGER AS $$
DECLARE
  payload JSONB;
  request_id BIGINT;
BEGIN
  -- Build the exact JSON payload the Edge Function is expecting
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW),
    'old_record', row_to_json(OLD)
  );

  -- Send the HTTP POST request to the local Edge Function
  SELECT net.http_post(
    url := 'http://host.docker.internal:54321/functions/v1/order-webhook',
    body := payload,
    headers := '{"Content-Type": "application/json"}'::jsonb
  ) INTO request_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach the trigger to the orders table
CREATE TRIGGER on_order_status_webhook
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trigger_order_webhook();