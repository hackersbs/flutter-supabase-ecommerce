import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { customer, items, payment_method, coupon_code } = await req.json();
    if (!customer || typeof customer !== 'object' || !Array.isArray(items) || items.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Delivery details and cart items are required.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      );
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } }
    );

    // Call the PostgreSQL place_order function with atomic row locks & transactions.
    const { data, error } = await supabaseClient.rpc('place_order', {
      p_customer: customer,
      p_items: items,
      p_payment_method: payment_method || 'cash_on_delivery',
      p_coupon_code: coupon_code || null,
    });

    if (error) {
      console.error('Error placing order:', error);
      return new Response(
        JSON.stringify({ error: error.message }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      );
    }

    return new Response(
      JSON.stringify({ success: true, order_id: data }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error) {
    console.error('Error placing order:', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Could not place order.' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
