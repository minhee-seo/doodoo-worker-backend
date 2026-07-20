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
  id, slug, title, summary, category_id, sub_option_id, base_prompt, edit_fields, image_thumbnail_key, image_preview_key, image_alt, status, published_at
) VALUES (
  'b019488a-aaaa-4444-8888-000000000001',
  'new-semester-3d-character',
  '{"ko": "새학기 초등학생 등교길 3D 일러스트", "en": "3D Illustration of Elementary Student Going to School"}'::jsonb,
  '{"ko": "설레는 마음으로 등교하는 귀여운 초등학생 캐릭터 3D 일러스트 프롬프트입니다.", "en": "3D illustration prompt of a cute elementary school student walking to school with excitement."}'::jsonb,
  (SELECT id FROM public.categories WHERE slug = 'illustration' LIMIT 1),
  NULL,
  'A cute 3D character of a young student wearing a backpack, walking towards school, cherry blossoms blowing, warm pastel colors, soft clay render, octane render, 8k --ar 16:9',
  '[]'::jsonb,
  'images/thumbnails/new-semester-3d-character.jpg',
  'images/previews/new-semester-3d-character.jpg',
  '새학기 등교하는 3D 학생 캐릭터 일러스트',
  'published',
  now()
) ON CONFLICT (slug) DO NOTHING;

-- [프롬프트 B] 새학기 학용품 목업 사진
INSERT INTO public.prompts (
  id, slug, title, summary, category_id, sub_option_id, base_prompt, edit_fields, image_thumbnail_key, image_preview_key, image_alt, status, published_at
) VALUES (
  'b019488a-bbbb-4444-8888-000000000002',
  'new-semester-stationery-mockup',
  '{"ko": "새학기 심플 학용품 배치 및 노트 목업", "en": "Simple Back to School Stationery Layout & Notebook Mockup"}'::jsonb,
  '{"ko": "파스텔톤의 노트, 연필, 가위가 정갈하게 배치된 신학기 감성 목업 프롬프트입니다.", "en": "A back-to-school emotional mockup prompt featuring neatly arranged pastel-toned notebooks, pencils, and scissors."}'::jsonb,
  (SELECT id FROM public.categories WHERE slug = 'branding-mockups' LIMIT 1),
  NULL,
  'Flat lay of pastel-toned school stationery, notebooks, pencils on a clean mint background, minimalist aesthetic, commercial branding photography, soft natural lighting --ar 4:3',
  '[]'::jsonb,
  'images/thumbnails/new-semester-stationery-mockup.jpg',
  'images/previews/new-semester-stationery-mockup.jpg',
  '파스텔톤 학용품과 노트 목업 이미지',
  'published',
  now()
) ON CONFLICT (slug) DO NOTHING;

-- [프롬프트 C] 새학기 대학생 캠퍼스 풍경 (실사)
INSERT INTO public.prompts (
  id, slug, title, summary, category_id, sub_option_id, base_prompt, edit_fields, image_thumbnail_key, image_preview_key, image_alt, status, published_at
) VALUES (
  'b019488a-cccc-4444-8888-000000000003',
  'new-semester-college-campus',
  '{"ko": "새학기 벚꽃 피는 대학 캠퍼스 실사", "en": "Realistic Photo of University Campus with Cherry Blossoms"}'::jsonb,
  '{"ko": "화창한 봄날, 벚꽃이 흩날리는 평화로운 대학교 캠퍼스 풍경의 실사 일러스트/사진 프롬프트입니다.", "en": "A realistic photo prompt of a peaceful university campus scenery with scattered cherry blossoms on a sunny spring day."}'::jsonb,
  (SELECT id FROM public.categories WHERE slug = 'photography' LIMIT 1),
  NULL,
  'A cinematic photo of a beautiful university campus in spring, cherry blossom trees in full bloom, college students walking in the background, sun flare, captured on 35mm lens, highly detailed --ar 16:9',
  '[]'::jsonb,
  'images/thumbnails/new-semester-college-campus.jpg',
  'images/previews/new-semester-college-campus.jpg',
  '봄날 벚꽃이 만개한 캠퍼스 풍경 실사',
  'published',
  now()
) ON CONFLICT (slug) DO NOTHING;

WITH seed_prompts (
  id, slug, title_ko, title_en, summary_ko, summary_en, category_slug, base_prompt, img_base_name, image_alt, sort_order
) AS (
  VALUES
    (
      'b019488a-dddd-4444-8888-000000000004'::uuid, 'new-semester-class-schedule-poster',
      '새학기 시간표 안내 포스터', 'New Semester Class Schedule Poster',
      '밝고 깔끔한 색감으로 구성한 신학기 시간표 및 수업 안내 포스터 프롬프트입니다.', 'A clean new semester timetable and class guide poster prompt built with bright colors.',
      'marketing', 'A clean Korean school timetable poster for a new semester, bright blue and yellow palette, friendly icons, modern editorial layout, high resolution',
      'new-semester-class-schedule-poster.jpg', '새학기 시간표 안내 포스터', 4
    ),
    (
      'b019488a-eeee-4444-8888-000000000005'::uuid, 'new-semester-school-bus-illustration',
      '새학기 학교 버스 일러스트', 'New Semester School Bus Illustration',
      '등교 첫날의 활기찬 분위기를 담은 스쿨버스 일러스트 프롬프트입니다.', 'A school bus illustration prompt capturing the lively atmosphere of the first day of school.',
      'illustration', 'Whimsical illustration of a yellow school bus arriving on the first day of a new semester, smiling students with backpacks, spring morning, soft pastel colors',
      'new-semester-school-bus-illustration.jpg', '새학기 학교 버스 일러스트', 5
    ),
    (
      'b019488a-ffff-4444-8888-000000000006'::uuid, 'new-semester-notebook-cover-mockup',
      '새학기 노트 표지 브랜딩 목업', 'New Semester Notebook Cover Branding Mockup',
      '문구 브랜드에 활용할 수 있는 신학기 노트 표지 목업 프롬프트입니다.', 'A back to school notebook cover mockup prompt that can be used for stationery branding.',
      'branding-mockups', 'Premium notebook cover mockup for a back to school stationery brand, clean desk, embossed logo, pastel pink and navy colors, soft studio lighting',
      'new-semester-notebook-cover-mockup.jpg', '새학기 노트 표지 브랜딩 목업', 6
    ),
    (
      'b019488a-1111-5555-8888-000000000007'::uuid, 'new-semester-typography-quote',
      '새학기 응원 타이포그래피', 'New Semester Supportive Typography',
      '새로운 시작을 응원하는 감성적인 한글 타이포그래피 포스터 프롬프트입니다.', 'An emotional Korean typography poster prompt cheering for a fresh new start.',
      'typography', 'Expressive Korean typography poster with the phrase 새로운 시작, bold hand lettering, paper texture, optimistic new semester mood, cream and coral palette',
      'new-semester-typography-quote.jpg', '새로운 시작 한글 타이포그래피 포스터', 7
    ),
    (
      'b019488a-2222-5555-8888-000000000008'::uuid, 'new-semester-library-photo',
      '새학기 도서관 공부 책상 실사', 'Realistic Photo of New Semester Library Study Desk',
      '햇살이 들어오는 도서관에서 공부를 준비하는 신학기 분위기의 실사 프롬프트입니다.', 'A realistic photo prompt capturing a new semester atmosphere of preparing to study in a sunlit library.',
      'photography', 'Realistic photo of a student study desk in a sunlit university library, open textbooks, laptop, coffee, fresh new semester atmosphere, 50mm photography',
      'new-semester-library-photo.jpg', '새학기 도서관 공부 책상 실사', 8
    ),
    (
      'b019488a-3333-5555-8888-000000000009'::uuid, 'new-semester-club-recruitment-card-news',
      '새학기 동아리 모집 카드뉴스', 'New Semester Club Recruitment Social Media Card News',
      '대학 동아리 신입 부원 모집에 활용할 수 있는 카드뉴스 프롬프트입니다.', 'A card news template prompt suitable for recruiting new members for university clubs.',
      'marketing', 'Colorful social media card news design for university club recruitment, energetic student illustrations, clear information hierarchy, vibrant purple and lime palette',
      'new-semester-club-recruitment-card-news.jpg', '새학기 동아리 모집 카드뉴스', 9
    ),
    (
      'b019488a-4444-5555-8888-000000000010'::uuid, 'new-semester-backpack-product-photo',
      '새학기 백팩 제품 사진', 'Back to School Backpack Commercial Product Photo',
      '학생용 백팩의 기능과 색감을 강조하는 커머스용 제품 사진 프롬프트입니다.', 'A commerce product photography prompt highlighting the functions and colors of a student backpack.',
      'photography', 'Commercial product photo of a stylish student backpack on a light blue studio background, school supplies beside it, crisp softbox lighting, premium ecommerce style',
      'new-semester-backpack-product-photo.jpg', '새학기 학생용 백팩 제품 사진', 10
    )
)
INSERT INTO public.prompts (
  id, slug, title, summary, category_id, base_prompt, edit_fields,
  image_thumbnail_key, image_preview_key, image_alt, status, published_at, sort_order
)
SELECT
  s.id,
  s.slug,
  jsonb_build_object('ko', s.title_ko, 'en', s.title_en),
  jsonb_build_object('ko', s.summary_ko, 'en', s.summary_en),
  c.id,
  s.base_prompt,
  '[]'::jsonb,
  'images/thumbnails/' || s.img_base_name,
  'images/previews/' || s.img_base_name,
  s.image_alt,
  'published',
  now(),
  s.sort_order
FROM seed_prompts s
JOIN public.categories c ON c.slug = s.category_slug
ON CONFLICT (slug) DO NOTHING;

-- ==========================================
-- 3. 프롬프트와 태그 매핑 등록 (다대다 관계 완성)
-- ==========================================

-- 프롬프트 A(3D 캐릭터)에 [#새학기], [#일러스트] 태그 연결
INSERT INTO public.prompt_tags (prompt_id, tag_id) VALUES
('b019488a-aaaa-4444-8888-000000000001', 'a019488a-1111-4444-8888-000000000001'),
('b019488a-aaaa-4444-8888-000000000001', 'a019488a-2222-4444-8888-000000000002'),
('b019488a-bbbb-4444-8888-000000000002', 'a019488a-1111-4444-8888-000000000001'),
('b019488a-bbbb-4444-8888-000000000002', 'a019488a-3333-4444-8888-000000000003'),
('b019488a-cccc-4444-8888-000000000003', 'a019488a-1111-4444-8888-000000000001'),
('b019488a-cccc-4444-8888-000000000003', 'a019488a-4444-4444-8888-000000000004')
ON CONFLICT DO NOTHING;

INSERT INTO public.prompt_tags (prompt_id, tag_id)
SELECT prompt_id, tags.id
FROM (
  VALUES
    ('b019488a-dddd-4444-8888-000000000004'::uuid, 'new-semester'),
    ('b019488a-dddd-4444-8888-000000000004'::uuid, 'poster'),
    ('b019488a-eeee-4444-8888-000000000005'::uuid, 'new-semester'),
    ('b019488a-eeee-4444-8888-000000000005'::uuid, 'illustration'),
    ('b019488a-ffff-4444-8888-000000000006'::uuid, 'new-semester'),
    ('b019488a-ffff-4444-8888-000000000006'::uuid, 'mockup'),
    ('b019488a-1111-5555-8888-000000000007'::uuid, 'new-semester'),
    ('b019488a-2222-5555-8888-000000000008'::uuid, 'new-semester'),
    ('b019488a-2222-5555-8888-000000000008'::uuid, 'photo'),
    ('b019488a-3333-5555-8888-000000000009'::uuid, 'new-semester'),
    ('b019488a-3333-5555-8888-000000000009'::uuid, 'card-news'),
    ('b019488a-4444-5555-8888-000000000010'::uuid, 'new-semester'),
    ('b019488a-4444-5555-8888-000000000010'::uuid, 'photo')
) AS mappings (prompt_id, tag_slug)
JOIN public.tags ON tags.slug = mappings.tag_slug
ON CONFLICT DO NOTHING;


-- 
-- 
-- 
-- 
-- ==========================================
-- 3. 서브 옵션 동적 FK 연동 (Typography 카테고리 하위에 3D Text 추가)
-- ==========================================
INSERT INTO public.sub_options (id, category_id, slug, name, sort_order)
SELECT 
  '22222222-2222-2222-2222-222222222222'::uuid,
  c.id, -- slug가 'typography'인 카테고리의 실제 ID를 동적으로 조인
  '3d-text',
  '3D Text',
  1
FROM public.categories c
WHERE c.slug = 'typography'
ON CONFLICT (category_id, slug) DO UPDATE SET name = EXCLUDED.name;

-- ==========================================
-- 4. Y2K 젤리 텍스트 프롬프트 등록 (동적 FK 참조)
-- ==========================================
INSERT INTO public.prompts (
  id,
  slug,
  title,
  summary,
  category_id,
  sub_option_id,
  base_prompt,
  edit_fields,
  image_thumbnail_key,
  image_preview_key,
  image_alt,
  status,
  published_at,
  sort_order
)
SELECT
  '99999999-9999-9999-9999-999999999999'::uuid,
  'y2k-glossy-jelly-typography-poster',
  '{"ko": "영롱한 Y2K 입체 젤리 텍스트 포스터", "en": "Y2K Glossy Jelly Typography Poster"}'::jsonb,
  '{"ko": "투명하고 오팔빛이 도는 핑크 젤리 질감의 3D 타이포그래피 포스터 프롬프트입니다.", "en": "A premium typography poster with translucent glossy jelly-text lettering."}'::jsonb,
  c.id,  -- typography 카테고리 ID 동적 연동
  s.id,  -- 3d-text 서브 옵션 ID 동적 연동
  '[Purpose]
Create a premium typography-focused poster featuring glossy translucent jelly-text lettering with a dreamy Y2K aesthetic. Generate a clean commercial-quality design that highlights the typography as the main visual element while maintaining a cute, luxurious, and highly shareable social-media-friendly appearance.

[Scene]
A minimal pastel pink studio backdrop with a soft gradient background and abundant negative space. Small floating decorative elements including glossy hearts and sparkling star icons are placed around the typography to create a playful, dreamy, and feminine atmosphere. The environment is clean, uncluttered, and visually balanced.

[Main Subject]
The primary focus is a large 3D jelly-text typography displaying "{{MAIN_TEXT}}". The letters are inflated, rounded, soft, and balloon-like, made from translucent glossy gel material with subtle transparency and a pearlescent iridescent finish. The surface reflects soft pink, lavender, and white highlights, creating a premium liquid-glass appearance. Additional matching decorative hearts and sparkles float around the text using the same translucent material.

[Style]
Y2K aesthetic, glossy liquid typography, translucent jelly material, kawaii luxury design, dreamcore aesthetic, soft pastel palette, Pinterest-inspired graphic design, Korean visual trend style, premium commercial render, cute luxury branding, clean minimalism, highly polished 3D illustration, modern social-media poster design.

[Composition]
Centered symmetrical composition with the typography occupying approximately seventy percent of the frame. Decorative hearts and sparkle elements are distributed evenly around the text. Large negative space surrounds the subject to enhance readability and luxury appeal. Main title positioned in the center, optional subtitle beneath the title, and optional descriptive copy at the bottom. Balanced spacing and strong visual hierarchy.

[Lighting]
Soft studio lighting with diffused illumination, gentle ambient glow, subtle rim lighting around the typography, smooth reflections across the glossy surface, soft internal light scattering inside the translucent material, delicate shadows, bright pastel reflections, and no harsh contrast.

[Text]
Main headline: "{{Jelly}}"
Subtitle: "{{Sweet Dream}}"
Description: "{{I''ve never seen the text so sweet}}"

[Color Palette]
Soft blush pink, pastel rose, pearl white, pale lavender, subtle holographic reflections, iridescent rainbow highlights, creamy beige background, soft candy-inspired tones, low-saturation pastel colors, luxury beauty-brand color grading.

[Material]
Ultra-glossy translucent jelly material, liquid glass texture, inflated gel appearance, pearlescent coating, soft refraction, smooth rounded edges, crystal-clear highlights, realistic light transmission, premium cosmetic-advertisement quality material rendering.

[Camera]
Front-facing view, centered framing, slight telephoto perspective, orthographic-like product presentation, sharp focus on typography, high-resolution render, commercial poster presentation.

[Mood]
Cute, dreamy, playful, feminine, luxurious, trendy, aesthetic, modern, charming, soft, uplifting, elegant, premium, youthful, fashionable.

[Constraints]
No people, no realistic environment, no complex scenery, no cluttered composition, no dark mood, no harsh shadows, no excessive decoration, no metallic materials, no grunge textures, no visible noise, no low-resolution details, no typography distortion, maintain perfect text readability, ultra-clean background, premium advertising quality, high detail, 8K render.',
  '[
    {
      "key": "MAIN_TEXT",
      "label": "메인 텍스트 (3D)",
      "type": "text",
      "default": "Jelly"
    },
    {
      "key": "Jelly",
      "label": "메인 헤드라인",
      "type": "text",
      "default": "Jelly"
    },
    {
      "key": "Sweet Dream",
      "label": "서브 타이틀",
      "type": "text",
      "default": "Sweet Dream"
    },
    {
      "key": "I''ve never seen the text so sweet",
      "label": "하단 문구",
      "type": "text",
      "default": "I''ve never seen the text so sweet"
    }
  ]'::jsonb,
  'images/thumbnails/y2k-glossy-jelly-typography-poster-thumb.png',
  'images/previews/y2k-glossy-jelly-typography-poster-preview.png',
  'Pink glossy translucent 3D jelly typography reading Jelly Sweet Dream',
  'published',
  now(),
  1
FROM public.categories c
JOIN public.sub_options s ON s.category_id = c.id AND s.slug = '3d-text'
WHERE c.slug = 'typography'
ON CONFLICT (slug) DO UPDATE
SET 
  title = EXCLUDED.title,
  base_prompt = EXCLUDED.base_prompt,
  edit_fields = EXCLUDED.edit_fields;

-- ==========================================
-- 5. 프롬프트 - 태그 매핑 (동적 태그 ID 매핑)
-- ==========================================
INSERT INTO public.prompt_tags (prompt_id, tag_id)
SELECT 
  '99999999-9999-9999-9999-999999999999'::uuid,
  t.id
FROM public.tags t
WHERE t.slug IN ('poster', '3d-character', 'pastel-tone')
ON CONFLICT (prompt_id, tag_id) DO NOTHING;

COMMIT;