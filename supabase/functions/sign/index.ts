import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { TOTP } from "https://esm.sh/otpauth@9";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TOTP_WINDOW = 1; // Accept ±1 step (±30s)

interface SignRequest {
  session_id: string;
  totp: string;
  signature_png_base64: string;
  slot: "morning" | "afternoon";
  device_id: string;
  timestamp: string;
  sha256: string;
  latitude?: string;
  longitude?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  try {
    // 1. Verify JWT and get user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return error("unauthorized", 401);
    }

    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const anonClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await anonClient.auth.getUser();
    if (authError || !user) {
      return error("unauthorized", 401);
    }

    // 2. Parse body
    const body: SignRequest = await req.json();
    const { session_id, totp, signature_png_base64, slot, device_id, timestamp, sha256 } = body;

    if (!session_id || !totp || !signature_png_base64 || !slot || !device_id || !sha256) {
      return error("missing_fields", 400);
    }

    if (!/^\d{6}$/.test(totp)) {
      return error("invalid_totp_format", 400);
    }

    // 3. Load course and teacher secret
    const { data: course, error: courseError } = await supabaseUser
      .from("courses")
      .select("*, teachers(totp_secret)")
      .eq("id", session_id)
      .single();

    if (courseError || !course) {
      return error("course_not_found", 404);
    }

    // 4. Check time window
    const now = new Date();
    const startsAt = new Date(course.starts_at);
    const endsAt = new Date(course.ends_at);

    if (now < startsAt || now > endsAt) {
      return error("out_of_window", 403);
    }

    // 5. Validate TOTP
    const secret = course.teachers?.totp_secret;
    if (!secret) {
      return error("no_totp_secret", 500);
    }

    const totpInstance = new TOTP({
      secret,
      digits: 6,
      period: 30,
      algorithm: "SHA1",
    });

    const delta = totpInstance.validate({ token: totp, window: TOTP_WINDOW });
    if (delta === null) {
      return error("invalid_totp", 403);
    }

    // 6. Check uniqueness (student + course + slot)
    const { data: existing } = await supabaseUser
      .from("signatures")
      .select("id")
      .eq("student_id", user.id)
      .eq("course_id", session_id)
      .eq("slot", slot)
      .maybeSingle();

    if (existing) {
      return error("already_signed", 409);
    }

    // 7. Check device binding
    const { data: student } = await supabaseUser
      .from("students")
      .select("device_id")
      .eq("id", user.id)
      .single();

    if (student?.device_id && student.device_id !== device_id) {
      return error("device_mismatch", 403);
    }

    // 8. Upload signature PNG to storage
    const signatureId = crypto.randomUUID();
    const pngBuffer = Uint8Array.from(atob(signature_png_base64), (c) => c.charCodeAt(0));
    const storagePath = `${user.id}/${signatureId}.png`;

    const { error: uploadError } = await supabaseUser.storage
      .from("signatures")
      .upload(storagePath, pngBuffer, {
        contentType: "image/png",
        upsert: false,
      });

    if (uploadError) {
      console.error("Storage upload error:", uploadError);
      return error("storage_error", 500);
    }

    // 9. Insert signature record
    const { error: insertError } = await supabaseUser
      .from("signatures")
      .insert({
        id: signatureId,
        student_id: user.id,
        course_id: session_id,
        slot,
        image_path: storagePath,
        timestamp: timestamp || now.toISOString(),
        device_id,
        latitude: body.latitude ? parseFloat(body.latitude) : null,
        longitude: body.longitude ? parseFloat(body.longitude) : null,
        sha256,
      });

    if (insertError) {
      console.error("Insert error:", insertError);
      return error("insert_error", 500);
    }

    return new Response(JSON.stringify({ ok: true, signature_id: signatureId }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (e) {
    console.error("Unexpected error:", e);
    return error("internal_error", 500);
  }
});

function error(code: string, status: number) {
  return new Response(JSON.stringify({ ok: false, error: code }), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}
