-- ==============================================================================
-- 1. UPDATED_AT TRIGGER (Section 16)
-- Automatically update the updated_at column whenever a row changes
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Attach to all relevant tables
CREATE TRIGGER update_profiles_modtime BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_vendors_modtime BEFORE UPDATE ON public.vendors FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_products_modtime BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_inventory_modtime BEFORE UPDATE ON public.inventory FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_orders_modtime BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ==============================================================================
-- 2. AUDIT LOGGING TRIGGER (Section 16 & 31)
-- Automatically log sensitive changes (like product price updates)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.audit_logs (user_id, table_name, record_id, action, old_data, new_data)
        VALUES (auth.uid(), TG_TABLE_NAME, NEW.id, 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach audit log to product price/status changes
CREATE TRIGGER audit_products_trigger 
AFTER UPDATE OF base_price, status ON public.products 
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

-- Attach audit log to inventory changes
CREATE TRIGGER audit_inventory_trigger 
AFTER UPDATE OF quantity ON public.inventory 
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();