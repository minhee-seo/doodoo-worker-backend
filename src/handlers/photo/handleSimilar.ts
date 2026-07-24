import { createClient } from '@supabase/supabase-js';
import { getSupabaseClient } from '../../lib/supabase';
import { CORS_HEADERS, Env } from '../../lib/constants';

export async function handleSimilar(request: Request, env: Env): Promise<Response> {
  const supabase = getSupabaseClient(env);
  const url = new URL(request.url);
  const imageId = url.searchParams.get("id");
  const lang = url.searchParams.get("lang") || "ko";
  const limitParam = url.searchParams.get('limit') || '4';
  const limit = Math.min(parseInt(limitParam, 10) || 8, 20);

  // 1. target_prompt_id 필수값 검증
  if (!imageId) {
    return new Response(
      JSON.stringify({ error: 'Missing required parameter: id' }),
      { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }


  // 1. Cloudflare Edge Cache 객체 참조
  const cache = caches.default;
  // URL 자체를 캐시 키로 사용 (쿼리 파라미터 id, lang, limit 구분)
  const cacheKey = new Request(url.toString(), request);

  // 2. Edge Cache 히트 여부 확인
  let response = await cache.match(cacheKey);

  if (response) {
    // 캐시에서 즉시 반환 (DB 호출 0회)
    return response;
  }

  try {
    const { data, error } = await supabase.rpc('get_similar_prompts', {
      target_prompt_id: imageId,
      limit_count: limit,
    });

    if (error) {
      console.error('Supabase RPC Error:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch similar prompts' }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const formattedData = (data || []).map((item: any) => {
      const rawTitle = item.title || {};
      const selectedTitle =
        rawTitle[lang] || rawTitle['ko'] || rawTitle['en'] || Object.values(rawTitle)[0] || '';

      return {
        id: item.id,
        slug: item.slug,
        title: selectedTitle, // JSON 대신 단일 string으로 반환
        similarity_score: item.similarity_score,
        images: {
          thumbnail_url: `${env.PUBLIC_VERCEL}/${item.image_thumbnail_key}`,
        },
      };
    });


    return new Response(
      JSON.stringify({ success: true, data: formattedData }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=86400, s-maxage=86400',
          ...CORS_HEADERS,
        },
      }
    );

  } catch (err: any) {
    console.error('Worker Internal Error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }

};