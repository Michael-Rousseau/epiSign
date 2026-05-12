import { supabase, supabaseAdmin, isDevMode } from './supabase.js';
import type { AppState } from './types.js';

export function renderLogin(state: AppState): string {
    const devBadge = isDevMode
        ? '<span class="mode-badge audible" style="margin-bottom:16px;">MODE DEV — bypass email</span>'
        : '';

    return `
        <h1>EpiSign Formateur</h1>
        <p class="subtitle">Connectez-vous avec votre email</p>
        ${devBadge}
        <div class="form-group" id="login-form">
            <input type="email" id="login-email" placeholder="Email" autocomplete="email" />
            <button class="btn" id="login-btn">Connexion</button>
            <p class="error-msg" id="login-error">${state.error}</p>
        </div>
    `;
}

export function renderCheckEmail(email: string): string {
    return `
        <div class="email-icon">📧</div>
        <h1>Vérifiez votre boîte mail</h1>
        <p class="subtitle">Nous avons envoyé un lien de connexion à <strong>${email}</strong></p>
        <div class="spinner"></div>
        <p class="info">Cliquez sur le lien dans l'email pour vous connecter automatiquement.</p>
        <div class="nav-links">
            <button id="back-to-login">Retour</button>
        </div>
    `;
}

export function renderDevLink(email: string, link: string): string {
    return `
        <h1>DEV — Lien magique</h1>
        <p class="subtitle">Connexion pour <strong>${email}</strong></p>
        <div class="form-group" style="margin-top:20px;">
            <a href="${link}" class="btn" style="display:block;text-align:center;text-decoration:none;">Se connecter</a>
            <p class="info" style="margin-top:12px;word-break:break-all;">${link}</p>
        </div>
        <div class="nav-links">
            <button id="back-to-login">Retour</button>
        </div>
    `;
}

export function attachLoginEvents(setState: (partial: Partial<AppState>) => void) {
    const btn = document.getElementById('login-btn');
    const input = document.getElementById('login-email') as HTMLInputElement;

    btn?.addEventListener('click', async () => {
        const email = input?.value.trim();
        if (!email) {
            setState({ error: 'Email requis' });
            return;
        }

        (btn as HTMLButtonElement).disabled = true;
        (btn as HTMLButtonElement).textContent = 'Connexion en cours...';

        // Dev mode: generate the magic link via admin API, no email sent
        if (isDevMode && supabaseAdmin) {
            try {
                const { data, error } = await supabaseAdmin.auth.admin.generateLink({
                    type: 'magiclink',
                    email,
                    options: {
                        redirectTo: `${window.location.origin}/`,
                    },
                });

                if (error) {
                    setState({ error: error.message });
                    (btn as HTMLButtonElement).disabled = false;
                    (btn as HTMLButtonElement).textContent = 'Connexion';
                    return;
                }

                // Show the link directly instead of sending an email
                const app = document.getElementById('app')!;
                app.innerHTML = `<div class="container">${renderDevLink(email, data.properties?.action_link ?? '')}</div>`;
                attachDevLinkEvents(setState);
                return;
            } catch (e) {
                setState({ error: String(e) });
                (btn as HTMLButtonElement).disabled = false;
                (btn as HTMLButtonElement).textContent = 'Connexion';
                return;
            }
        }

        // Normal mode: send magic link email
        const { error } = await supabase.auth.signInWithOtp({
            email,
            options: { emailRedirectTo: `${window.location.origin}/` },
        });

        if (error) {
            setState({ error: error.message });
            (btn as HTMLButtonElement).disabled = false;
            (btn as HTMLButtonElement).textContent = 'Connexion';
            return;
        }

        setState({ screen: 'check-email', error: '' });
    });

    input?.addEventListener('keydown', (e: KeyboardEvent) => {
        if (e.key === 'Enter') btn?.dispatchEvent(new Event('click'));
    });
}

function attachDevLinkEvents(setState: (partial: Partial<AppState>) => void) {
    document.getElementById('back-to-login')?.addEventListener('click', () => {
        setState({ screen: 'login', error: '' });
    });
}

export function attachCheckEmailEvents(setState: (partial: Partial<AppState>) => void) {
    document.getElementById('back-to-login')?.addEventListener('click', () => {
        setState({ screen: 'login', error: '' });
    });
}