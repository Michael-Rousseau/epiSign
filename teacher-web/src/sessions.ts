import { supabase } from './supabase.js';
import type { AppState, Course } from './types.js';

export function renderSessionList(state: AppState): string {
    const greeting = state.user?.email ? `Bonjour, ${state.user.email}` : 'Formateur';

    if (state.courses.length === 0) {
        return `
            <h1>${greeting}</h1>
            <p class="subtitle">Aucune session à venir</p>
            <div class="nav-links">
                <button id="logout-btn">Se déconnecter</button>
            </div>
        `;
    }

    const courseCards = state.courses.map(c => {
        const dateStr = new Date(c.starts_at).toLocaleDateString('fr-FR', {
            weekday: 'short',
            day: 'numeric',
            month: 'short',
        });
        const startTime = new Date(c.starts_at).toLocaleTimeString('fr-FR', {
            hour: '2-digit',
            minute: '2-digit',
        });
        const endTime = new Date(c.ends_at).toLocaleTimeString('fr-FR', {
            hour: '2-digit',
            minute: '2-digit',
        });
        const slotLabel = c.slot === 'morning' ? 'Matin' : 'Après-midi';
        const slotClass = c.slot;

        return `
            <div class="session-card" data-course-id="${c.id}">
                <div class="session-info">
                    <div class="session-title">${c.title}</div>
                    <div class="session-meta">${dateStr} · ${startTime}–${endTime} · ${c.room}</div>
                </div>
                <span class="session-slot ${slotClass}">${slotLabel}</span>
            </div>
        `;
    }).join('');

    return `
        <h1>${greeting}</h1>
        <p class="subtitle">Choisissez une session pour démarrer l'émission</p>
        <div class="session-list">
            ${courseCards}
        </div>
        <div class="nav-links">
            <button id="logout-btn">Se déconnecter</button>
        </div>
    `;
}

export async function fetchCourses(teacherId: string): Promise<Course[]> {
    const { data, error } = await supabase
        .from('courses')
        .select('*')
        .eq('teacher_id', teacherId)
        .gte('ends_at', new Date().toISOString())
        .order('starts_at', { ascending: true });

    if (error) {
        console.error('Failed to fetch courses:', error);
        return [];
    }

    return (data as Course[]) ?? [];
}

export function attachSessionListEvents(
    setState: (partial: Partial<AppState>) => void,
    courses: Course[],
) {
    document.querySelectorAll('.session-card').forEach(card => {
        card.addEventListener('click', () => {
            const courseId = (card as HTMLElement).dataset.courseId;
            const course = courses.find(c => c.id === courseId);
            if (course) {
                setState({ screen: 'emit', selectedCourse: course });
            }
        });
    });

    document.getElementById('logout-btn')?.addEventListener('click', async () => {
        await supabase.auth.signOut();
        setState({ screen: 'login', user: null, courses: [], selectedCourse: null, totpSecret: null });
    });
}