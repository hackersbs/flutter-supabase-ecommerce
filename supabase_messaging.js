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
    const payload = await req.json();
    const action = payload.action;

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    let resultData = null;

    if (action === 'send') {
      const { receiver_id, order_id, product_id, body } = payload;
      const { data, error } = await supabaseClient.rpc('send_message', {
        p_receiver_id: receiver_id,
        p_order_id: order_id || null,
        p_product_id: product_id || null,
        p_body: body,
      });
      if (error) throw error;
      resultData = { message: data };
    } 
    else if (action === 'get_messages') {
      const { other_user_id } = payload;
      const { data, error } = await supabaseClient.rpc('get_messages', {
        p_other_user_id: other_user_id
      });
      if (error) throw error;
      resultData = { messages: data };
    } 
    else if (action === 'get_recent_messages') {
      const { data, error } = await supabaseClient.rpc('get_recent_messages');
      if (error) throw error;
      resultData = { messages: data };
    } 
    else {
      throw new Error('Invalid action');
    }

    return new Response(
      JSON.stringify({ success: true, ...resultData }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error) {
    console.error('Edge Function Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
