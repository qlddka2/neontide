/* 로그인 서버 설정 — 퇴마·맞수와 같은 Supabase 프로젝트. 아래 두 값은 '공개용'이라 저장소에 올려도 됩니다.
   (절대 넣으면 안 되는 것: service_role 키, DB 비밀번호, Google Client Secret) */
window.NT_CONFIG = {
  // 'beta' = 모두에게 전부 열림(의견 받기용), 테스트 모드는 정식판 권한 계정(개발자)만
  // 'paid' = 체험판(기본 낚시꾼 3명 · 1막까지) + 정식판(2,400원 → 할인 1,300원) — 판매 시작할 때 바꾸기
  mode: 'beta',
  supabaseUrl: 'https://rofphqdqwxmjkypmjtok.supabase.co',
  supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvZnBocWRxd3htamt5cG1qdG9rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0NTc5NDAsImV4cCI6MjEwNzAzMzk0MH0.4YtLlwxtzx-s0xX7SCQv7mbgN_RIsXpdh6LuFCY9WMI'
};
