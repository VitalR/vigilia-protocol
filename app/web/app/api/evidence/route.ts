import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  const json = await req.text();

  // Validate it's parseable JSON
  try {
    JSON.parse(json);
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const token = process.env.GITHUB_GIST_TOKEN;
  if (!token) {
    return NextResponse.json({ error: "GITHUB_GIST_TOKEN not configured" }, { status: 503 });
  }

  const gistRes = await fetch("https://api.github.com/gists", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/vnd.github.v3+json",
      "User-Agent": "vigilia-frontend",
    },
    body: JSON.stringify({
      public: true,
      description: "Vigilia grant application evidence",
      files: { "evidence.json": { content: json } },
    }),
  });

  if (!gistRes.ok) {
    const text = await gistRes.text();
    return NextResponse.json({ error: `GitHub API error: ${gistRes.status}`, detail: text }, { status: 502 });
  }

  const gist = await gistRes.json() as {
    files: Record<string, { raw_url: string }>;
  };

  const rawUrl = gist.files?.["evidence.json"]?.raw_url;
  if (!rawUrl) {
    return NextResponse.json({ error: "No raw_url in gist response" }, { status: 502 });
  }

  return NextResponse.json({ url: rawUrl });
}
