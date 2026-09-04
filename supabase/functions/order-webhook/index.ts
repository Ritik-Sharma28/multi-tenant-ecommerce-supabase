// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

// This is the equivalent of app.post('/', async (req, res) => { ... })
Deno.serve(async (req : any) => {
  try {
    // 1. Get the payload sent by the PostgreSQL database webhook
    // (Equivalent to req.body in Express)
    const payload = await req.json()
    console.log("Database Webhook Received!", payload)

    // The database sends 'record' (new row), 'old_record' (previous row), and 'type' (INSERT, UPDATE)
    const { type, record, old_record } = payload

    // 2. Write our business logic
    // If this is an update, and the status just changed to 'completed'
    if (type === 'UPDATE' && record.status === 'completed' && old_record?.status !== 'completed') {
        
        // In a real app, you would use an email API like Resend or SendGrid here:
        // await fetch('https://api.resend.com/emails', { method: 'POST', body: ... })
        console.log(`[ACTION REQUIRED] Sending receipt email to User ID: ${record.user_id} for Order: ${record.id}`)
    }

    // 3. Send a success response back to the database
    // (Equivalent to res.status(200).json(...) in Express)
    return new Response(
      JSON.stringify({ message: "Webhook processed successfully" }),
      { headers: { "Content-Type": "application/json" }, status: 200 },
    )

  } catch (error:any) {
    // 4. Handle errors securely
    console.error("Webhook Error:", error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 400 },
    )
  }
})