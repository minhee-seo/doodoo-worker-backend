# Doodoo 백엔드·콘텐츠 탐색 설계

## 1. 목표와 최종 구조

Doodoo는 비회원 공개 사용자가 디자인 레퍼런스를 탐색하고, 몇 번의 선택만으로 AI 이미지 생성 프롬프트를 완성·복사하는 서비스다. 운영은 저비용으로 시작하되, 공개 읽기 요청이 급증해도 원점 서버와 DB가 병목이 되지 않도록 설계한다.

```text
Browser → Cloudflare CDN / WAF / Rate Limit
        → Next.js 웹 (Cloudflare Workers)
        → API Worker (Hono)
             ├─ Supabase Postgres
             └─ Cloudflare R2
                  └─ https://img.doodoostock.com/...
```

- **Next.js**: SEO가 필요한 목록·상세 화면을 렌더링한다.
- **Cloudflare Worker + Hono**: 공개 API, 관리자 API, 캐시 제어, 입력 검증을 담당한다.
- **Supabase Postgres**: 프롬프트 메타데이터, 카테고리, 태그, 편집 규칙, 발행 상태를 저장한다.
- **Cloudflare R2**: 모든 대표·상세 이미지를 저장한다. 공개 응답에는 R2 키가 아니라 `https://img.doodoostock.com/<key>` URL만 제공한다.

이미지는 브라우저가 `img.doodoostock.com`에서 직접 가져오게 해 API Worker와 DB를 거치지 않게 한다. `Cache-Control: public, max-age=31536000, immutable`을 적용하고, 교체가 필요할 경우 파일명을 `prompt-id/version.webp`처럼 버전 관리한다.

## 2. 콘텐츠와 2단계 카테고라이징

대분류는 고정된 6개다.

| slug | 표시명 |
| --- | --- |
| `promo-poster` | 홍보포스터 |
| `social-content` | 소셜콘텐츠 |
| `brand-mockup` | 브랜드목업 |
| `typography` | 타이포그래피 |
| `illustration` | 일러스트 |
| `photorealistic` | 사진실사 |

탐색은 두 단계로 고정한다.

1. **1단계: 카테고리** — 홈·메뉴에서 대분류 하나를 선택한다.
2. **2단계: 필터** — 해당 카테고리에서 태그와 서브 옵션을 AND 조건으로 좁힌다. 태그는 공통 속성(예: `minimal`, `blue`, `luxury`)이고, 서브 옵션은 카테고리 전용 선택지(예: 홍보포스터의 `event`, `sale`, `concert`)다.

카테고리별 페이지는 가능한 태그·서브 옵션과 결과 수를 함께 반환한다. 선택 필터는 URL 쿼리에 유지한다.

```text
/categories/promo-poster?tags=minimal,luxury&subtype=event
```

태그는 다중 선택 가능, 서브 옵션은 MVP에서 하나만 선택 가능하게 한다. 결과가 없으면 가장 최근 선택한 태그를 해제할 수 있는 안내와 해당 카테고리의 인기 항목을 보여 준다.

## 3. 데이터 모델

### 핵심 테이블

- `categories`: `id`, `slug`, `name`, `sort_order`, `is_active`
- `sub_options`: `id`, `category_id`, `slug`, `name`, `sort_order`, `is_active`
- `tags`: `id`, `slug`, `name`, `group`(선택), `is_active`
- `prompts`: `id`, `slug`, `title`, `summary`, `category_id`, `sub_option_id`, `base_prompt`, `edit_fields`(JSONB), `image_key`, `image_alt`, `status`, `published_at`, `sort_order`
- `prompt_tags`: `prompt_id`, `tag_id`
- `prompt_events`: `id`, `prompt_id`, `event_type`, `created_at` — `view`와 `copy` 집계용

`image_key`는 `prompts/123/hero-v1.webp`만 저장한다. API 응답 계층에서 `https://img.doodoostock.com/${image_key}`로 변환해 반환한다. 도메인 변경이나 R2 구조 변경 시 DB를 일괄 수정하지 않기 위해서다.

`edit_fields`는 이미지마다 다른 편집 인터페이스를 표현하는 JSONB다.

```json
[
  {
    "key": "headline",
    "label": "메인 문구",
    "type": "text",
    "defaultValue": "SUMMER SALE",
    "template": "Use the headline text: '{{value}}'."
  },
  {
    "key": "palette",
    "label": "색감",
    "type": "select",
    "options": [
      { "label": "오렌지", "fragment": "warm orange palette" },
      { "label": "블루", "fragment": "muted blue palette" }
    ]
  }
]
```

타이포가 없는 풍경·사진실사 콘텐츠는 `headline` 필드를 넣지 않는다. 프론트는 받은 필드만 렌더링하고, 최종 문구는 `base_prompt`와 유효한 선택값의 템플릿/조각을 순서대로 결합한다.

## 4. API와 캐시 정책

### 공개 API

- `GET /v1/prompts/:slug` — 상세와 편집 필드 반환
- `GET /v1/categories/:slug` — 필터 메타데이터 및 콘텐츠 목록 반환
- `GET /v1/search?q=` — 제목·태그 기반 검색 및 자동완성, 최대 8건
- `POST /v1/events/copy` — 복사 이벤트 기록

상세·카테고리 응답은 Worker Cache API와 CDN에 5분 캐시한다. 발행·수정·비공개 처리 시 해당 slug와 카테고리 URL을 purge한다. 검색·자동완성은 30초만 캐시하고, 입력은 클라이언트에서 300ms 디바운스한다. `copy` 이벤트는 Queue로 보내 비동기 처리하여 DB 쓰기 폭주를 막는다.

### 관리자 API

- `POST/PATCH /v1/admin/prompts` — 콘텐츠 초안, 편집 항목, 카테고리·태그 설정
- `POST /v1/admin/uploads/sign` — R2 직접 업로드용 제한된 서명 URL 발급
- `POST /v1/admin/prompts/:id/publish` — 검증 후 발행 및 캐시 purge

관리자 API는 Supabase Auth JWT와 `admin` 역할을 확인한다. 공개 API는 발행된 콘텐츠만 반환한다. API 입력은 Zod로 검증하고, 검색·이벤트·업로드 서명 엔드포인트에는 IP 기반 rate limit을 적용한다.

## 5. 구현 순서와 완료 기준

1. Supabase 스키마·RLS·시드 데이터: 6개 카테고리와 공통 태그를 등록한다.
2. R2 커스텀 도메인: `img.doodoostock.com`을 버킷에 연결하고 업로드 키/캐시 규칙을 설정한다.
3. API Worker: 목록·상세·검색을 구현하고, 카테고리/태그/서브 옵션 조합을 검증한다.
4. Next.js 연결: URL 기반 2단계 필터, 동적 편집 폼, 실시간 최종 프롬프트, 복사 토스트를 연결한다.
5. 관리자·관측성: 콘텐츠 발행, R2 직접 업로드, 캐시 purge, 오류 로그와 요청 지표를 완성한다.

완료 시 6개 카테고리를 탐색할 수 있고, 카테고리 내 태그/서브 옵션으로 결과를 좁힐 수 있어야 한다. 이미지마다 다른 편집 폼이 표시되고 복사 문구에 정확히 반영되어야 한다. 공개 이미지와 캐시된 읽기 요청은 Supabase를 호출하지 않아야 하며, 관리자 변경은 다음 요청에서 갱신된 결과를 보여야 한다.

## 6. 운영 기본값

- Next.js와 API Worker는 Cloudflare에 배포하고, PostgreSQL·인증은 Supabase를 사용한다.
- R2 버킷은 비공개로 유지하고 custom domain을 통해서만 읽기 공개한다.
- 사용자 계정, 북마크, 댓글은 MVP 범위에서 제외한다.
- 도구별 프롬프트 문법은 공통 프롬프트 MVP 이후 `tool_variants`로 확장한다.
