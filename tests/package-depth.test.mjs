import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');
const catalog = JSON.parse(read('routing/skill-catalog.json'));
const attachments = {
  'ui-designer': ['design-system', 'localization'],
  'software-architect': ['domain-modeling', 'migration-upgrade', 'mcp-server-development', 'technical-diagrams'],
  'software-implementer': ['migration-upgrade', 'mcp-server-development', 'localization', 'skill-authoring-evaluation'],
  'media-producer': ['subtitle-production', 'technical-diagrams'],
};
const routes = {
  'skill-authoring-review': ['skill-authoring-evaluation'],
  'design-system-spec': ['design-system', 'frontend-visual-design'],
  'domain-model': ['domain-modeling'],
  'dependency-framework-upgrade': ['migration-upgrade'],
  'mcp-server-build': ['mcp-server-development'],
  'technical-diagram': ['technical-diagrams'],
  'subtitle-caption-conversion': ['subtitle-production'],
  'localization-i18n': ['localization'],
};

test('depth skills resolve with the CLI requirements of their shipped examples', () => {
  const requirements = {
    'design-system': [],
    'domain-modeling': [],
    'migration-upgrade': [],
    'skill-authoring-evaluation': [],
    'mcp-server-development': ['node'],
    'technical-diagrams': ['node'],
    localization: ['node'],
    'subtitle-production': ['node'],
    'frontend-visual-design': ['node'],
    'accessibility-audit': ['node'],
    'browser-e2e': ['node', 'python'],
  };
  for (const [id, commands] of Object.entries(requirements)) {
    const skill = catalog.skills.find((entry) => entry.id === id);
    assert.ok(skill, `${id} must be selectable from the catalog`);
    assert.equal(skill.path.replaceAll('\\', '/'), `skills/${id}/SKILL.md`);
    assert.match(read(`skills/${id}/SKILL.md`), new RegExp(`^name: ${id}$`, 'm'));
    assert.deepEqual(skill.requires?.cli ?? [], commands, `${id} CLI requirements`);
    assert.deepEqual(skill.requires?.env ?? [], [], `${id} needs no credential or setting`);
    assert.deepEqual(skill.requires?.api ?? [], [], `${id} needs no external service`);
  }
});

test('depth routing and optional Role attachments agree with the shipped Role text', () => {
  const roles = JSON.parse(read('roles/catalog.json')).roles;
  const selection = JSON.parse(read('routing/skill-selection.json'));
  for (const [id, skills] of Object.entries(attachments)) {
    const role = roles.find((entry) => entry.id === id);
    const text = read(role.path);
    const optional = text.split('optionalSkills:\n')[1].split('---')[0];
    for (const skill of skills) {
      assert.ok(role.optionalSkills.includes(skill), `${id} must offer ${skill}`);
      assert.ok(optional.includes(`  - ${skill}\n`), `${id} frontmatter must offer ${skill}`);
      assert.ok(text.split('## 可选专业 Skill')[1].includes('`' + skill + '`'), `${id} body must offer ${skill}`);
    }
  }
  for (const [risk, skills] of Object.entries(routes)) {
    assert.deepEqual(selection.riskRoutes[risk], skills, risk);
    for (const id of skills) assert.ok(catalog.skills.some((entry) => entry.id === id));
  }
});
