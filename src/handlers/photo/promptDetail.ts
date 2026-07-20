// Workers의 src/handlers/promptDetail.ts 기준

import { getSupabaseClient } from '../../lib/supabase';
import { Env, CORS_HEADERS } from '../../lib/constants';


export async function handleGetPromptDetail(
  request: Request,
  env: Env,
  idOrSlug: string
): Promise<Response> {
  const url = new URL(request.url);
  const lang = url.searchParams.get('lang') || 'ko'; // 기본 언어 ko 설정

  if (!idOrSlug) {
    return new Response(JSON.stringify({ error: 'ID 또는 Slug가 필요합니다.' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const supabase = getSupabaseClient(env);
  const r2BaseUrl = env.PUBLIC_VERCEL || '';

  // UUID 형식인지 Slug 문자열인지 구분하여 조회 조건 생성
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug);

  try {
    // 1. Supabase 조인을 활용해 프롬프트, 카테고리, 서브옵션, 태그 한 번에 조회
    let query = supabase
      .from('prompts')
      .select(`
        id,
        slug,
        title,
        summary,
        base_prompt,
        edit_fields,
        image_preview_key,
        image_alt,
        created_at,
        category:categories!inner (
          id,
          slug,
          name
        ),
        sub_option:sub_options (
          id,
          slug,
          name
        ),
        prompt_tags (
          tag:tags (
            id,
            slug,
            name,
            group_name
          )
        )
      `)
      .eq('status', 'published')
      .lte('published_at', new Date().toISOString());

    if (isUuid) {
      query = query.eq('id', idOrSlug);
    } else {
      query = query.eq('slug', idOrSlug);
    }

    const { data: prompt, error } = await query.single();

    if (error || !prompt) {
      return new Response(JSON.stringify({ error: '프롬프트를 찾을 수 없습니다.' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 2. 페이지 조회(View) 이벤트 백그라운드 기록 (비동기)
    // Analytics 비동기 전송 (결과를 기다리지 않고 바로 응답)
    supabase
      .from('prompt_events')
      .insert({ prompt_id: prompt.id, event_type: 'view' })
      .then();

    // 3. 다국어 처리 및 R2 이미지 풀 주소 조합
    const titleObj = prompt.title as Record<string, string>;
    const summaryObj = prompt.summary as Record<string, string>;

    const formattedPrompt = {
      id: prompt.id,
      slug: prompt.slug,
      title: titleObj[lang] || titleObj['ko'] || '',
      summary: summaryObj[lang] || summaryObj['ko'] || '',
      base_prompt: prompt.base_prompt,
      edit_fields: prompt.edit_fields ?? [],
      image_preview_url: `${r2BaseUrl}/${prompt.image_preview_key}`,
      image_alt: prompt.image_alt,
      category: prompt.category,
      sub_option: prompt.sub_option,
      tags: (prompt.prompt_tags ?? [])
        .map((pt: any) => pt.tag)
        .filter(Boolean),
      created_at: prompt.created_at,
    };

    return new Response(JSON.stringify(formattedPrompt), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60, s-maxage=300', // CDN 캐싱 설정
        ...CORS_HEADERS,
      },
    });
  } catch (err) {
    console.error('Prompt Detail API Error:', err);
    return new Response(JSON.stringify({ error: '서버 내부 오류가 발생했습니다.' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}