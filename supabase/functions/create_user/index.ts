import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req:any) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Create admin client with service role key
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SERVICE_ROLE_KEY') ?? '',
            {
                auth: {
                    autoRefreshToken: false,
                    persistSession: false
                }
            }
        )

        // Parse request body
        const { email, password, role, clinic_id, profile_data } = await req.json()

        // Validation
        if (!email || !password || !role || !clinic_id) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: 'Missing required fields: email, password, role, clinic_id'
                }),
                {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                }
            )
        }

        // Validate role
        if (role !== 'staff' && role !== 'dentist') {
            return new Response(
                JSON.stringify({ success: false, error: 'Invalid role. Must be "staff" or "dentist"' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Validate email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        if (!emailRegex.test(email)) {
            return new Response(
                JSON.stringify({ success: false, error: 'Invalid email format' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Validate password length
        if (password.length < 6) {
            return new Response(
                JSON.stringify({ success: false, error: 'Password must be at least 6 characters long' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log(`Creating ${role} user: ${email}`)

        // Create auth user using admin API
        const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true, // Auto-confirm email
            user_metadata: {
                role: role,
                clinic_id: clinic_id,
            }
        })

        if (authError) {
            console.error('Auth creation error:', authError)
            return new Response(
                JSON.stringify({
                    success: false,
                    error: authError.message || 'Failed to create auth user. Email may already exist.'
                }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        if (!authData.user) {
            return new Response(
                JSON.stringify({ success: false, error: 'User creation failed' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log(`Auth user created: ${authData.user.id}`)

        // Determine table and ID column based on role
        const tableName = role === 'staff' ? 'staffs' : 'dentists'
        const idColumn = role === 'staff' ? 'staff_id' : 'dentist_id'

        // Prepare profile record
        const profileRecord = {
            [idColumn]: authData.user.id,
            email: email,
            password: password, // Storing for consistency with existing pattern
            clinic_id: clinic_id,
            role: role === 'staff' ? 'staff' : 'associate',
            fcm_token: null, // Initialize as null, will be set on first login
            ...profile_data,
        }

        // Add status field for dentists
        if (role === 'dentist') {
            profileRecord.status = profile_data?.status || 'pending'
        }

        console.log(`Inserting into ${tableName}:`, profileRecord)

        // Insert profile into appropriate table
        const { error: dbError } = await supabaseAdmin
            .from(tableName)
            .insert(profileRecord)

        if (dbError) {
            console.error('Database insertion error:', dbError)

            // If profile insertion fails, delete the auth user to maintain consistency
            await supabaseAdmin.auth.admin.deleteUser(authData.user.id)

            return new Response(
                JSON.stringify({
                    success: false,
                    error: `Failed to create profile: ${dbError.message}`
                }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log(`${role} created successfully: ${authData.user.id}`)

        // Return success
        return new Response(
            JSON.stringify({
                success: true,
                user_id: authData.user.id,
                message: `${role === 'staff' ? 'Staff' : 'Dentist'} created successfully`
            }),
            {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error) {
        console.error('Unexpected error:', error)
        return new Response(
            JSON.stringify({
                success: false,
                error: error.message || 'An unexpected error occurred'
            }),
            {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )
    }
})
