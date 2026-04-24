-- Seed data for demo
-- Run after 001_schema.sql

-- Insert a demo teacher with a TOTP secret
-- This secret is base32-encoded, compatible with otpauth library
-- Decode: JBSWY3DPEHPK3PXP = "Hello!" in base32
-- For production, generate a proper random secret per teacher
INSERT INTO teachers (id, name, totp_secret) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'M. Fournier', 'JBSWY3DPEHPK3PXP')
ON CONFLICT (id) DO NOTHING;

-- Insert demo courses for the week of 27/04/2026
INSERT INTO courses (id, title, date, slot, room, teacher_id, starts_at, ends_at) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'iOS Development', '2026-04-27', 'morning',   'SM Apple', 'a0000000-0000-0000-0000-000000000001', '2026-04-27 09:00:00+02', '2026-04-27 13:00:00+02'),
    ('c0000000-0000-0000-0000-000000000002', 'iOS Development', '2026-04-27', 'afternoon', 'SM Apple', 'a0000000-0000-0000-0000-000000000001', '2026-04-27 14:00:00+02', '2026-04-27 18:00:00+02'),
    ('c0000000-0000-0000-0000-000000000003', 'Swift Avancé',    '2026-04-28', 'morning',   'SM Apple', 'a0000000-0000-0000-0000-000000000001', '2026-04-28 09:00:00+02', '2026-04-28 13:00:00+02'),
    ('c0000000-0000-0000-0000-000000000004', 'Swift Avancé',    '2026-04-28', 'afternoon', 'SM Apple', 'a0000000-0000-0000-0000-000000000001', '2026-04-28 14:00:00+02', '2026-04-28 18:00:00+02'),
    ('c0000000-0000-0000-0000-000000000005', 'Projet EpiSign',  '2026-04-29', 'morning',   'SM Apple', 'a0000000-0000-0000-0000-000000000001', '2026-04-29 09:00:00+02', '2026-04-29 13:00:00+02'),
    ('c0000000-0000-0000-0000-000000000006', 'Projet EpiSign',  '2026-04-29', 'afternoon', 'SM Apple', 'a0000000-0000-0000-0000-000000000001', '2026-04-29 14:00:00+02', '2026-04-29 18:00:00+02')
ON CONFLICT (id) DO NOTHING;
