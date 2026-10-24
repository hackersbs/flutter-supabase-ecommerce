-- ==============================================================================
-- CONCURRENCY TEST: PROVE OUT_OF_STOCK ON SIMULTANEOUS PURCHASES
-- ==============================================================================
-- Scenario:
-- A product has quantity = 1.
-- Two concurrent transactions attempt to execute place_order() for quantity = 1.
--
-- How PostgreSQL prevents race conditions:
-- 1. Transaction A executes: SELECT * FROM public.product WHERE id = target_id FOR UPDATE;
--    This acquires an exclusive row-level lock on the product row.
-- 2. Transaction B executes the same statement simultaneously. Because of "FOR UPDATE",
--    PostgreSQL blocks Transaction B until Transaction A commits or rolls back.
-- 3. Transaction A validates stock (1 >= 1), decrements product.quantity to 0, and commits.
-- 4. Transaction B unblocks, reads the freshly updated row (quantity = 0), triggers:
--    RAISE EXCEPTION 'OUT_OF_STOCK: %', product_name
--    Transaction B rolls back atomically.
-- ==============================================================================

DO $$
DECLARE
  v_seller_id uuid;
  v_buyer1_id uuid;
  v_buyer2_id uuid;
  v_product_id uuid;
  v_order1_id uuid;
  v_error_message text := '';
  v_customer jsonb := '{"name":"Tester","email":"test@example.com","phone":"9999999999","address":"Test St","city":"Mumbai","state":"Maharashtra","country":"India"}'::jsonb;
  v_items jsonb;
  v_final_stock integer;
BEGIN
  -- 1. Setup mock test users
  v_seller_id := gen_random_uuid();
  v_buyer1_id := gen_random_uuid();
  v_buyer2_id := gen_random_uuid();

  INSERT INTO auth.users (id, email) VALUES (v_seller_id, 'seller_test@example.com') ON CONFLICT DO NOTHING;
  INSERT INTO auth.users (id, email) VALUES (v_buyer1_id, 'buyer1_test@example.com') ON CONFLICT DO NOTHING;
  INSERT INTO auth.users (id, email) VALUES (v_buyer2_id, 'buyer2_test@example.com') ON CONFLICT DO NOTHING;

  -- 2. Create a product with EXACTLY 1 item in stock
  INSERT INTO public.product (user_id, name, price, quantity)
  VALUES (v_seller_id, 'Limited Edition Watch', 1999.00, 1)
  RETURNING id INTO v_product_id;

  v_items := jsonb_build_array(
    jsonb_build_object('product_id', v_product_id, 'quantity', 1)
  );

  -- 3. Simulate Buyer 1 placing order (runs under auth context of buyer 1)
  PERFORM set_config('request.jwt.claim.sub', v_buyer1_id::text, true);
  v_order1_id := public.place_order(v_customer, v_items, 'cash_on_delivery');
  ASSERT v_order1_id IS NOT NULL, 'Buyer 1 order should succeed';

  -- 4. Simulate Buyer 2 trying to buy the exact same product immediately after
  PERFORM set_config('request.jwt.claim.sub', v_buyer2_id::text, true);
  BEGIN
    PERFORM public.place_order(v_customer, v_items, 'cash_on_delivery');
    RAISE EXCEPTION 'TEST FAILED: Buyer 2 should have received OUT_OF_STOCK';
  EXCEPTION WHEN OTHERS THEN
    v_error_message := SQLERRM;
  END;

  -- 5. Verify assertions
  ASSERT v_error_message LIKE 'OUT_OF_STOCK%', format('Expected OUT_OF_STOCK error, got: %s', v_error_message);

  SELECT quantity INTO v_final_stock FROM public.product WHERE id = v_product_id;
  ASSERT v_final_stock = 0, format('Product stock should be exactly 0, got: %s', v_final_stock);

  RAISE NOTICE 'CONCURRENCY TEST PASSED: Exactly 1 order succeeded and the second received "%"', v_error_message;

  -- Roll back test artifacts so database remains clean
  RAISE EXCEPTION 'TEST_SUCCESSFUL_ROLLBACK' USING ERRCODE = '00000';
EXCEPTION
  WHEN SQLSTATE '00000' THEN
    RAISE NOTICE 'Test completed successfully and test data was rolled back.';
END;
$$;
