-- EpiSign schema
-- Run this in Supabase SQL Editor or as a migration

-- Students (linked to auth.users)
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Teachers (TOTP secrets — never exposed to clients)
CREATE TABLE IF NOT EXISTS teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    totp_secret TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Courses
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    date DATE NOT NULL,
    slot TEXT NOT NULL CHECK (slot IN ('morning', 'afternoon')),
    room TEXT NOT NULL DEFAULT '',
    teacher_id UUID REFERENCES teachers(id) ON DELETE SET NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Signatures
CREATE TABLE IF NOT EXISTS signatures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    slot TEXT NOT NULL CHECK (slot IN ('morning', 'afternoon')),
    image_path TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    device_id TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    sha256 TEXT NOT NULL,
    invalidated_at TIMESTAMPTZ,
    invalidation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(student_id, course_id, slot)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_courses_date ON courses(date);
CREATE INDEX IF NOT EXISTS idx_courses_teacher ON courses(teacher_id);
CREATE INDEX IF NOT EXISTS idx_signatures_student ON signatures(student_id);
CREATE INDEX IF NOT EXISTS idx_signatures_course ON signatures(course_id);

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE signatures ENABLE ROW LEVEL SECURITY;

-- Students: can read/update own record
CREATE POLICY "students_select_own" ON students
    FOR SELECT USING (id = auth.uid());

CREATE POLICY "students_update_own" ON students
    FOR UPDATE USING (id = auth.uid());

CREATE POLICY "students_insert_own" ON students
    FOR INSERT WITH CHECK (id = auth.uid());

-- Teachers: NO client access (only service_role)
-- No policies = no access for authenticated role

-- Courses: any authenticated user can read
CREATE POLICY "courses_select_authenticated" ON courses
    FOR SELECT TO authenticated USING (true);

-- Signatures: students can read own, no client insert (only via Edge Function)
CREATE POLICY "signatures_select_own" ON signatures
    FOR SELECT USING (student_id = auth.uid());

-- ============================================================
-- Storage bucket for signature PNGs
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('signatures', 'signatures', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: students can read own signatures
CREATE POLICY "signatures_storage_select" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'signatures'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Service role can insert (used by Edge Function)
-- No INSERT policy for authenticated = only Edge Function with service_role can write
