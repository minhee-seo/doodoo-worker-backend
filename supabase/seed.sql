-- 초기 카테고리 등록
INSERT INTO public.categories (name, slug, sort_order) VALUES
('마케팅·디자인', 'marketing', 1),
('브랜딩·목업', 'branding-mockups', 2),
('타이포그래피', 'typography', 3),
('일러스트레이션', 'illustration', 4),
('사진·실사', 'photography', 5)
ON CONFLICT (slug) DO NOTHING;

-- 초기 태그 등록
INSERT INTO public.tags (name, slug, group_name) VALUES
('카드뉴스', 'card-news', '포맷'),
('포스터', 'poster', '포맷'),
('3D 캐릭터', '3d-character', '스타일'),
('파스텔톤', 'pastel-tone', '색상')
ON CONFLICT (slug) DO NOTHING;

-- ==========================================
-- 1. "새학기" 관련 추가 태그 등록
-- ==========================================
INSERT INTO public.tags (id, name, slug, group_name) VALUES
('a019488a-1111-4444-8888-000000000001', '새학기', 'new-semester', '시즌'),
('a019488a-2222-4444-8888-000000000002', '일러스트', 'illustration', '스타일'),
('a019488a-3333-4444-8888-000000000003', '목업', 'mockup', '스타일'),
('a019488a-4444-4444-8888-000000000004', '실사사진', 'photo', '스타일')
ON CONFLICT (slug) DO NOTHING;

-- ==========================================
-- 2. "새학기" 관련 테스트용 프롬프트 등록
-- ==========================================
-- (참고: 아래 SQL은 앞서 등록한 카테고리인 'marketing', 'illustration', 'photography'의 ID를 동적으로 조회해서 매핑합니다.)

-- [프롬프트 A] 새학기 등교길 3D 일러스트
INSERT INTO public.prompts (
  id, slug, title, summary, category_id, sub_option_id, base_prompt, edit_fields, image_key, image_alt, status, published_at
) VALUES (
  'b019488a-aaaa-4444-8888-000000000001',
  'new-semester-3d-character',
  '새학기 초등학생 등교길 3D 일러스트',
  '설레는 마음으로 등교하는 귀여운 초등학생 캐릭터 3D 일러스트 프롬프트입니다.',
  (SELECT id FROM public.categories WHERE slug = 'illustration' LIMIT 1),
  NULL,
  'A cute 3D character of a young student wearing a backpack, walking towards school, cherry blossoms blowing, warm pastel colors, soft clay render, octane render, 8k --ar 16:9',
  '[]'::jsonb,
  'samples/new-semester-3d.png',
  '새학기 등교하는 3D 학생 캐릭터 일러스트',
  'published',
  now()
) ON CONFLICT (slug) DO NOTHING;

-- [프롬프트 B] 새학기 학용품 목업 사진
INSERT INTO public.prompts (
  id, slug, title, summary, category_id, sub_option_id, base_prompt, edit_fields, image_key, image_alt, status, published_at
) VALUES (
  'b019488a-bbbb-4444-8888-000000000002',
  'new-semester-stationery-mockup',
  '새학기 심플 학용품 배치 및 노트 목업',
  '파스텔톤의 노트, 연필, 가위가 정갈하게 배치된 신학기 감성 목업 프롬프트입니다.',
  (SELECT id FROM public.categories WHERE slug = 'branding-mockups' LIMIT 1),
  NULL,
  'Flat lay of pastel-toned school stationery, notebooks, pencils on a clean mint background, minimalist aesthetic, commercial branding photography, soft natural lighting --ar 4:3',
  '[]'::jsonb,
  'samples/stationery-mockup.png',
  '파스텔톤 학용품과 노트 목업 이미지',
  'published',
  now()
) ON CONFLICT (slug) DO NOTHING;

-- [프롬프트 C] 새학기 대학생 캠퍼스 풍경 (실사)
INSERT INTO public.prompts (
  id, slug, title, summary, category_id, sub_option_id, base_prompt, edit_fields, image_key, image_alt, status, published_at
) VALUES (
  'b019488a-cccc-4444-8888-000000000003',
  'new-semester-college-campus',
  '새학기 벚꽃 피는 대학 캠퍼스 실사',
  '화창한 봄날, 벚꽃이 흩날리는 평화로운 대학교 캠퍼스 풍경의 실사 일러스트/사진 프롬프트입니다.',
  (SELECT id FROM public.categories WHERE slug = 'photography' LIMIT 1),
  NULL,
  'A cinematic photo of a beautiful university campus in spring, cherry blossom trees in full bloom, college students walking in the background, sun flare, captured on 35mm lens, highly detailed --ar 16:9',
  '[]'::jsonb,
  'samples/campus-cherry-blossom.png',
  '봄날 벚꽃이 만개한 캠퍼스 풍경 실사',
  'published',
  now()
) ON CONFLICT (slug) DO NOTHING;


-- ==========================================
-- 3. 프롬프트와 태그 매핑 등록 (다대다 관계 완성)
-- ==========================================

-- 프롬프트 A(3D 캐릭터)에 [#새학기], [#일러스트] 태그 연결
INSERT INTO public.prompt_tags (prompt_id, tag_id) VALUES
('b019488a-aaaa-4444-8888-000000000001', 'a019488a-1111-4444-8888-000000000001'),
('b019488a-aaaa-4444-8888-000000000001', 'a019488a-2222-4444-8888-000000000002')
ON CONFLICT DO NOTHING;

-- 프롬프트 B(학용품 목업)에 [#새학기], [#목업] 태그 연결
INSERT INTO public.prompt_tags (prompt_id, tag_id) VALUES
('b019488a-bbbb-4444-8888-000000000002', 'a019488a-1111-4444-8888-000000000001'),
('b019488a-bbbb-4444-8888-000000000002', 'a019488a-3333-4444-8888-000000000003')
ON CONFLICT DO NOTHING;

-- 프롬프트 C(대학 캠퍼스)에 [#새학기], [#실사사진] 태그 연결
INSERT INTO public.prompt_tags (prompt_id, tag_id) VALUES
('b019488a-cccc-4444-8888-000000000003', 'a019488a-1111-4444-8888-000000000001'),
('b019488a-cccc-4444-8888-000000000003', 'a019488a-4444-4444-8888-000000000004')
ON CONFLICT DO NOTHING;