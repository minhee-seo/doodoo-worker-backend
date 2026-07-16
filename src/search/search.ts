import { getSupabaseClient } from '../lib/supabase';
import { CORS_HEADERS, Env } from '../lib/constants';

const PAGE_SIZE = 30;
const PROMPT_SELECT = `
  id,
  slug,
  title,
  summary,
  image_key,
  image_alt,
  published_at,
  sort_order,
  category:categories (slug, name),
  prompt_tags (tag:tags (slug, name))
`;

type PromptRow = {
  id: string;
  slug: string;
  title: string;
  summary: string;
  image_key: string;
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

function formatPrompt(prompt: PromptRow) {
  return {
    id: prompt.id,
    slug: prompt.slug,
    title: prompt.title,
    summary: prompt.summary,
    imageKey: prompt.image_key,
    imageAlt: prompt.image_alt,
    category: prompt.category,
    tags: prompt.prompt_tags.flatMap(({ tag }) => (tag ? [tag] : [])),
  };
}

export async function handleSearch(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const query = url.searchParams.get('q')?.trim();
  const pageParam = url.searchParams.get('page') ?? url.searchParams.get('p') ?? '1';
  const page = Number(pageParam);

  if (!query) {
    return jsonResponse({ error: '검색어(q)를 입력해 주세요.' }, 400);
  }

  if (query.length > 100) {
    return jsonResponse({ error: '검색어는 100자 이하여야 합니다.' }, 400);
  }

  if (!/^\d+$/.test(pageParam) || !Number.isSafeInteger(page) || page < 1) {
    return jsonResponse({ error: '페이지 번호는 1 이상의 정수여야 합니다.' }, 400);
  }

  const supabase = getSupabaseClient(env);
  const pattern = `*${escapeIlikeValue(query)}*`;
  const now = new Date().toISOString();

  const [textResult, tagResult] = await Promise.all([
    supabase
      .from('prompts')
      .select(PROMPT_SELECT)
      .eq('status', 'published')
      .lte('published_at', now)
      .or(`title.ilike."${pattern}",summary.ilike."${pattern}",base_prompt.ilike."${pattern}"`)
      .order('sort_order', { ascending: true })
      .order('published_at', { ascending: false }),
    supabase
      .from('tags')
      .select('id')
      .or(`name.ilike."${pattern}",slug.ilike."${pattern}"`),
  ]);

  if (textResult.error || tagResult.error) {
    const error = textResult.error ?? tagResult.error;
    console.error('Prompt search failed:', error?.message);
    return jsonResponse({ error: '검색 결과를 불러오지 못했습니다.' }, 500);
  }

  const tagIds = (tagResult.data ?? []).map(({ id }) => id);
  let tagPrompts: PromptRow[] = [];

  if (tagIds.length > 0) {
    const { data, error } = await supabase
      .from('prompt_tags')
      .select(`prompt:prompts!inner(${PROMPT_SELECT})`)
      .in('tag_id', tagIds);

    if (error) {
      console.error('Tag prompt search failed:', error.message);
      return jsonResponse({ error: '검색 결과를 불러오지 못했습니다.' }, 500);
    }

    tagPrompts = (data as unknown as PromptTagRow[] ?? [])
      .flatMap(({ prompt }) => (prompt ? [prompt] : []));
  }

  const prompts = new Map<string, PromptRow>();
  for (const prompt of [...(textResult.data as unknown as PromptRow[] ?? []), ...tagPrompts]) {
    prompts.set(prompt.id, prompt);
  }

  const allResults = [...prompts.values()]
    .sort((a, b) => a.sort_order - b.sort_order
      || new Date(b.published_at).getTime() - new Date(a.published_at).getTime());
  const totalCount = allResults.length;
  const totalPages = Math.ceil(totalCount / PAGE_SIZE);
  const start = (page - 1) * PAGE_SIZE;
  const results = allResults.slice(start, start + PAGE_SIZE).map(formatPrompt);

  return jsonResponse({
    query,
    prompts: results,
    total_count: totalCount,
    page,
    limit: PAGE_SIZE,
    total_pages: totalPages,
  });
}
