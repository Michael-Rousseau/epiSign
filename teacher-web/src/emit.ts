import { supabase } from './supabase.js';
import type { AppState, TeacherSessionKey } from './types.js';

// These types come from the ggwave and otpauth UMD globals
// We declare them here so TypeScript won't complain
declare global {
    interface Window {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ggwave_factory: () => Promise<any>;
        OTPAuth: {
            TOTP: new (opts: { secret: string; digits: number; period: number; algorithm: string }) => { generate: () => string };
        };
    }
}

let ggwaveModule: InstanceType<typeof Object> | null = null;
let ggwaveInstance: number | null = null;
let audioContext: AudioContext | null = null;
let emitInterval: ReturnType<typeof setInterval> | null = null;
let timerInterval: ReturnType<typeof setInterval> | null = null;
let totpSecret = '';
let isDevMode = false;

function convertTypedArray(src: ArrayBufferView, type: Float32ArrayConstructor): Float32Array {
    const buffer = new ArrayBuffer(src.byteLength);
    new (src.constructor as Float32ArrayConstructor)(buffer).set(src as unknown as Float32Array);
    return new type(buffer);
}

async function loadGGWave(): Promise<void> {
    const urls = [
        'https://ggwave-js.ggerganov.com/ggwave.js',
        'https://cdn.jsdelivr.net/npm/ggwave@0.4.0/build/ggwave.js',
    ];

    for (const url of urls) {
        try {
            await new Promise<void>((resolve, reject) => {
                const s = document.createElement('script');
                s.src = url;
                s.onload = () => resolve();
                s.onerror = () => reject(new Error('Failed to load'));
                document.head.appendChild(s);
            });
            if (typeof window.ggwave_factory === 'function') {
                console.log('ggwave loaded from:', url);
                return;
            }
        } catch {
            console.warn('Failed to load ggwave from:', url);
        }
    }
    throw new Error('Could not load ggwave from any source');
}

function getProtocolId(): number {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const P = (ggwaveModule as any)?.ProtocolId;
    if (isDevMode) {
        return P ? P.GGWAVE_PROTOCOL_AUDIBLE_NORMAL : 0;
    } else {
        return P ? P.GGWAVE_PROTOCOL_ULTRASOUND_NORMAL : 3;
    }
}

function generateTOTP(): string {
    const totp = new window.OTPAuth.TOTP({
        secret: totpSecret,
        digits: 6,
        period: 30,
        algorithm: 'SHA1',
    });
    return totp.generate();
}

function updateTOTPDisplay(): string {
    const code = generateTOTP();
    const el = document.getElementById('totp-code');
    if (el) el.textContent = code;
    return code;
}

function playWaveform(waveform: ArrayBufferView): void {
    const buf = convertTypedArray(waveform, Float32Array);
    if (!audioContext) return;

    const buffer = audioContext.createBuffer(1, buf.length, audioContext.sampleRate);
    buffer.getChannelData(0).set(buf);

    const source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.connect(audioContext.destination);
    source.start(0);
}

function updateAndEmit(): void {
    const code = updateTOTPDisplay();

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const mod = ggwaveModule as any;
    if (!mod || ggwaveInstance == null || !audioContext) {
        console.warn('updateAndEmit: not ready');
        return;
    }

    if (audioContext.state === 'suspended') {
        audioContext.resume();
    }

    try {
        const protocolId = getProtocolId();
        const volume = 100;

        const waveform = mod.encode(ggwaveInstance, code, protocolId, volume);

        if (waveform && waveform.length > 0) {
            playWaveform(waveform);
            console.log('Emitted TOTP:', code, '| protocol:', protocolId);
        } else {
            console.warn('ggwave encode returned empty');
        }
    } catch (e) {
        console.error('Encode/play error:', e);
    }
}

function updateTimerBar(): void {
    const now = Date.now() / 1000;
    const elapsed = now % 30;
    const pct = ((30 - elapsed) / 30) * 100;
    const fill = document.getElementById('timer-fill');
    if (fill) fill.style.width = pct + '%';

    const code = generateTOTP();
    const display = document.getElementById('totp-code');
    if (display && display.textContent !== code) {
        display.textContent = code;
    }
}

async function fetchTOTPSecret(courseId: string): Promise<TeacherSessionKey> {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) throw new Error('Not authenticated');

    const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/teacher-session-key`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ course_id: courseId }),
    });

    if (!response.ok) {
        const body = await response.json();
        throw new Error(body.error || 'Failed to fetch session key');
    }

    return response.json();
}

export function renderEmit(state: AppState): string {
    const course = state.selectedCourse;
    if (!course) return '<p class="error-msg">Erreur: aucune session sélectionnée</p>';

    const slotLabel = course.slot === 'morning' ? 'Matin' : 'Après-midi';
    const slotClass = course.slot === 'morning' ? 'morning' : 'afternoon';
    const dateStr = new Date(course.starts_at).toLocaleDateString('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
    });

    return `
        <h1>${course.title}</h1>
        <p class="subtitle">
            ${dateStr} · <span class="session-slot ${slotClass}">${slotLabel}</span> · ${course.room}
        </p>
        <div id="emitter-status">
            <div class="spinner"></div>
            <p style="margin-top:12px; color: rgba(255,255,255,0.5);">Chargement…</p>
        </div>
        <div id="emit-content" style="display:none;">
            <p class="subtitle">Code TOTP actuel — fallback saisie manuelle</p>
            <div class="totp-display" id="totp-code">------</div>
            <div class="timer-bar">
                <div class="timer-fill" id="timer-fill"></div>
            </div>
            <div class="status">
                <span class="dot" id="emit-dot"></span>
                <span id="status-text">Émission active</span>
            </div>
            <div id="mode-badge-container"></div>
            <p class="info" id="info-text">
                Signal ultrasonique 17-20 kHz · Renouvellement toutes les 30s<br>
                Les étudiants peuvent aussi saisir le code manuellement
            </p>
        </div>
        <p class="error-msg" id="emit-error"></p>
        <div class="nav-links">
            <button id="back-to-sessions">← Retour aux sessions</button>
        </div>
    `;
}

export async function startEmit(state: AppState): Promise<void> {
    const course = state.selectedCourse;
    if (!course) return;

    const statusEl = document.getElementById('emitter-status');
    const contentEl = document.getElementById('emit-content');
    const errorEl = document.getElementById('emit-error');

    try {
        const keyData = await fetchTOTPSecret(course.id);
        totpSecret = keyData.totp_secret;
        isDevMode = false;

        if (statusEl) statusEl.style.display = 'none';
        if (contentEl) contentEl.style.display = 'block';

        const courseTitle = document.getElementById('display-course');

        if (courseTitle) courseTitle.textContent = course.title;

        const badgeContainer = document.getElementById('mode-badge-container');
        const infoText = document.getElementById('info-text');
        if (isDevMode) {
            if (badgeContainer) badgeContainer.innerHTML = '<span class="mode-badge audible">MODE DEV — Audible ~1-4 kHz</span>';
            if (infoText) infoText.innerHTML = 'Signal audible 1-4 kHz (dev/test) · Renouvellement toutes les 30s<br>Les étudiants peuvent aussi saisir le code manuellement';
        } else {
            if (badgeContainer) badgeContainer.innerHTML = '<span class="mode-badge ultrasound">Ultrason 17-20 kHz</span>';
            if (infoText) infoText.innerHTML = 'Signal ultrasonique 17-20 kHz · Renouvellement toutes les 30s<br>Les étudiants peuvent aussi saisir le code manuellement';
        }

        audioContext = new AudioContext({
            sampleRate: 48000,
        });

        await loadGGWave();
        ggwaveModule = await window.ggwave_factory();
        const params = (ggwaveModule as any).getDefaultParameters();
        params.sampleRateInp = audioContext.sampleRate;
        params.sampleRateOut = audioContext.sampleRate;
        ggwaveInstance = (ggwaveModule as any).init(params);
        if (ggwaveInstance == null || ggwaveInstance < 0) {
            throw new Error('ggwave.init() failed');
        }

        console.log('ggwave initialized OK');

        updateAndEmit();
        emitInterval = setInterval(updateAndEmit, 5000);
        timerInterval = setInterval(updateTimerBar, 100);
    } catch (e) {
        console.error('Emit init error:', e);

        if (statusEl) statusEl.style.display = 'none';
        if (contentEl) contentEl.style.display = 'block';
        if (errorEl) errorEl.textContent = 'Erreur ggwave — code affiché uniquement (saisie manuelle)';

        const dot = document.getElementById('emit-dot');
        const statusText = document.getElementById('status-text');
        if (dot) dot.style.background = '#f87171';
        if (statusText) statusText.textContent = 'Émission échouée';

        updateTOTPDisplay();
        setInterval(updateTOTPDisplay, 1000);
        timerInterval = setInterval(updateTimerBar, 100);
    }
}

export function stopEmit(): void {
    if (emitInterval) clearInterval(emitInterval);
    if (timerInterval) clearInterval(timerInterval);
    emitInterval = null;
    timerInterval = null;

    if (audioContext) {
        audioContext.close();
        audioContext = null;
    }

    ggwaveModule = null;
    ggwaveInstance = null;
    totpSecret = '';
}

export function attachEmitEvents(setState: (partial: Partial<AppState>) => void): void {
    document.getElementById('back-to-sessions')?.addEventListener('click', () => {
        stopEmit();
        setState({ screen: 'session-list', selectedCourse: null, totpSecret: null });
    });
}