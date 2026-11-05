(() => {
  'use strict';
  const form = document.getElementById('recovery-form');
  const input = document.getElementById('recovery-code');
  const preview = document.getElementById('preview');
  const summary = document.getElementById('profile-summary');
  const status = document.getElementById('status');
  const confirm = document.getElementById('confirm-delete');
  const cancel = document.getElementById('cancel');
  const verify = document.getElementById('verify');
  let recoveryCode = '', busy = false;

  function message(text, error = false) {
    status.textContent = text;
    status.className = error ? 'error' : '';
  }
  function working(value) {
    busy = value;
    for (const button of [verify, confirm, cancel]) button.disabled = value;
    input.disabled = value;
  }
  async function request(path, data, token, method = 'POST') {
    const response = await fetch(`/api/v1/${path}`, {
      method, headers: { 'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: JSON.stringify(data), cache: 'no-store', credentials: 'omit',
      redirect: 'error', referrerPolicy: 'no-referrer',
      signal: AbortSignal.timeout(20_000),
    });
    const value = await response.json();
    if (!response.ok) throw new Error(value.error?.message || 'Operazione non completata. Riprova.');
    return value;
  }

  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (busy) return;
    working(true);
    message('Verifica in corso…');
    const candidate = input.value.trim();
    try {
      const { profile } = await request('profiles/restore/preview', { recoveryCode: candidate });
      recoveryCode = candidate;
      summary.textContent = `${profile.displayName || 'Giocatore'} · ${profile.gems} gemme · ${profile.ownedDecks.length} collezioni`;
      form.hidden = true;
      preview.hidden = false;
      input.value = '';
      message('Controlla il profilo prima di confermare.');
      working(false);
      cancel.focus();
    } catch (error) {
      recoveryCode = '';
      message(error.name === 'TimeoutError' ? 'Il servizio non risponde. Riprova.' :
        error.message || 'Connessione non disponibile. Riprova.', true);
      working(false);
    }
  });

  cancel.addEventListener('click', () => {
    if (busy) return;
    recoveryCode = '';
    summary.textContent = '';
    preview.hidden = true;
    form.hidden = false;
    message('Cancellazione annullata.');
    input.focus();
  });

  confirm.addEventListener('click', async () => {
    if (busy || !recoveryCode) return;
    working(true);
    message('Cancellazione in corso…');
    let token;
    try {
      const restored = await request('profiles/restore', { recoveryCode, confirmReplace: true });
      token = restored.token;
      await request('auth/reauth/recovery', { recoveryCode }, token);
      await request('profile', { confirmDelete: true }, token, 'DELETE');
      recoveryCode = '';
      summary.textContent = '';
      document.getElementById('recovery-section').hidden = true;
      message('Il profilo SommoMemory e i dati associati sono stati eliminati.');
    } catch (error) {
      message(error.name === 'TimeoutError' ? 'Il servizio non risponde. Verifica il profilo e riprova.' :
        error.message || 'Connessione non disponibile. Riprova.', true);
    } finally {
      // This page never stores credentials. Revoke an unused recovery session
      // when a later step failed; a successful deletion already revoked it.
      if (token) await request('profile/logout', {}, token).catch(() => {});
      token = undefined;
      working(false);
    }
  });
})();
