export interface Course {
    id: string;
    title: string;
    date: string;
    slot: 'morning' | 'afternoon';
    room: string;
    teacher_id: string;
    starts_at: string;
    ends_at: string;
}

export interface TeacherSessionKey {
    totp_secret: string;
    course_title: string;
    starts_at: string;
    ends_at: string;
}

export type AppScreen = 'login' | 'check-email' | 'session-list' | 'emit';

export interface AppState {
    screen: AppScreen;
    user: { id: string; email: string } | null;
    courses: Course[];
    selectedCourse: Course | null;
    totpSecret: string | null;
    error: string;
}