(() => {
  'use strict';
  const errorMessages = {
  "Invia un oggetto JSON valido.": "Send a valid JSON object.",
  "Usa il formato JSON.": "Use JSON format.",
  "Richiesta troppo grande.": "Request too large.",
  "Richiesta incompleta.": "Incomplete request.",
  "Riprova più tardi.": "Try again later.",
  "Troppe richieste. Riprova più tardi.": "Too many requests. Try again later.",
  "Origine non autorizzata.": "Unauthorised origin.",
  "Metodo non valido.": "Invalid method.",
  "Servizio non trovato.": "Service not found.",
  "Errore del servizio. Riprova più tardi.": "Service error. Try again later.",
  "Codice di recupero non valido.": "Invalid recovery code.",
  "Profilo non disponibile. Ripristinalo con il codice di recupero.": "Profile unavailable. Restore it with your recovery code.",
  "Sessione del profilo non valida.": "Invalid profile session.",
  "Questo profilo è stato eliminato.": "This profile has been deleted.",
  "Conferma prima di sostituire il profilo locale.": "Confirm before replacing the local profile.",
  "Conferma l’eliminazione del profilo.": "Confirm profile deletion.",
  "Verifica di nuovo l’accesso per continuare.": "Verify your sign-in again to continue.",
  "Il codice appartiene a un altro profilo.": "The code belongs to another profile.",
  "Sessione non valida.": "Invalid session."
};
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
    if (!response.ok) throw new Error(errorMessages[value.error?.message] || 'Action not completed. Try again.');
    return value;
  }

  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (busy) return;
    working(true);
    message('Verifying…');
    const candidate = input.value.trim();
    try {
      const { profile } = await request('profiles/restore/preview', { recoveryCode: candidate });
      recoveryCode = candidate;
      summary.textContent = `${profile.displayName || 'Player'} · ${profile.gems} ${profile.gems === 1 ? 'gem' : 'gems'} · ${profile.ownedDecks.length} ${profile.ownedDecks.length === 1 ? 'collection' : 'collections'}`;
      form.hidden = true;
      preview.hidden = false;
      input.value = '';
      message('Check the profile before confirming.');
      working(false);
      cancel.focus();
    } catch (error) {
      recoveryCode = '';
      message(error.name === 'TimeoutError' ? 'The service is not responding. Try again.' :
        error.message || 'Connection unavailable. Try again.', true);
      working(false);
    }
  });

  cancel.addEventListener('click', () => {
    if (busy) return;
    recoveryCode = '';
    summary.textContent = '';
    preview.hidden = true;
    form.hidden = false;
    message('Deletion cancelled.');
    input.focus();
  });

  confirm.addEventListener('click', async () => {
    if (busy || !recoveryCode) return;
    working(true);
    message('Deleting…');
    let token;
    try {
      const restored = await request('profiles/restore', { recoveryCode, confirmReplace: true });
      token = restored.token;
      await request('auth/reauth/recovery', { recoveryCode }, token);
      await request('profile', { confirmDelete: true }, token, 'DELETE');
      recoveryCode = '';
      summary.textContent = '';
      document.getElementById('recovery-section').hidden = true;
      message('The SommoMemory profile and its associated data have been deleted.');
    } catch (error) {
      message(error.name === 'TimeoutError' ? 'The service is not responding. Verify the profile and try again.' :
        error.message || 'Connection unavailable. Try again.', true);
    } finally {
      // This page never stores credentials. Revoke an unused recovery session
      // when a later step failed; a successful deletion already revoked it.
      if (token) await request('profile/logout', {}, token).catch(() => {});
      token = undefined;
      working(false);
    }
  });
})();
