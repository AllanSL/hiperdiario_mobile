import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const commonHeaders = {
  "Accept": "application/json, text/plain, */*",
  "Accept-Language": "pt-PT,pt;q=0.9,en-US;q=0.8,en;q=0.7",
  "Connection": "keep-alive",
  "Referer": "https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp",
  "Sec-Fetch-Dest": "empty",
  "Sec-Fetch-Mode": "cors",
  "Sec-Fetch-Site": "same-origin",
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
};

// Cache para o cookie para não gerar um novo em cada requisição, a não ser que expire.
let cachedCookie: string | null = null;

async function getSessionCookie(forceNew = false): Promise<string | null> {
  if (cachedCookie && !forceNew) return cachedCookie;
  
  try {
    const res = await fetch("https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp", {
      method: "GET",
      headers: {
        "User-Agent": commonHeaders["User-Agent"]
      }
    });

    const setCookie = res.headers.get("set-cookie");
    if (setCookie) {
      // Pode vir mais de um TS, extraímos e juntamos
      const tsMatches = setCookie.match(/TS[0-9a-zA-Z]+=[^;]+/g);
      if (tsMatches && tsMatches.length > 0) {
        cachedCookie = tsMatches.join('; ');
        return cachedCookie;
      }
    }
  } catch (error) {
    console.error("Erro ao obter cookie de sessão:", error);
  }
  return null;
}

// Lida com a requisição da API Supabase e faz o proxy para o CNES
serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { url } = req;
    const path = new URL(url).searchParams.get('path'); 
    // Exemplo: ?path=estabelecimentos/atendimento/1702102467682

    if (!path) {
      return new Response(JSON.stringify({ error: "Parâmetro 'path' é obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    let cookie = await getSessionCookie();
    if (!cookie) {
      return new Response(JSON.stringify({ error: "Não foi possível obter sessão no CNES" }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const cnesUrl = `https://cnes.datasus.gov.br/services/${path}`;
    
    // Tenta fazer o fetch
    let cnesRes = await fetch(cnesUrl, {
      headers: {
        ...commonHeaders,
        "Cookie": cookie
      }
    });

    // Se falhar por sessão expirada (403 geralmente no F5 BIG-IP), renovamos e tentamos novamente
    if (cnesRes.status === 403 || cnesRes.status === 401) {
      console.log("Sessão expirada/rejeitada, tentando renovar o cookie...");
      cookie = await getSessionCookie(true); // força obter novo
      if (cookie) {
        cnesRes = await fetch(cnesUrl, {
          headers: {
            ...commonHeaders,
            "Cookie": cookie
          }
        });
      }
    }

    if (!cnesRes.ok) {
      return new Response(JSON.stringify({ error: `Erro na resposta do CNES: ${cnesRes.statusText}` }), {
        status: cnesRes.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const data = await cnesRes.json();
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
})
