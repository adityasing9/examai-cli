import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

// Helper to authenticate requests using the password stored in Supabase config
async function authenticate(req: NextRequest) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return false;
  }
  const password = authHeader.split(" ")[1];

  const { data, error } = await supabase
    .from("examai_config")
    .select("value")
    .eq("key", "admin_password")
    .single();

  if (error || !data) {
    return false;
  }

  return password === data.value;
}

export async function GET(req: NextRequest) {
  const isAuth = await authenticate(req);
  if (!isAuth) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data, error } = await supabase
    .from("examai_config")
    .select("key, value");

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  // Create formatted object
  const config: Record<string, string> = {};
  data.forEach((item) => {
    config[item.key] = item.value;
  });

  return NextResponse.json({
    gemini_api_key: config.gemini_api_key || "",
    // Keep password hidden
    has_password: !!config.admin_password,
  });
}

export async function POST(req: NextRequest) {
  const isAuth = await authenticate(req);
  if (!isAuth) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const { gemini_api_key, admin_password } = await req.json();

    if (gemini_api_key !== undefined) {
      const { error } = await supabase
        .from("examai_config")
        .upsert({ key: "gemini_api_key", value: gemini_api_key, updated_at: new Date() });
      if (error) throw error;
    }

    if (admin_password !== undefined && admin_password.trim() !== "") {
      const { error } = await supabase
        .from("examai_config")
        .upsert({ key: "admin_password", value: admin_password, updated_at: new Date() });
      if (error) throw error;
    }

    return NextResponse.json({ success: true });
  } catch (err: any) {
    return NextResponse.json({ error: err.message || err }, { status: 500 });
  }
}
