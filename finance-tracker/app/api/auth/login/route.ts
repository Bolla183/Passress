import { NextResponse } from "next/server";
import {
  SESSION_COOKIE,
  SESSION_COOKIE_OPTIONS,
  createSessionValue,
} from "@/lib/auth";

export async function POST(request: Request) {
  if (!process.env.APP_PASSWORD) {
    return NextResponse.json(
      { error: "Server misconfigured: APP_PASSWORD is not set" },
      { status: 500 }
    );
  }

  const { password } = await request.json();

  if (typeof password !== "string" || password !== process.env.APP_PASSWORD) {
    return NextResponse.json({ error: "Incorrect password" }, { status: 401 });
  }

  let sessionValue: string;
  try {
    sessionValue = createSessionValue();
  } catch {
    return NextResponse.json(
      { error: "Server misconfigured: SESSION_SECRET is not set" },
      { status: 500 }
    );
  }

  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE, sessionValue, SESSION_COOKIE_OPTIONS);
  return response;
}
