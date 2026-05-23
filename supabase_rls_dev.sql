-- ─── Ghars Dev: منح صلاحية القراءة لمفتاح anon ─────────────────
-- شغّل هذا في Supabase SQL Editor مرة واحدة

-- تفعيل RLS وإضافة سياسة قراءة لكل جدول مطلوب

ALTER TABLE "Garden"      ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Plant"       ENABLE ROW LEVEL SECURITY;
ALTER TABLE "PlantCatalog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Schedule"    ENABLE ROW LEVEL SECURITY;

-- قراءة مفتوحة للـ anon (مرحلة التطوير — سنقيّدها بـ auth.uid() لاحقاً)
CREATE POLICY "dev_anon_read" ON "Garden"
  FOR SELECT TO anon USING (true);

CREATE POLICY "dev_anon_read" ON "Plant"
  FOR SELECT TO anon USING (true);

CREATE POLICY "dev_anon_read" ON "PlantCatalog"
  FOR SELECT TO anon USING (true);

CREATE POLICY "dev_anon_read" ON "Schedule"
  FOR SELECT TO anon USING (true);
