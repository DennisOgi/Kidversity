interface GoogleServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

let cachedToken: {value: string; expiresAt: number} | null = null;

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function pemBytes(pem: string): Uint8Array {
  const encoded = pem
    .replaceAll("\\n", "\n")
    .replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const binary = atob(encoded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - now > 300) {
    return cachedToken.value;
  }

  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("GOOGLE_TTS_NOT_CONFIGURED");
  const serviceAccount = JSON.parse(raw) as GoogleServiceAccount;
  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw new Error("GOOGLE_TTS_CREDENTIALS_INVALID");
  }

  const header = base64Url(JSON.stringify({alg: "RS256", typ: "JWT"}));
  const claims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/cloud-platform",
    aud: serviceAccount.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(serviceAccount.private_key).buffer as ArrayBuffer,
    {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"},
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsigned),
  );

  const response = await fetch(
    serviceAccount.token_uri ?? "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: `${unsigned}.${base64Url(new Uint8Array(signature))}`,
      }),
    },
  );
  if (!response.ok) throw new Error("GOOGLE_TTS_AUTH_FAILED");
  const token = await response.json() as {
    access_token: string;
    expires_in: number;
  };
  cachedToken = {
    value: token.access_token,
    expiresAt: now + token.expires_in,
  };
  return token.access_token;
}
