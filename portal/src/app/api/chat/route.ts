import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function POST(req: NextRequest) {
  const startTime = Date.now();
  let questionLength = 0;
  let responseLength = 0;
  let statusCode = 200;

  try {
    const body = await req.json();
    const contents = body.contents || [];
    
    // Calculate question length
    try {
      questionLength = JSON.stringify(contents).length;
    } catch {}

    // 1. Fetch Gemini API Key from Supabase config table
    console.log("Fetching Gemini API Key from Supabase...");
    const { data: configData, error: configError } = await supabase
      .from("examai_config")
      .select("value")
      .eq("key", "gemini_api_key")
      .single();

    if (configError || !configData?.value) {
      console.error("Database fetch error:", configError);
      statusCode = 500;
      return NextResponse.json(
        { error: "Gemini API key is not configured in the admin portal." },
        { status: 500 }
      );
    }

    const apiKey = configData.value;
    console.log("Key found. Forwarding request to Gemini...");

    // 2. Call Google Gemini API
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
    
    const response = await fetch(geminiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    statusCode = response.status;
    const respData = await response.json();

    if (!response.ok) {
      const errMsg = respData?.error?.message || "Gemini API request failed.";
      console.error("Gemini API error response:", errMsg);
      return NextResponse.json({ error: errMsg }, { status: response.status });
    }

    // Extract answer text to measure response length
    let answer = "";
    if (respData?.candidates?.[0]?.content?.parts?.[0]?.text) {
      answer = respData.candidates[0].content.parts[0].text;
      responseLength = answer.length;
    }

    // 3. Log query stats (await to ensure it persists before response completes)
    const responseTimeMs = Date.now() - startTime;
    try {
      const { error: logError } = await supabase
        .from("examai_logs")
        .insert({
          question_length: questionLength,
          response_length: responseLength,
          response_time_ms: responseTimeMs,
          status_code: statusCode,
        });
      if (logError) {
        console.error("Failed to insert log in DB:", logError);
      }
    } catch (dbErr) {
      console.error("Failed to execute log insert:", dbErr);
    }

    return NextResponse.json(respData);

  } catch (err: any) {
    const responseTimeMs = Date.now() - startTime;
    console.error("Proxy error caught:", err);
    
    // Log the failure in DB
    try {
      await supabase
        .from("examai_logs")
        .insert({
          question_length: questionLength,
          response_length: 0,
          response_time_ms: responseTimeMs,
          status_code: 500,
        });
    } catch (dbErr) {
      console.error("Failed to execute error log insert:", dbErr);
    }

    return NextResponse.json(
      { error: `Internal server error: ${err.message || err}` },
      { status: 500 }
    );
  }
}
