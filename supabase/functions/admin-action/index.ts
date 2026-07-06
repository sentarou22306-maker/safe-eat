import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-admin-key',
}

export default {
  fetch: async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    try {
      const requestKey = req.headers.get('x-admin-key')
      const envKey = Deno.env.get('ADMIN_KEY')
      if (!requestKey || requestKey !== envKey) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      )

      const { action, table, janCode } = await req.json()

      if (action === 'load-pending') {
        const { data: products, error: e1 } = await supabase
          .from('products')
          .select()
          .eq('is_approved', false)
          .order('jan_code')
        if (e1) throw new Error(e1.message)

        const { data: corrections, error: e2 } = await supabase
          .from('allergen_corrections')
          .select()
          .eq('is_approved', false)
          .order('submitted_at', { ascending: false })
        if (e2) throw new Error(e2.message)

        return new Response(JSON.stringify({ products, corrections }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })

      } else if (action === 'approve') {
        const updateData: Record<string, unknown> = { is_approved: true }
        if (table === 'allergen_corrections') {
          updateData.updated_at = new Date().toISOString()
        }
        const { error } = await supabase
          .from(table)
          .update(updateData)
          .eq('jan_code', janCode)
        if (error) throw new Error(error.message)

      } else if (action === 'delete') {
        if (table === 'products') {
          const { error } = await supabase
            .from('products')
            .delete()
            .eq('jan_code', janCode)
            .eq('is_approved', false)
          if (error) throw new Error(error.message)
        } else {
          const { error } = await supabase
            .from(table)
            .delete()
            .eq('jan_code', janCode)
          if (error) throw new Error(error.message)
        }

      } else {
        throw new Error(`Unknown action: ${action}`)
      }

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } catch (e) {
      return new Response(JSON.stringify({ error: (e as Error).message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
  }
}
