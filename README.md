# 📸 DooDoo - 저작권 프리 이미지 다운로드 웹사이트

> **회원가입 없는 빠른 다운로드, 저작권 걱정 없는 무료 이미지 서비스**
> 실제 운영 시 발생하는 비용 효율화와 대규모 데이터의 검색 노출(SEO)을 엔지니어링 관점에서 해결하는 데 집중했습니다.


## 🚀 DEMO
**서비스 링크**: [https://www.doodoostock.com/](https://www.doodoostock.com/)
<img width="1285" height="742" alt="Image" src="https://github.com/user-attachments/assets/f8dd1852-0204-4378-8a07-17e38655dfce" />

---

## 🛠️ 기술 스택

| 영역 | 기술 |
|------|------|
| **Frontend** | Next.js 16 (App Router), React 19, TypeScript 5 |
| **Styling** | Tailwind CSS 4.0, SASS (SCSS Modules) |
| **Backend** | Cloudflare Workers (Serverless Edge) |
| **Database** | Supabase (PostgreSQL) |
| **Storage** | Cloudflare R2 (Object Storage) |
| **Deploy** | Vercel (Frontend), Cloudflare (Backend/Storage) |
| **Optimization** | React Compiler (Babel Plugin) |

---

## 🗂️ 아키텍처

```
Client (Next.js / Vercel)
        │
        ▼
Cloudflare Workers  ─── PUBLIC_ASSETS (R2)   ← 썸네일 · 프리뷰 (CDN 공개)
        │           ─── PRIVATE_ORIGINALS (R2) ← 원본 파일 (Presigned URL 전용)
        │           ─── VIEW_COUNT_KV          ← 조회수 버퍼 (10분 배치 플러시)
        │
        ▼
Supabase (PostgreSQL)
```

요청 흐름: `src/index.ts` (라우팅 + CORS) → `src/handlers/` (엔드포인트별 핸들러) → `src/lib/` · `src/utils/` (Supabase 클라이언트, 인증 미들웨어) → Supabase / R2


## 🔍 기술적 도전과 해결 과정

 **왜 이 방식을 선택했는지** 를 중심으로 주요 개발 과정을 정리했습니다.

### 1. 원본 파일 보안 — R2 버킷을 두 개로 나눈 이유

**문제 상황**

처음엔 R2 버킷 하나에 모든 파일을 올리고 공개(public) 설정을 했습니다. 그런데 원본 고해상도 파일까지 URL만 알면 누구든 무제한으로 다운로드할 수 있다는 걸 뒤늦게 깨달았습니다.

**공부한 것**

S3-compatible 스토리지의 Presigned URL 에 대해 알게됐습니다. "특정 사용자에게, 특정 파일에 대해, 특정 시간 동안만 유효한 URL을 발급"하는 방식입니다. Cloudflare R2는 AWS S3 호환 API를 지원하기 때문에 `@aws-sdk/s3-request-presigner` 를 그대로 사용할 수 있었습니다.

**해결**

버킷을 두 개로 분리했습니다.

```
PUBLIC_ASSETS     → 썸네일 · 프리뷰 이미지 (CDN 직접 서빙, 공개)
PRIVATE_ORIGINALS → 원본 파일 (비공개, Presigned URL로만 접근)
```

`/api/download` 엔드포인트에서 DB로 파일 경로를 확인한 뒤, 유효 시간 1시간의 Presigned URL을 생성해 클라이언트에 반환합니다.

```typescript
// src/handlers/download.ts
const presignedUrl = await getSignedUrl(s3Client, command, {
  expiresIn: 3600,
});
```

---

### 2. workers KV 조회수 집계 — DB에 조회수를 실시간으로 반영하지 않은 이유

**문제 상황**

이미지 상세 페이지 진입 시마다 Supabase에 `UPDATE images SET views = views + 1` 을 날렸을 때, 동시 요청이 몰리면 DB 커넥션이 병목 또는   새로고침이나 크롤러로 조회수가 쓸모없이 증가해 DB에 부담이 갈 것을 예상했습니다.

**공부한 것**

"Write Buffer + Batch Flush" 패턴을 공부했습니다. Redis나 KV 같은 인메모리 저장소에 카운터를 쌓다가 주기적으로 DB에 한 번에 반영하는 방식입니다. Cloudflare에는 KV 네임스페이스가 있고, Workers Cron Trigger로 주기적 실행이 가능하다는 걸 알게 됐습니다.

**해결**

3단계로 구성했습니다.

1. **쿠키 중복 방지**: `viewed_{imageId}` 쿠키를 24시간 TTL로 발급해 같은 클라이언트의 중복 카운트를 차단합니다.
2. **KV 버퍼**: 쿠키가 없는 새 방문자의 조회수를 `VIEW_COUNT_KV`에 적립합니다.
3. **배치 플러시**: 10분 간격 Cron이 KV의 모든 카운터를 읽어 Supabase RPC(`increment_image_view_count`)를 호출하고 KV를 비웁니다.

실제 요청마다 실행되는 `handleViewIncrement.ts`가 쿠키 확인 → KV 적립 → 응답 쿠키 세팅을 담당합니다.

```typescript
// src/handlers/handleViewIncrement.ts — 요청마다 실행
const cookieName = `viewed_${id}`;
if (request.headers.get('Cookie')?.includes(cookieName)) {
  return; // 24시간 내 재방문 → KV 적립 없이 스킵
}

// DB 대신 KV에 카운트 1 적립 (메모리 기반, 비용 최소)
const key = `view_count:${id}`;
const current = parseInt(await env.VIEW_COUNT_KV.get(key) || '0', 10);
await env.VIEW_COUNT_KV.put(key, (current + 1).toString());

// 쿠키 발급으로 24시간 중복 카운트 차단
headers.set('Set-Cookie', `${cookieName}=true; Max-Age=86400; HttpOnly; Path=/`);
```

10분마다 Cron이 이 KV 데이터를 DB로 일괄 반영합니다.

```
// wrangler.jsonc
"triggers": { "crons": ["*/10 * * * *"] }
```

```typescript
// src/handlers/handleBatchUpdate.ts — 10분마다 실행
const keys = await kv.list({ prefix: 'view_count:' });
for (const key of keys.keys) {
  const count = await kv.get(key.name);
  await supabase.rpc('increment_image_view_count', {
    p_image_id: imageId,
    p_increment_by: Number(count),
  });
  await kv.delete(key.name);
}
```

---

### 3. SEO — 서버리스 환경에서 사이트맵 생성

**문제**

스톡 이미지 서비스에서 SEO는 핵심입니다. 그런데 이미지가 계속 추가되므로 사이트맵을 정적 파일로 관리하기 어렵습니다. Next.js의 `app/sitemap.ts`에서 빌드 타임에 생성하면 최신 이미지가 반영되지 않는 문제가 있었습니다.

**해결**

`/api/sitemap-data` 엔드포인트를 Workers에 추가해 Supabase에서 전체 이미지 목록을 실시간으로 제공하고, Next.js 사이트맵 생성 함수가 이 엔드포인트를 호출하도록 했습니다.

```typescript
// src/handlers/sitemapData.ts
const { data } = await supabase
  .from('images')
  .select('id, uploaded_at, preview_url');
```

---

### 4. 관리자 API 라우팅 — 관문(Gatekeeper) 패턴으로 권한을 일괄 보호한 이유

**문제**

관리자 엔드포인트가 늘어날수록 각 핸들러마다 인증 코드를 붙이면 빠뜨릴 여지가 생깁니다. 나중에 인증 방식을 바꿔야 할 때 수정 범위도 넓어집니다.

**해결**

`src/index.ts`에서 `/admin/*` 경로를 한 곳에서 가로채 JWT를 검증하고, 통과한 요청만 각 핸들러로 넘기는 관문 구조를 만들었습니다. 로그인 엔드포인트(`/admin/auth POST`) 하나만 예외로 두고, 나머지는 전부 이 관문을 통과해야 합니다.

```
/admin/* 요청 수신
    ↓
pathname === '/admin/auth' && POST?
    ├─ Yes → 검증 없이 handleAdminAuth()  (로그인 자체는 예외)
    └─ No  → Authorization: Bearer <token> 헤더 확인
                ├─ 없음 → 401 인증 필요
                └─ 있음 → verifyAdminToken() 호출
                            ├─ 실패 → 403 권한 없음
                            └─ 성공 → 각 관리자 핸들러 실행
```

```typescript
// src/index.ts — 관리자 미들웨어 (일부 발췌)
if (url.pathname.startsWith('/admin')) {
  if (url.pathname === '/admin/auth' && request.method === 'POST') {
    return handleAdminAuth(request, env);
  }

  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: '인증이 필요합니다.' }), { status: 401, headers: CORS_HEADERS });
  }

  const isAdmin = await verifyAdminToken(authHeader.split(' ')[1], env);
  if (!isAdmin) {
    return new Response(JSON.stringify({ error: '권한이 없습니다.' }), { status: 403, headers: CORS_HEADERS });
  }
}
// 이후 handleGetImages, handleImageUpload, handleImageEdit 등은 인증 로직 없이 비즈니스 로직에만 집중
```

**얻은 것**

핸들러 코드에 인증 로직이 전혀 없고, 인증 방식을 바꾸거나 관리자 경로를 추가할 때 `src/index.ts` 한 곳만 수정하면 됩니다.

---

## 엔드포인트 목록

### Public API

| 엔드포인트 | 메서드 | 설명 |
|---|---|---|
| `/api/search` | GET | 키워드·카테고리 검색 (페이지네이션) |
| `/api/photo` | GET | 이미지 상세 조회 (파일 포맷별 정보 포함) |
| `/api/download` | GET | 원본 파일 Presigned URL 발급 |
| `/api/similar` | GET | 유사 이미지 추천 |
| `/api/categories` | GET | 카테고리 목록 |
| `/api/sitemap-data` | GET | SEO 사이트맵용 이미지 목록 |

### Admin (JWT 인증 필요)

| 엔드포인트 | 메서드 | 설명 |
|---|---|---|
| `/admin/auth` | POST | 관리자 로그인 |
| `/admin/images` | GET | 이미지 목록 조회 |
| `/admin/images/upload` | POST | 이미지 배치 업로드 |
| `/admin/images/edit/:id` | GET · PATCH · POST · DELETE | 이미지 CRUD |
| `/admin/images/delete` | DELETE | 이미지 일괄 삭제 |

---

