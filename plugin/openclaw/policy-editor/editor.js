// policy-editor/editor.js
const $ = id => document.getElementById(id);

async function loadPolicy() {
  const res = await fetch('/policy');
  return await res.text();
}

async function savePolicy(yaml) {
  const res = await fetch('/policy', {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain' },
    body: yaml,
  });
  return res.ok;
}

function parseField(yaml, key) {
  const m = yaml.match(new RegExp(`^\\s*${key}:\\s*(.+)$`, 'm'));
  return m ? m[1].trim().replace(/^"|"$/g, '') : '';
}

function setField(yaml, key, value) {
  const re = new RegExp(`(^\\s*${key}:).*$`, 'm');
  return re.test(yaml) ? yaml.replace(re, `$1 "${value}"`) : yaml;
}

const rawYaml = await loadPolicy();
$('raw-yaml').value = rawYaml;

const quietStart = parseField(rawYaml, 'start');
const quietEnd   = parseField(rawYaml, 'end');
if (quietStart) $('quiet-start').value = quietStart;
if (quietEnd)   $('quiet-end').value   = quietEnd;

$('confirm-lock').checked = /lock/.test(rawYaml);

$('save-btn').addEventListener('click', async () => {
  let yaml = $('raw-yaml').value;
  yaml = setField(yaml, 'start', $('quiet-start').value);
  yaml = setField(yaml, 'end',   $('quiet-end').value);
  $('raw-yaml').value = yaml;
  const ok = await savePolicy(yaml);
  $('status').textContent = ok ? 'Saved' : 'Error';
  setTimeout(() => { $('status').textContent = ''; }, 2000);
});

['quiet-start', 'quiet-end'].forEach(id => {
  $(id).addEventListener('change', () => {
    let yaml = $('raw-yaml').value;
    yaml = setField(yaml, 'start', $('quiet-start').value);
    yaml = setField(yaml, 'end',   $('quiet-end').value);
    $('raw-yaml').value = yaml;
  });
});
