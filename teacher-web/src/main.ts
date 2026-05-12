import './style.css';
import { supabase } from './supabase.js';
import type { AppState } from './types.js';
import { renderLogin, renderCheckEmail, attachLoginEvents, attachCheckEmailEvents } from './login.js';
import { renderSessionList, fetchCourses, attachSessionListEvents } from './sessions.js';
import { renderEmit, startEmit, stopEmit, attachEmitEvents } from './emit.js';

const app = document.getElementById('app')!;

const state: AppState = {
    screen: 'login',
    user: null,
    courses: [],
    selectedCourse: null,
    totpSecret: null,
    error: '',
};

function setState(partial: Partial<AppState>): void {
    Object.assign(state, partial);
    render();
}

function render(): void {
    switch (state.screen) {
        case 'login':
            app.innerHTML = `<div class="container" id="login-screen">${renderLogin(state)}</div>`;
            attachLoginEvents(setState);
            break;
        case 'check-email':
            app.innerHTML = `<div class="container">${renderCheckEmail(state.user?.email ?? '')}</div>`;
            attachCheckEmailEvents(setState);
            break;
        case 'session-list':
            app.innerHTML = `<div class="container">${renderSessionList(state)}</div>`;
            attachSessionListEvents(setState, state.courses);
            break;
        case 'emit':
            app.innerHTML = `<div class="container">${renderEmit(state)}</div>`;
            attachEmitEvents(setState);
            startEmit(state);
            break;
    }
}

async function init(): Promise<void> {
    const { data: { session } } = await supabase.auth.getSession();

    if (session?.user) {
        state.user = { id: session.user.id, email: session.user.email ?? '' };
        state.courses = await fetchCourses(session.user.id);
        state.screen = 'session-list';
    }

    supabase.auth.onAuthStateChange(async (_event, session) => {
        if (session?.user) {
            state.user = { id: session.user.id, email: session.user.email ?? '' };
            state.courses = await fetchCourses(session.user.id);
            state.screen = 'session-list';
            stopEmit();
        } else {
            state.user = null;
            state.courses = [];
            state.selectedCourse = null;
            state.totpSecret = null;
            state.screen = 'login';
            stopEmit();
        }
        render();
    });

    render();
}

init();