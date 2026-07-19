import { getSupabaseClient } from '../lib/supabase';
import { CORS_HEADERS, Env } from '../lib/constants';


const PAGE_SIZE = 30;
const getPromptSelect = (lang: string) => `
  id,
  slug,
  title->>${lang},
  image_thumbnail_key,
  image_alt,
  sort_order,
  category:categories (slug, name),
  prompt_tags (tag:tags (slug, name))
`;

type PromptRow = {
  id: string;
  slug: string;
  [key: string]: any; // 동적 dynamic key (lang 값) 매핑용
  image_thumbnail_key: string;
  image_alt: string;
  published_at: string;
  sort_order: number;
  category: { slug: string; name: string } | null;
  prompt_tags: Array<{ tag: { slug: string; name: string } | null }>;
};

type PromptTagRow = {
  prompt: PromptRow | null;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function escapeIlikeValue(value: string): string {
  return value.replace(/[\\%_]/g, '\\$&').replace(/"/g, '\\"');
}

function formatPrompt(prompt: PromptRow, lang: string, env: Env) {
  const imgBaseUrl = env.PUBLIC_VERCEL || "https://img.doodoostock.com";

  return {
    id: prompt.id,
    slug: prompt.slug,
    // 해당 언어 데이터가 없으면 한국어('ko')를 백업(Fallback)으로 적용
    title: prompt[lang] || prompt['ko'],
    imageThumbnailKey: `${imgBaseUrl}/${prompt.image_thumbnail_key}`,
    imageAlt: prompt.image_alt,
    category: prompt.category,
    tags: prompt.prompt_tags.flatMap(({ tag }) => (tag ? [tag] : [])),
  };
}

export async function handleSearch(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const query = url.searchParams.get('q')?.trim();
  
  const categoryParam = url.searchParams.get('category') ?? url.searchParams.get('c') ?? '';
  const category = categoryParam.trim();

  const pageParam = url.searchParams.get('page') ?? url.searchParams.get('p') ?? '1';
  const page = Number(pageParam);

  const langParam = url.searchParams.get('lang') || 'ko';
  const allowedLangs = ['ko', 'en'];
  const lang = allowedLangs.includes(langParam) ? langParam : 'ko';

  if (!query && !category) {
    return jsonResponse({ error: '검색어(q) 또는 카테고리를 입력해 주세요.' }, 400);
  }

  if (query && query.length > 100) {
    return jsonResponse({ error: '검색어는 100자 이하여야 합니다.' }, 400);
  }

  if (category && category.length > 50) {
    return jsonResponse({ error: '카테고리 값이 올바르지 않습니다.' }, 400);
  }

  if (!/^\d+$/.test(pageParam) || !Number.isSafeInteger(page) || page < 1) {
    return jsonResponse({ error: '페이지 번호는 1 이상의 정수여야 합니다.' }, 400);
  }

  const supabase = getSupabaseClient(env);
  const pattern = query ? `*${escapeIlikeValue(query)}*` : '';
  const now = new Date().toISOString();

  const promptSelectStr = getPromptSelect(lang);

  // ----------------------------------------------------
  // 1. 메인 텍스트 쿼리 빌더 조립
  // ----------------------------------------------------
  let textQueryBuilder = supabase
    .from('prompts')
    .select(promptSelectStr)
    .eq('status', 'published')
    .lte('published_at', now);

  // 카테고리가 있으면 카테고리 테이블을 강제 inner 조인
  if (category) {
    textQueryBuilder = textQueryBuilder.eq('category.slug', category);
  }

  if (query) {
    textQueryBuilder = textQueryBuilder.or(
      `title->>${lang}.ilike."${pattern}",summary->>${lang}.ilike."${pattern}",base_prompt.ilike."${pattern}"`
    );
  }

  // ----------------------------------------------------
  // 2. 태그 아이디 쿼리 (검색어가 있을 때만 실행)
  // ----------------------------------------------------
  let tagIds: string[] = [];
  let tagError = null;

  if (query) {
    const tagResult = await supabase
      .from('tags')
      .select('id')
      .or(`name.ilike."${pattern}",slug.ilike."${pattern}"`);
    
    tagError = tagResult.error;
    tagIds = (tagResult.data ?? []).map(({ id }) => id);
  }

  // 텍스트 검색 결과 먼저 실행
  const textResult = await textQueryBuilder;

  if (textResult.error || tagError) {
    const error = textResult.error ?? tagError;
    console.error('Prompt search failed:', error?.message);
    return jsonResponse({ error: '검색 결과를 불러오지 못했습니다.' }, 500);
  }

  // ----------------------------------------------------
  // 3. 태그 맵핑 검색 결과 조회 및 교차 검증
  // ----------------------------------------------------
  let tagPrompts: PromptRow[] = [];
  if (query && tagIds.length > 0) {
    let tagQueryBuilder = supabase
      .from('prompt_tags')
      .select(`prompt:prompts!inner(${promptSelectStr})`)
      .in('tag_id', tagIds)
      .eq('prompts.status', 'published')
      .lte('prompts.published_at', now);

    // 태그 연결 테이블에서 가져올 때도 카테고리 조건을 inner 조인
    if (category) {
      tagQueryBuilder = tagQueryBuilder.eq('prompts.category.slug', category);
    }

    const { data, error } = await tagQueryBuilder;

    if (error) {
      console.error('Tag prompt search failed:', error.message);
      return jsonResponse({ error: '검색 결과를 불러오지 못했습니다.' }, 500);
    }

    tagPrompts = (data as unknown as PromptTagRow[] ?? [])
      .flatMap(({ prompt }) => (prompt ? [prompt] : []));
  }

  // ----------------------------------------------------
  // 4. 결과 병합 및 최종 안전 필터링
  // ----------------------------------------------------
  const prompts = new Map<string, PromptRow>();
  
  // 합치기 대상 전체 리스트 구하기
  const rawMergedList = [
    ...(textResult.data as unknown as PromptRow[] ?? []), 
    ...tagPrompts
  ];

  for (const prompt of rawMergedList) {
    // DB 릴레이션 범위 밖에서 null 데이터가 타고 들어오는 것을 메모리 단에서 최종 필터링
    if (category && (!prompt.category || prompt.category.slug !== category)) {
      continue; 
    }
    prompts.set(prompt.id, prompt);
  }

  // 정렬, 페이징
  const allResults = [...prompts.values()]
    .sort((a, b) => a.sort_order - b.sort_order
      || new Date(b.published_at).getTime() - new Date(a.published_at).getTime());
  
  const totalCount = allResults.length;
  const totalPages = Math.ceil(totalCount / PAGE_SIZE);
  const start = (page - 1) * PAGE_SIZE;

  const results = allResults.slice(start, start + PAGE_SIZE).map((p) => formatPrompt(p, lang, env));

  return jsonResponse({
    query: query || '',
    category,
    lang, 
    prompts: results,
    total_count: totalCount,
    page,
    limit: PAGE_SIZE,
    total_pages: totalPages,
  });
}
